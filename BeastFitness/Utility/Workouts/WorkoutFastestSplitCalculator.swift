//
//  WorkoutFastestSplitCalculator.swift
//  BeastFitness
//
//  Created by Patrick Doyle on 2/16/26.
//

import Foundation
import HealthKit
import CoreLocation
import BeastFitnessCore

// MARK: - Fastest split (pace) from HKWorkoutRoute (with interpolation + pause-aware "moving time")

final class WorkoutFastestSplitCalculator {

    enum TimeBasis {
        /// Uses wall-clock time between GPS timestamps (includes pauses / standing still).
        case elapsed

        /// Subtracts HKWorkout pause/resume events from the window.
        /// (If there are no events, behaves like .elapsed.)
        case moving
    }

    private let healthStore: HKHealthStore
    private let workout: HKWorkout

    init(healthStore: HKHealthStore = HKHealthStore(), workout: HKWorkout) {
        self.healthStore = healthStore
        self.workout = workout
    }

    /// Returns the fastest pace over `targetMeters` in **seconds per meter**.
    /// Convert to sec/mile or sec/km using the helpers at the bottom.
    ///
    /// - Parameters:
    ///   - targetMeters: Split distance to evaluate (e.g. 1609.344 for 1 mile).
    ///   - timeBasis: `.elapsed` or `.moving`
    ///   - accuracyCutoff: Optional horizontal accuracy filter for GPS points.
    func fastestPaceSecondsPerMeter(
        targetMeters: Double,
        timeBasis: TimeBasis = .elapsed,
        accuracyCutoff: CLLocationAccuracy? = 50
    ) async -> Double? {

        guard targetMeters > 0 else { return nil }

        // 1) Fetch + normalize route locations
        guard var locations = await fetchAllWorkoutRouteLocations() else { return nil }
        if let cutoff = accuracyCutoff {
            locations = locations.filter { $0.horizontalAccuracy >= 0 && $0.horizontalAccuracy <= cutoff }
        }
        locations.sort { $0.timestamp < $1.timestamp }
        guard locations.count >= 2 else { return nil }

        // Optional: remove duplicate timestamps / zero-time segments that can cause weird interpolation
        locations = dedupeByTimestampKeepingBestAccuracy(locations)
        guard locations.count >= 2 else { return nil }

        // 2) Build cumulative distance (meters) along the path
        let cumulative = buildCumulativeDistance(locations: locations)
        let total = cumulative.last ?? 0
        guard total >= targetMeters else { return nil }

        // 3) Two-pointer sliding window in distance space (O(n))
        var bestSecondsPerMeter: Double = .infinity
        var j = 1

        for i in 0..<(locations.count - 1) {
            let startDist = cumulative[i]
            let desiredDist = startDist + targetMeters

            // Ensure j is at least i+1
            if j < i + 1 { j = i + 1 }

            // Advance j until we cross the desired cumulative distance
            while j < locations.count && cumulative[j] < desiredDist {
                j += 1
            }
            if j >= locations.count { break }

            // We crossed target between (j-1) and j, or exactly at j
            let startTime = locations[i].timestamp

            // Interpolated end time exactly at the target distance
            let endTime: Date = {
                if cumulative[j] == desiredDist {
                    return locations[j].timestamp
                }
                // interpolate within segment (j-1 -> j)
                return interpolateTimeAtDistance(
                    prev: locations[j - 1],
                    next: locations[j],
                    prevCum: cumulative[j - 1],
                    nextCum: cumulative[j],
                    targetCum: desiredDist
                )
            }()

            var elapsed = endTime.timeIntervalSince(startTime)
            if elapsed <= 0 { continue }

            if timeBasis == .moving {
                let paused = pausedSeconds(between: startTime, and: endTime, workout: workout)
                elapsed = max(0, elapsed - paused)
                if elapsed <= 0 { continue }
            }

            let secondsPerMeter = elapsed / targetMeters
            if secondsPerMeter < bestSecondsPerMeter {
                bestSecondsPerMeter = secondsPerMeter
            }
        }

        return bestSecondsPerMeter.isFinite ? bestSecondsPerMeter : nil
    }

    /// Convenience: fastest pace in **seconds per mile** for a mile split.
    func fastestMilePaceSeconds(
        timeBasis: TimeBasis = .elapsed,
        accuracyCutoff: CLLocationAccuracy? = 50
    ) async -> Double? {
        let mileMeters = 1609.344
        guard let spm = await fastestPaceSecondsPerMeter(
            targetMeters: mileMeters,
            timeBasis: timeBasis,
            accuracyCutoff: accuracyCutoff
        ) else { return nil }
        return spm * mileMeters
    }

    /// Convenience: fastest pace in **seconds per kilometer** for a 1km split.
    func fastestKilometerPaceSeconds(
        timeBasis: TimeBasis = .elapsed,
        accuracyCutoff: CLLocationAccuracy? = 50
    ) async -> Double? {
        let kmMeters = 1000.0
        guard let spm = await fastestPaceSecondsPerMeter(
            targetMeters: kmMeters,
            timeBasis: timeBasis,
            accuracyCutoff: accuracyCutoff
        ) else { return nil }
        return spm * kmMeters
    }

    // MARK: - Route fetching

    private func fetchAllWorkoutRouteLocations() async -> [CLLocation]? {
        await withCheckedContinuation { continuation in
            let routePredicate = HKQuery.predicateForObjects(from: workout)

            let routeQuery = HKSampleQuery(
                sampleType: HKSeriesType.workoutRoute(),
                predicate: routePredicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: nil
            ) { [weak self] _, samples, error in
                guard let self else {
                    continuation.resume(returning: nil)
                    return
                }

                if let error {
                    print("HKSampleQuery(workoutRoute) error: \(error.localizedDescription)")
                    continuation.resume(returning: nil)
                    return
                }

                let routes = (samples as? [HKWorkoutRoute]) ?? []
                guard !routes.isEmpty else {
                    continuation.resume(returning: nil)
                    return
                }

                // Fetch locations for all routes and merge
                Task {
                    var all: [CLLocation] = []
                    for route in routes {
                        if let locs = await self.fetchLocations(for: route) {
                            all.append(contentsOf: locs)
                        }
                    }
                    continuation.resume(returning: all.isEmpty ? nil : all)
                }
            }

            healthStore.execute(routeQuery)
        }
    }

    private func fetchLocations(for route: HKWorkoutRoute) async -> [CLLocation]? {
        await withCheckedContinuation { continuation in
            var locations: [CLLocation] = []

            let locationQuery = HKWorkoutRouteQuery(route: route) { _, newLocations, done, error in
                if let error {
                    print("HKWorkoutRouteQuery error: \(error.localizedDescription)")
                    continuation.resume(returning: nil)
                    return
                }
                if let newLocations {
                    locations.append(contentsOf: newLocations)
                }
                if done {
                    continuation.resume(returning: locations)
                }
            }

            healthStore.execute(locationQuery)
        }
    }

    // MARK: - Distance + interpolation

    private func buildCumulativeDistance(locations: [CLLocation]) -> [Double] {
        var cumulative: [Double] = Array(repeating: 0, count: locations.count)
        var total: Double = 0

        for idx in 1..<locations.count {
            let d = locations[idx].distance(from: locations[idx - 1]) // meters
            if d.isFinite, d > 0 {
                total += d
            }
            cumulative[idx] = total
        }
        return cumulative
    }

    /// Interpolates a timestamp at a target cumulative distance that lies between prevCum and nextCum.
    private func interpolateTimeAtDistance(
        prev: CLLocation,
        next: CLLocation,
        prevCum: Double,
        nextCum: Double,
        targetCum: Double
    ) -> Date {
        let segDist = nextCum - prevCum
        guard segDist > 0 else { return next.timestamp }

        let fraction = (targetCum - prevCum) / segDist
        let clamped = max(0, min(1, fraction))

        let segTime = next.timestamp.timeIntervalSince(prev.timestamp)
        return prev.timestamp.addingTimeInterval(segTime * clamped)
    }

    private func dedupeByTimestampKeepingBestAccuracy(_ locations: [CLLocation]) -> [CLLocation] {
        guard locations.count >= 2 else { return locations }

        var result: [CLLocation] = []
        result.reserveCapacity(locations.count)

        var i = 0
        while i < locations.count {
            var best = locations[i]
            var j = i + 1
            while j < locations.count && locations[j].timestamp == best.timestamp {
                // Keep the one with better (smaller) horizontalAccuracy, if valid
                let a1 = best.horizontalAccuracy
                let a2 = locations[j].horizontalAccuracy
                if (a2 >= 0 && (a1 < 0 || a2 < a1)) {
                    best = locations[j]
                }
                j += 1
            }
            result.append(best)
            i = j
        }

        return result
    }

    // MARK: - Pause-aware moving time

    /// Returns how many seconds of "paused" time overlap [start, end] based on workout events.
    private func pausedSeconds(between start: Date, and end: Date, workout: HKWorkout) -> TimeInterval {
        guard start < end, let events = workout.workoutEvents, !events.isEmpty else { return 0 }

        var paused: TimeInterval = 0
        var pauseStart: Date? = nil

        for e in events {
            switch e.type {
            case .pause, .motionPaused:
                // Handle both manual pauses (.pause) and automatic motion detection (.motionPaused)
                pauseStart = e.dateInterval.start

            case .resume, .motionResumed:
                // Handle both manual resumes (.resume) and automatic motion detection (.motionResumed)
                if let ps = pauseStart {
                    let pe = e.dateInterval.start
                    paused += overlapSeconds(aStart: start, aEnd: end, bStart: ps, bEnd: pe)
                }
                pauseStart = nil

            default:
                break
            }
        }

        // If workout ended while paused (no resume event), count until end of window
        if let ps = pauseStart {
            paused += overlapSeconds(aStart: start, aEnd: end, bStart: ps, bEnd: end)
        }

        return paused
    }

    private func overlapSeconds(aStart: Date, aEnd: Date, bStart: Date, bEnd: Date) -> TimeInterval {
        let s = max(aStart, bStart)
        let e = min(aEnd, bEnd)
        return max(0, e.timeIntervalSince(s))
    }
    
    /// Fastest time (seconds) to cover `targetMeters` within the route.
    func fastestTimeSeconds(
        targetMeters: Double,
        timeBasis: TimeBasis = .elapsed,
        accuracyCutoff: CLLocationAccuracy? = 50
    ) async -> Double? {
        guard targetMeters > 0 else { return nil }

        // Reuse the pace method and multiply back:
        // secondsPerMeter * meters = seconds
        guard let secondsPerMeter = await fastestPaceSecondsPerMeter(
            targetMeters: targetMeters,
            timeBasis: timeBasis,
            accuracyCutoff: accuracyCutoff
        ) else { return nil }

        return secondsPerMeter * targetMeters
    }

    /// Tier 2 fallback: Calculate fastest split using distance samples instead of GPS route
    /// This queries HKQuantityType distance samples and builds a distance-over-time series
    struct DP {
        let time: Date
        let cum: Double
    }

    func fastestTimeSecondsFromDistanceSamples(
        targetMeters: Double,
        distanceType: SQQuantityType,
        timeBasis: TimeBasis = .elapsed
    ) async -> Double? {
        guard targetMeters > 0 else { return nil }

        guard let id = distanceType.hkQuantityTypeIdentifier,
              let qt = HKQuantityType.quantityType(forIdentifier: id) else { return nil }

        // 1) Query: prefer "from workout"
        let workoutPredicate = HKQuery.predicateForObjects(from: workout)

        let sort = [NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: true)]

        func runQuery(_ predicate: NSPredicate) async -> [HKQuantitySample] {
            (try? await withCheckedThrowingContinuation { (cont: CheckedContinuation<[HKQuantitySample], Error>) in
                let q = HKSampleQuery(sampleType: qt, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: sort) { _, samples, error in
                    if let error { cont.resume(throwing: error); return }
                    cont.resume(returning: (samples as? [HKQuantitySample]) ?? [])
                }
                healthStore.execute(q)
            }) ?? []
        }

        var samples = await runQuery(workoutPredicate)

        if samples.count < 2 {
            // fallback: time range (use strict end too)
            let datePredicate = HKQuery.predicateForSamples(
                withStart: workout.startDate,
                end: workout.endDate,
                options: [.strictStartDate, .strictEndDate]
            )
            samples = await runQuery(datePredicate)
        }

        guard samples.count >= 2 else { return nil }

        // 2) Decide delta-vs-cumulative heuristic
        let meter = HKUnit.meter()
        let values = samples.map { $0.quantity.doubleValue(for: meter) }
        let startsNearWorkoutStartCount = samples.filter { abs($0.startDate.timeIntervalSince(workout.startDate)) < 1 }.count
        let mostlyNonDecreasing = zip(values, values.dropFirst()).filter { $1 >= $0 }.count > (values.count * 3 / 4)

        let treatAsCumulative = startsNearWorkoutStartCount > (samples.count / 2) && mostlyNonDecreasing

        // 3) Build (time, cumulative) using endDate
        var points: [DP] = []
        points.reserveCapacity(samples.count)

        var cum = 0.0
        var cumMax = 0.0

        for s in samples {
            let v = s.quantity.doubleValue(for: meter)
            guard v.isFinite else { continue }

            if treatAsCumulative {
                cumMax = max(cumMax, v)
                cum = cumMax
            } else {
                if v > 0 { cum += v }
            }

            points.append(DP(time: s.endDate, cum: cum))
        }

        points.sort { $0.time < $1.time }
        guard points.count >= 2, (points.last?.cum ?? 0) >= targetMeters else { return nil }

        // 4) Sliding window with interpolation
        var best = Double.infinity
        var j = 1

        for i in 0..<(points.count - 1) {
            let startDist = points[i].cum
            let desired = startDist + targetMeters
            if j < i + 1 { j = i + 1 }

            while j < points.count && points[j].cum < desired { j += 1 }
            if j >= points.count { break }

            let startTime = points[i].time

            let endTime: Date = {
                if points[j].cum == desired { return points[j].time }
                // interpolate within segment j-1 -> j
                let a = points[j - 1], b = points[j]
                let segDist = b.cum - a.cum
                guard segDist > 0 else { return b.time }

                let f = (desired - a.cum) / segDist
                let clamped = max(0, min(1, f))
                let segT = b.time.timeIntervalSince(a.time)
                return a.time.addingTimeInterval(segT * clamped)
            }()

            var elapsed = endTime.timeIntervalSince(startTime)
            if elapsed <= 0 { continue }

            if timeBasis == .moving {
                elapsed = max(0, elapsed - pausedSeconds(between: startTime, and: endTime, workout: workout))
                if elapsed <= 0 { continue }
            }

            if elapsed < best { best = elapsed }
        }

        return best.isFinite ? best : nil
    }


}

//
//  SQHKWorkout.swift
//  BeastFitness
//
//  Created by Patrick Doyle on 10/14/24.
//

import Foundation
import HealthKit
import CoreLocation
import BeastFitnessCore

struct SQHKWorkout: SQWorkoutSourcable {
    let sourceId: String
    let hkWorkout: HKWorkout

    /// Enable verbose logging for pace calculations (useful for debugging)
    static var isVerbosePaceLoggingEnabled: Bool = false

    init(hkWorkout: HKWorkout) {
        self.sourceId = hkWorkout.uuid.uuidString
        self.hkWorkout = hkWorkout
    }
    
    var activityType: HKWorkoutActivityType {
        hkWorkout.workoutActivityType
    }
    
    func sumOutputFor(_ quantityTypeIdentifier: SQQuantityType) -> Double? {

        switch quantityTypeIdentifier {
        case .sqPaceRunning, .sqFastestPace, .sqTotalVolumeLifted, .unknown:
            return nil

        case .distanceWalkingRunning, .distanceCycling, .distanceSwimming, .distanceRowing, .distanceDownhillSnowSports, .distanceCrossCountrySkiing, .flightsClimbed, .activeKilocaloriesBurned, .heartRate:
            /// Continue below since these are all supported in HealhKit
            break
        }

        return hkWorkout.sumOutputFor(quantityTypeIdentifier)
    }
    
    func avgOutputFor(_ quantityTypeIdentifier: SQQuantityType) -> Double? {

        switch quantityTypeIdentifier {

        case .unknown:
            return nil

        case .sqPaceRunning, .sqTotalVolumeLifted:
            guard let totalDistance = sumOutputFor(.distanceWalkingRunning), let activeDuration else { return nil }
            print("PTD1 Distance: \(totalDistance) \(activeDuration)")
            return activeDuration / totalDistance

        case .sqFastestPace:
            return nil

        case .distanceWalkingRunning, .distanceCycling, .distanceSwimming, .distanceRowing, .distanceDownhillSnowSports, .distanceCrossCountrySkiing, .flightsClimbed, .activeKilocaloriesBurned, .heartRate:
            /// Continue below since these are all supported in HealhKit
            break
        }

        return hkWorkout.avgOutputFor(quantityTypeIdentifier)
    }

    func fastestPaceFor(_ distance: SQDistance) async -> Double? {
        // 1. Get the appropriate distance type for this activity
        guard let distanceType = hkWorkout.workoutActivityType.standardDistanceType else {
            return nil  // Activity doesn't track distance (e.g., strength training)
        }

        // 2. Get the unit used by this distance type
        guard let unit = distanceType.unit else {
            return nil  // No unit defined for this distance type
        }

        // 3. Get total workout distance in the activity's native unit
        guard let totalDistance = sumOutputFor(distanceType) else {
            return nil  // No distance data available
        }

        // 4. Convert requested distance from meters to the activity's unit
        let requestedDistance = SQUnit.convert(distance.meters, from: .meter, to: unit) ?? 0

        // 5. Check if workout is long enough
        guard totalDistance >= requestedDistance else {
            return nil  // Workout too short (e.g., 0.5 mi run can't have fastest mile)
        }

        // 6) Compute fastest time (seconds) over that distance from GPS route
        let calc = WorkoutFastestSplitCalculator(workout: hkWorkout)

        // Choose .elapsed (includes pauses) or .moving (subtracts pause/resume events)
        guard let fastestSeconds = await calc.fastestTimeSeconds(
            targetMeters: distance.meters,
            timeBasis: .moving,          // Uses moving time (excludes manual + motion pauses)
            accuracyCutoff: 50            // tweak or set nil to disable accuracy filtering
        ) else {
            if Self.isVerbosePaceLoggingEnabled {
                SQLogger.shared.log(
                    "No route data for workout \(hkWorkout.uuid)",
                    .debug,
                    context: .healthKit
                )
            }
            return nil
        }

        guard fastestSeconds > 0 else {
            if Self.isVerbosePaceLoggingEnabled {
                SQLogger.shared.log(
                    "Invalid fastestSeconds (\(fastestSeconds)) for workout \(hkWorkout.uuid)",
                    .error,
                    context: .healthKit
                )
            }
            return nil
        }

        // 7) Convert to pace per mile (seconds per mile)
        // - distance.miles is the distance covered in miles
        // - fastestSeconds is the time it took
        // - Pace = time / distance in miles
        guard distance.miles > 0 else {
            if Self.isVerbosePaceLoggingEnabled {
                SQLogger.shared.log(
                    "Invalid distance.miles (\(distance.miles)) for distance \(distance)",
                    .error,
                    context: .healthKit
                )
            }
            return nil
        }

        let pacePerMile = fastestSeconds / distance.miles

        // Validate the result is reasonable based on activity type
        let paceRange = reasonablePaceRange(for: hkWorkout.workoutActivityType)
        guard pacePerMile >= paceRange.min && pacePerMile <= paceRange.max else {
            if Self.isVerbosePaceLoggingEnabled {
                SQLogger.shared.log(
                    "Unreasonable pace (\(pacePerMile) sec/mile = \(pacePerMile.timeCode())) for \(hkWorkout.workoutActivityType.name) workout \(hkWorkout.uuid). Expected range: \(paceRange.min.timeCode())-\(paceRange.max.timeCode()). FastestSeconds: \(fastestSeconds), distance.miles: \(distance.miles)",
                    .error,
                    context: .healthKit
                )
            }
            return nil
        }

        if Self.isVerbosePaceLoggingEnabled {
            SQLogger.shared.log(
                "Calculated pace: \(pacePerMile.timeCode()) per mile for \(hkWorkout.workoutActivityType.name) workout \(hkWorkout.uuid)",
                .debug,
                context: .healthKit
            )
        }

        return pacePerMile
    }

    /// Returns reasonable pace range (in seconds per mile) for a given activity type
    /// These ranges are extremely lenient to avoid filtering out any legitimate data
    private func reasonablePaceRange(for activityType: HKWorkoutActivityType) -> (min: Double, max: Double) {
        switch activityType {
        case .running, .walking, .hiking:
            // 2 min/mile (30 mph sprint) to 10 hours/mile (0.1 mph crawl)
            return (1, 500000)

        case .cycling, .handCycling:
            // 18 sec/mile (200 mph) to 10 hours/mile (0.1 mph uphill/stopped)
            return (1, 500000)

        case .swimming:
            // 5 min/mile (12 mph) to 10 hours/mile (0.1 mph)
            return (1, 500000)

        case .rowing:
            // 1 min/mile (60 mph) to 10 hours/mile (0.1 mph)
            return (1, 500000)

        case .crossCountrySkiing:
            // 1 min/mile (60 mph) to 10 hours/mile (0.1 mph)
            return (1, 500000)

        case .downhillSkiing, .snowboarding:
            // 10 sec/mile (360 mph) to 10 hours/mile (0.1 mph)
            return (1, 500000)

        default:
            // Generic fallback: catch only obviously corrupt data
            return (1, 500000)
        }
    }

    var activeDuration: Double? {
        workoutActiveDuration(from: hkWorkout)
    }
    
    var startDate: Date? {
        hkWorkout.startDate
    }
    
    var endDate: Date? {
        hkWorkout.endDate
    }
    
    var device: SQWorkoutDevice? {
        guard let device = hkWorkout.device else { return nil }
        return .init(name: device.friendlyDescription)
    }

    // TODO: - Pass workout details for existing HK workouts if they exist
    var details: SQWorkoutActivityDetails? {
        nil
    }
    
    func workoutActiveDuration(from workout: HKWorkout) -> TimeInterval {
        // Use a non-optional for calculations
        let totalDuration: TimeInterval = workout.duration ?? 0

        // Optional only for logging if you want the nil behavior
        let totalDurationForLog: TimeInterval? = workout.duration   // change this if your "nil" total comes from elsewhere

        guard var events = workout.workoutEvents, !events.isEmpty else {
            SQLogger.shared.log(
                "⚠️ No workout events found - using total duration: \(totalDurationForLog?.timeCode() ?? "nil")",
                .debug,
                context: .healthKit
            )
            return totalDuration
        }

        events.sort { $0.dateInterval.start < $1.dateInterval.start }

        let pauseCount = events.filter { $0.type == .pause }.count
        let resumeCount = events.filter { $0.type == .resume }.count
        let motionPausedCount = events.filter { $0.type == .motionPaused }.count
        let motionResumedCount = events.filter { $0.type == .motionResumed }.count

        SQLogger.shared.log(
            "📊 Workout events: manual pause/resume: \(pauseCount)/\(resumeCount), motion pause/resume: \(motionPausedCount)/\(motionResumedCount)",
            .debug,
            context: .healthKit
        )

        var activeTime: TimeInterval = 0
        var lastStart = workout.startDate

        var isPaused = false
        var pauseStart: Date? = nil
        var totalPausedTime: TimeInterval = 0

        for event in events {
            let t = event.dateInterval.start

            switch event.type {
            case .pause, .motionPaused:
                // Ignore redundant pauses
                guard !isPaused else { break }

                let seg = t.timeIntervalSince(lastStart)
                if seg > 0 { activeTime += seg }

                isPaused = true
                pauseStart = t

            case .resume, .motionResumed:
                // Ignore redundant resumes
                guard isPaused else { break }

                if let ps = pauseStart {
                    let pausedSeg = t.timeIntervalSince(ps)
                    if pausedSeg > 0 { totalPausedTime += pausedSeg }
                }

                lastStart = t
                isPaused = false
                pauseStart = nil

            default:
                break
            }
        }

        // Only add tail if we ended unpaused
        if !isPaused {
            let tail = workout.endDate.timeIntervalSince(lastStart)
            if tail > 0 { activeTime += tail }
        }

        SQLogger.shared.log(
            "⏱️ Duration calc: Total: \(totalDurationForLog?.timeCode() ?? "nil"), Active: \(activeTime.timeCode()), Paused: \(totalPausedTime.timeCode()), EndedPaused: \(isPaused)",
            .debug,
            context: .healthKit,
            isPriority: true
        )

        // Fallback sanity checks
        if activeTime <= 0 { return totalDuration }

        // Don’t let active exceed total by more than a small tolerance (clock jitter)
        if activeTime > totalDuration + 5 {
            return totalDuration
        }

        return activeTime
    }


}

import Foundation
import HealthKit
import CoreLocation

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

}

// MARK: - Helpers: formatting pace

extension Double {
    /// Converts seconds to "m:ss" (or "h:mm:ss" if >= 1 hour)
    var asPaceString: String {
        guard self.isFinite, self >= 0 else { return "--:--" }
        let total = Int(self.rounded())
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let seconds = total % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%d:%02d", minutes, seconds)
        }
    }
}

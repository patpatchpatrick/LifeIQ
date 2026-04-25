//
//  WorkoutSplitsCalculator.swift
//  BeastFitness
//

import Foundation
import HealthKit
import CoreLocation

struct SQWorkoutSplit: Sendable {
    let index: Int
    let startDate: Date
    let endDate: Date
    let distanceMeters: Double

    var durationSeconds: Double {
        max(0, endDate.timeIntervalSince(startDate))
    }
}

private struct SQDistanceTimelinePoint {
    let time: Date
    let cumulativeDistance: Double
}

final class WorkoutSplitsCalculator {
    private let healthStore: HKHealthStore
    private let workout: HKWorkout

    init(healthStore: HKHealthStore = HKHealthStore(), workout: HKWorkout) {
        self.healthStore = healthStore
        self.workout = workout
    }

    func consecutiveSplits(
        targetMeters: Double,
        distanceType: SQQuantityType,
        timeBasis: WorkoutFastestSplitCalculator.TimeBasis = .moving,
        accuracyCutoff: CLLocationAccuracy? = 50,
        routeLocations: [CLLocation]? = nil
    ) async -> [SQWorkoutSplit]? {
        guard targetMeters > 0 else { return nil }

        if let routeSplits = await consecutiveSplitsFromRoute(
            targetMeters: targetMeters,
            timeBasis: timeBasis,
            accuracyCutoff: accuracyCutoff,
            routeLocations: routeLocations
        ), !routeSplits.isEmpty {
            return routeSplits
        }

        if let distanceSampleSplits = await consecutiveSplitsFromDistanceSamples(
            targetMeters: targetMeters,
            distanceType: distanceType,
            timeBasis: timeBasis
        ), !distanceSampleSplits.isEmpty {
            return distanceSampleSplits
        }

        return nil
    }

    private func consecutiveSplitsFromRoute(
        targetMeters: Double,
        timeBasis: WorkoutFastestSplitCalculator.TimeBasis,
        accuracyCutoff: CLLocationAccuracy?,
        routeLocations: [CLLocation]?
    ) async -> [SQWorkoutSplit]? {
        let resolvedLocations: [CLLocation]?
        if let routeLocations {
            resolvedLocations = routeLocations
        } else {
            resolvedLocations = await fetchAllWorkoutRouteLocations()
        }

        guard var locations = resolvedLocations else {
            return nil
        }

        if let cutoff = accuracyCutoff {
            locations = locations.filter { $0.horizontalAccuracy >= 0 && $0.horizontalAccuracy <= cutoff }
        }

        locations.sort { $0.timestamp < $1.timestamp }
        locations = dedupeByTimestampKeepingBestAccuracy(locations)

        guard locations.count >= 2 else { return nil }

        let cumulative = buildCumulativeDistance(locations: locations)
        let totalDistance = cumulative.last ?? 0
        let splitCount = Int(totalDistance / targetMeters)
        guard splitCount > 0 else { return nil }

        var splits = [SQWorkoutSplit]()
        splits.reserveCapacity(splitCount)

        var startSearchIndex = 1
        var endSearchIndex = 1

        for splitIndex in 0..<splitCount {
            let startDistance = Double(splitIndex) * targetMeters
            let endDistance = Double(splitIndex + 1) * targetMeters

            guard let startResult = timeAtDistance(
                targetDistance: startDistance,
                locations: locations,
                cumulative: cumulative,
                lowerBoundIndex: startSearchIndex
            ), let endResult = timeAtDistance(
                targetDistance: endDistance,
                locations: locations,
                cumulative: cumulative,
                lowerBoundIndex: max(endSearchIndex, startResult.index)
            ) else {
                return splits.isEmpty ? nil : splits
            }

            startSearchIndex = startResult.index
            endSearchIndex = endResult.index

            var endDate = endResult.date
            if timeBasis == .moving {
                let pausedSeconds = pausedSeconds(
                    between: startResult.date,
                    and: endResult.date,
                    workout: workout
                )
                endDate = endDate.addingTimeInterval(-pausedSeconds)
            }

            guard endDate > startResult.date else { continue }

            splits.append(
                SQWorkoutSplit(
                    index: splitIndex + 1,
                    startDate: startResult.date,
                    endDate: endDate,
                    distanceMeters: targetMeters
                )
            )
        }

        return splits.isEmpty ? nil : splits
    }

    private func consecutiveSplitsFromDistanceSamples(
        targetMeters: Double,
        distanceType: SQQuantityType,
        timeBasis: WorkoutFastestSplitCalculator.TimeBasis
    ) async -> [SQWorkoutSplit]? {
        guard let identifier = distanceType.hkQuantityTypeIdentifier,
              let quantityType = HKQuantityType.quantityType(forIdentifier: identifier) else {
            return nil
        }

        let samples = await fetchDistanceSamples(quantityType: quantityType)
        guard samples.count >= 2 else { return nil }

        let meterUnit = HKUnit.meter()
        let values = samples.map { $0.quantity.doubleValue(for: meterUnit) }
        let startsNearWorkoutStartCount = samples.filter {
            abs($0.startDate.timeIntervalSince(workout.startDate)) < 1
        }.count
        let mostlyNonDecreasing = zip(values, values.dropFirst()).filter { $1 >= $0 }.count > (values.count * 3 / 4)
        let treatAsCumulative = startsNearWorkoutStartCount > (samples.count / 2) && mostlyNonDecreasing

        var points = [SQDistanceTimelinePoint]()
        points.reserveCapacity(samples.count)

        var cumulativeDistance = 0.0
        var maxCumulativeDistance = 0.0

        for sample in samples {
            let value = sample.quantity.doubleValue(for: meterUnit)
            guard value.isFinite else { continue }

            if treatAsCumulative {
                maxCumulativeDistance = max(maxCumulativeDistance, value)
                cumulativeDistance = maxCumulativeDistance
            } else if value > 0 {
                cumulativeDistance += value
            }

            points.append(.init(time: sample.endDate, cumulativeDistance: cumulativeDistance))
        }

        points.sort { $0.time < $1.time }

        let totalDistance = points.last?.cumulativeDistance ?? 0
        let splitCount = Int(totalDistance / targetMeters)
        guard splitCount > 0 else { return nil }

        var splits = [SQWorkoutSplit]()
        splits.reserveCapacity(splitCount)

        var startSearchIndex = 1
        var endSearchIndex = 1

        for splitIndex in 0..<splitCount {
            let startDistance = Double(splitIndex) * targetMeters
            let endDistance = Double(splitIndex + 1) * targetMeters

            guard let startResult = timeAtDistance(
                targetDistance: startDistance,
                points: points,
                lowerBoundIndex: startSearchIndex
            ), let endResult = timeAtDistance(
                targetDistance: endDistance,
                points: points,
                lowerBoundIndex: max(endSearchIndex, startResult.index)
            ) else {
                return splits.isEmpty ? nil : splits
            }

            startSearchIndex = startResult.index
            endSearchIndex = endResult.index

            var endDate = endResult.date
            if timeBasis == .moving {
                let pausedSeconds = pausedSeconds(
                    between: startResult.date,
                    and: endResult.date,
                    workout: workout
                )
                endDate = endDate.addingTimeInterval(-pausedSeconds)
            }

            guard endDate > startResult.date else { continue }

            splits.append(
                SQWorkoutSplit(
                    index: splitIndex + 1,
                    startDate: startResult.date,
                    endDate: endDate,
                    distanceMeters: targetMeters
                )
            )
        }

        return splits.isEmpty ? nil : splits
    }

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

                if error != nil {
                    continuation.resume(returning: nil)
                    return
                }

                let routes = (samples as? [HKWorkoutRoute]) ?? []
                guard !routes.isEmpty else {
                    continuation.resume(returning: nil)
                    return
                }

                Task {
                    var locations = [CLLocation]()
                    for route in routes {
                        if let routeLocations = await self.fetchLocations(for: route) {
                            locations.append(contentsOf: routeLocations)
                        }
                    }

                    continuation.resume(returning: locations.isEmpty ? nil : locations)
                }
            }

            healthStore.execute(routeQuery)
        }
    }

    private func fetchLocations(for route: HKWorkoutRoute) async -> [CLLocation]? {
        await withCheckedContinuation { continuation in
            var locations = [CLLocation]()

            let query = HKWorkoutRouteQuery(route: route) { _, newLocations, done, error in
                if error != nil {
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

            healthStore.execute(query)
        }
    }

    private func fetchDistanceSamples(quantityType: HKQuantityType) async -> [HKQuantitySample] {
        let sortDescriptors = [NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: true)]

        func runQuery(predicate: NSPredicate) async -> [HKQuantitySample] {
            (try? await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[HKQuantitySample], Error>) in
                let query = HKSampleQuery(
                    sampleType: quantityType,
                    predicate: predicate,
                    limit: HKObjectQueryNoLimit,
                    sortDescriptors: sortDescriptors
                ) { _, samples, error in
                    if let error {
                        continuation.resume(throwing: error)
                        return
                    }

                    continuation.resume(returning: (samples as? [HKQuantitySample]) ?? [])
                }

                healthStore.execute(query)
            }) ?? []
        }

        let workoutPredicate = HKQuery.predicateForObjects(from: workout)
        let samplesFromWorkout = await runQuery(predicate: workoutPredicate)
        if samplesFromWorkout.count >= 2 {
            return samplesFromWorkout
        }

        let datePredicate = HKQuery.predicateForSamples(
            withStart: workout.startDate,
            end: workout.endDate,
            options: [.strictStartDate, .strictEndDate]
        )
        return await runQuery(predicate: datePredicate)
    }

    private func timeAtDistance(
        targetDistance: Double,
        locations: [CLLocation],
        cumulative: [Double],
        lowerBoundIndex: Int
    ) -> (date: Date, index: Int)? {
        guard !locations.isEmpty else { return nil }

        if targetDistance <= 0 {
            return (locations[0].timestamp, max(1, lowerBoundIndex))
        }

        var index = max(1, lowerBoundIndex)
        while index < cumulative.count && cumulative[index] < targetDistance {
            index += 1
        }

        guard index < cumulative.count else { return nil }

        if cumulative[index] == targetDistance {
            return (locations[index].timestamp, index)
        }

        let date = interpolateTimeAtDistance(
            previousDate: locations[index - 1].timestamp,
            nextDate: locations[index].timestamp,
            previousDistance: cumulative[index - 1],
            nextDistance: cumulative[index],
            targetDistance: targetDistance
        )
        return (date, index)
    }

    private func timeAtDistance(
        targetDistance: Double,
        points: [SQDistanceTimelinePoint],
        lowerBoundIndex: Int
    ) -> (date: Date, index: Int)? {
        guard !points.isEmpty else { return nil }

        if targetDistance <= 0 {
            return (points[0].time, max(1, lowerBoundIndex))
        }

        var index = max(1, lowerBoundIndex)
        while index < points.count && points[index].cumulativeDistance < targetDistance {
            index += 1
        }

        guard index < points.count else { return nil }

        if points[index].cumulativeDistance == targetDistance {
            return (points[index].time, index)
        }

        let previousPoint = points[index - 1]
        let nextPoint = points[index]
        let date = interpolateTimeAtDistance(
            previousDate: previousPoint.time,
            nextDate: nextPoint.time,
            previousDistance: previousPoint.cumulativeDistance,
            nextDistance: nextPoint.cumulativeDistance,
            targetDistance: targetDistance
        )
        return (date, index)
    }

    private func buildCumulativeDistance(locations: [CLLocation]) -> [Double] {
        var cumulative = Array(repeating: 0.0, count: locations.count)
        var total = 0.0

        for index in 1..<locations.count {
            let distance = locations[index].distance(from: locations[index - 1])
            if distance.isFinite, distance > 0 {
                total += distance
            }
            cumulative[index] = total
        }

        return cumulative
    }

    private func interpolateTimeAtDistance(
        previousDate: Date,
        nextDate: Date,
        previousDistance: Double,
        nextDistance: Double,
        targetDistance: Double
    ) -> Date {
        let distance = nextDistance - previousDistance
        guard distance > 0 else { return nextDate }

        let fraction = max(0, min(1, (targetDistance - previousDistance) / distance))
        let duration = nextDate.timeIntervalSince(previousDate)
        return previousDate.addingTimeInterval(duration * fraction)
    }

    private func dedupeByTimestampKeepingBestAccuracy(_ locations: [CLLocation]) -> [CLLocation] {
        guard locations.count >= 2 else { return locations }

        var deduped = [CLLocation]()
        deduped.reserveCapacity(locations.count)

        var index = 0
        while index < locations.count {
            var best = locations[index]
            var nextIndex = index + 1

            while nextIndex < locations.count && locations[nextIndex].timestamp == best.timestamp {
                let bestAccuracy = best.horizontalAccuracy
                let candidateAccuracy = locations[nextIndex].horizontalAccuracy
                if candidateAccuracy >= 0 && (bestAccuracy < 0 || candidateAccuracy < bestAccuracy) {
                    best = locations[nextIndex]
                }
                nextIndex += 1
            }

            deduped.append(best)
            index = nextIndex
        }

        return deduped
    }

    private func pausedSeconds(between start: Date, and end: Date, workout: HKWorkout) -> TimeInterval {
        guard start < end, let events = workout.workoutEvents, !events.isEmpty else { return 0 }

        var pausedSeconds: TimeInterval = 0
        var pausedAt: Date? = nil

        for event in events {
            switch event.type {
            case .pause, .motionPaused:
                pausedAt = event.dateInterval.start

            case .resume, .motionResumed:
                if let pausedAt {
                    pausedSeconds += overlapSeconds(
                        start: start,
                        end: end,
                        otherStart: pausedAt,
                        otherEnd: event.dateInterval.start
                    )
                }
                pausedAt = nil

            default:
                break
            }
        }

        if let pausedAt {
            pausedSeconds += overlapSeconds(
                start: start,
                end: end,
                otherStart: pausedAt,
                otherEnd: end
            )
        }

        return pausedSeconds
    }

    private func overlapSeconds(
        start: Date,
        end: Date,
        otherStart: Date,
        otherEnd: Date
    ) -> TimeInterval {
        let overlapStart = max(start, otherStart)
        let overlapEnd = min(end, otherEnd)
        return max(0, overlapEnd.timeIntervalSince(overlapStart))
    }
}

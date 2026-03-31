//
//  SQHealthKitManager.swift
//  BeastFitness
//
//  Created by Patrick Doyle on 10/14/24.
//

import Foundation
import HealthKit
import BeastFitnessCore
import CoreLocation

protocol SQHealthKitManaging {
    @discardableResult
    func saveWorkout(workout: SQWorkoutSessionable) async throws -> HKWorkout?
    func deleteWorkout(with healthKitId: String) async throws

    /// Latest available VO₂ max sample (ml/kg/min). Returns nil if the user has no samples.
    func fetchLatestVO2Max() async throws -> SQVO2MaxSample?

    /// VO₂ max samples in a time range (ascending by date).
    func fetchVO2MaxSamples(_ timeRange: SQTimeRange) async throws -> [SQVO2MaxSample]

    /// The N most-recent VO₂ max samples recorded on or before the calendar day of `date`,
    /// sorted descending by endDate.
    func fetchVO2MaxSamples(upTo date: Date, limit: Int) async throws -> [SQVO2MaxSample]

    /// Most recent VO₂ max sample whose endDate is strictly before `date`.
    func fetchLatestVO2MaxSample(strictlyBefore date: Date) async throws -> SQVO2MaxSample?

    /// Most recent VO₂ max sample whose startDate is on or after `date` and
    /// falls within the same calendar day as `endOfDay`.
    func fetchLatestVO2MaxSample(onOrAfter date: Date, throughEndOfDay endOfDay: Date) async throws -> SQVO2MaxSample?

    @MainActor
    func invalidateCache()

    /// Fetches workouts within a time range from HealthKit.
    @MainActor
    func fetchWorkouts(_ timeRange: SQTimeRange) async throws -> [HKWorkout]

    /// Returns all route points for a workout (may be empty if no GPS).
    func fetchRouteLocations(for workout: HKWorkout) async throws -> [CLLocation]

    /// Same, but you pass your saved HealthKit UUID string.
    func fetchRouteLocations(for healthKitId: String) async throws -> [CLLocation]

    /// Reads the weather temperature (in °C) recorded by Apple Watch during a workout.
    /// Returns nil if the workout has no weather metadata.
    func weatherTemperatureCelsius(from workout: HKWorkout) -> Double?

    /// Fetch sleep stage segments overlapping the provided interval.
    /// The caller can then aggregate by nights/time ranges.
    func fetchSleepSegments(from startDate: Date, to endDate: Date) async throws -> [SQSleepStageSegment]

    /// Daily average/min/max heart-rate summaries for the selected range.
    func fetchDailyHeartRateSummaries(_ timeRange: SQTimeRange) async throws -> [SQHeartRateDailySummary]

    /// Daily resting heart-rate summaries for the selected range.
    func fetchDailyRestingHeartRateSummaries(_ timeRange: SQTimeRange) async throws -> [SQHeartRateDailySummary]

    /// Per-interval heart-rate averages for a workout.
    func fetchWorkoutHeartRateSummaries(for workout: HKWorkout) async throws -> [SQHeartRateIntervalSummary]

    /// Same, but you pass your saved HealthKit UUID string.
    func fetchWorkoutHeartRateSummaries(for healthKitId: String) async throws -> [SQHeartRateIntervalSummary]
}


final class SQHealthKitManager: SQHealthKitManaging {
    static let shared = SQHealthKitManager()
    static let healthStore: HKHealthStore = HKHealthStore()
    
    let allTypesToReadWrite: Set<HKSampleType> = [
        HKObjectType.workoutType(),
        HKSeriesType.workoutRoute(),

        HKQuantityType(.activeEnergyBurned),
        HKQuantityType(.distanceCycling),
        HKQuantityType(.distanceWalkingRunning),
        HKQuantityType(.distanceWheelchair),
        HKQuantityType(.heartRate),
        HKQuantityType(.vo2Max),

        HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!
    ]

    
    private let userDefaults = UserDefaults.standard
    private let anchorKeyPrefix = "Anchor_"

    // MARK: - Cache

    struct WorkoutCacheEntry {
        let workouts: [HKWorkout]
        let fetchedAt: Date
        var isStale: Bool { Date().timeIntervalSince(fetchedAt) > 300 } // 5 min TTL
    }

    struct VO2MaxCacheEntry {
        let samples: [SQVO2MaxSample]
        let fetchedAt: Date
        var isStale: Bool { Date().timeIntervalSince(fetchedAt) > 300 } // 5 min TTL
    }

    private var workoutCache: [SQTimeRange: WorkoutCacheEntry] = [:]
    var vo2MaxCache: [SQTimeRange: VO2MaxCacheEntry] = [:]

    @MainActor @discardableResult
    func saveWorkout(
        workout: SQWorkoutSessionable
    ) async throws -> HKWorkout? {
        
        guard let startDate = workout.startDate else {
               // You need a start date for HealthKit
               return nil
           }

        let endDate = workout.endDate ?? .now
        
        try await Self.healthStore.requestAuthorization(
            toShare: allTypesToReadWrite,
            read: allTypesToReadWrite
        )

        // TODO: - Finish configuration, add calories, heartRate, locationType, etc..
        let configuration = HKWorkoutConfiguration()
        configuration.activityType = workout.activityType

        let builder = HKWorkoutBuilder(
            healthStore: Self.healthStore,
            configuration: configuration,
            device: .local()
        )

        try await builder.addMetadata(workoutMetadata(for: workout))
        
        try await builder.beginCollection(at: startDate)
        
        try await builder.addWorkoutActivity(.init(
            workoutConfiguration: configuration,
            start: startDate,
            end: endDate,
            metadata: nil))
        
        // TODO: - Hack to add inactive time for now, update later to properly use workout events
        if
            let startDate = workout.startDate,
            let endDate = workout.endDate,
            let activeDuration = workout.activeDuration
        {
            let approxPauseDate = startDate.addingTimeInterval(activeDuration)

            if approxPauseDate < endDate {
                // Pause at approxPauseDate, resume at endDate (or omit resume since workout ends)
                try await builder.addWorkoutEvents([
                    HKWorkoutEvent(
                        type: .pause,
                        dateInterval: DateInterval(start: approxPauseDate, end: approxPauseDate),
                        metadata: nil
                    )
                ])
            }
        }
        
        try await builder.endCollection(at: endDate)

        SQLogger.shared.log("Attempting to save workout to HealthKit", .debug, context: .healthKit)
        
        do {
            let workout = try await builder.finishWorkout()
            SQLogger.shared.log("Save workout to HealthKit success!", .debug, context: .healthKit)
            return workout
        } catch {
            SQLogger.shared.log("Save workout to HealthKit failed with error: \(error)", .debug, context: .healthKit)
            throw error
        }
    }

    private func workoutMetadata(for workout: SQWorkoutSessionable) -> [String: Any] {
        var metadata: [String: Any] = [
            HKMetadataKeySyncIdentifier: workout.id,
            HKMetadataKeySyncVersion: 1
        ]

        if UUID(uuidString: workout.id) != nil {
            metadata[HKMetadataKeyExternalUUID] = workout.id
        }

        return metadata
    }
    
    func deleteWorkout(with healthKitId: String) async throws {
        let healthStore = HKHealthStore()
        
        guard let uuid = UUID(uuidString: healthKitId) else {
            SQLogger.shared.log("Unexpected UUID format when deleting workout with hkId: \(healthKitId)", .error, context: .healthKit)
            throw SQError.standard(withDescription: "Unexpected UUID format")
        }

        let predicate = HKQuery.predicateForObject(with: uuid)
        let sampleType = HKObjectType.workoutType()

        let workouts : [HKWorkout] = try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: sampleType,
                predicate: predicate,
                limit: 1,
                sortDescriptors: nil
            ) { _, samples, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: samples as? [HKWorkout] ?? [])
                }
            }
            healthStore.execute(query)
        }

        guard let workout = workouts.first else {
            throw SQError.standard(withDescription: "HealthKit workout not found")
        }

        try await healthStore.delete(workout)
    }
    
    @MainActor
    func fetchWorkouts(_ timeRange: SQTimeRange) async throws -> [HKWorkout] {
        // Return cached result if fresh
        if let cached = workoutCache[timeRange], !cached.isStale {
            SQLogger.shared.log(
                "↩️ Workout cache hit for \(timeRange.rawValue) (\(cached.workouts.count) workouts)",
                .debug,
                context: .healthKit
            )
            return cached.workouts
        }

        guard HKHealthStore.isHealthDataAvailable() else {
            throw SQError.standard
        }

        try await Self.healthStore.requestAuthorization(
            toShare: allTypesToReadWrite,
            read: allTypesToReadWrite
        )

        let predicate = HKQuery.predicateForSamples(
            withStart: timeRange.startDate,
            end: timeRange.endDate
        )

        let limit = HKObjectQueryNoLimit
        let workoutType: HKSampleType = .workoutType()

        var workouts = try await executeQuery(
            sampleType: workoutType,
            predicate: predicate,
            anchor: nil,
            limit: limit
        )

        workouts = Self.filterDuplicateWorkouts(workouts)
        workouts = workouts.filter { $0.workoutActivityType != .other }

        workoutCache[timeRange] = WorkoutCacheEntry(workouts: workouts, fetchedAt: .now)
        SQLogger.shared.log(
            "💾 Workout cache populated for \(timeRange.rawValue) (\(workouts.count) workouts)",
            .debug,
            context: .healthKit
        )

        return workouts
    }

    @MainActor
    func invalidateCache() {
        workoutCache.removeAll()
        vo2MaxCache.removeAll()
        SQLogger.shared.log("HealthKit cache invalidated", .debug, context: .healthKit)
    }

    // MARK: - Anchors
    
    func anchorKey(for type: HKSampleType) -> String {
        return anchorKeyPrefix + type.identifier
    }
    
    func getAnchor(for type: HKSampleType) -> HKQueryAnchor? {
        if let anchorData = userDefaults.object(forKey: anchorKey(for: type)) as? Data {
            return try? NSKeyedUnarchiver.unarchivedObject(ofClass: HKQueryAnchor.self, from: anchorData)
        }
        return nil
    }
    
    func setAnchor(_ queryAnchor: HKQueryAnchor?, for type: HKSampleType) {
        if let queryAnchor = queryAnchor,
           let data = try? NSKeyedArchiver.archivedData(withRootObject: queryAnchor, requiringSecureCoding: true) {
            userDefaults.set(data, forKey: anchorKey(for: type))
        }
    }
    
    func updateAnchor(_ newAnchor: HKQueryAnchor?, from query: HKAnchoredObjectQuery) {
        if let sampleType = query.objectType as? HKSampleType {
            setAnchor(newAnchor, for: sampleType)
        } else if let identifier = query.objectType?.identifier {
            print("anchoredObjectQueryDidUpdate error: Did not save anchor for \(identifier) – Not an HKSampleType.")
        } else {
            print("anchoredObjectQueryDidUpdate error: query doesn't have a non-nil objectType.")
        }
    }
    
    // MARK: - Query execution
    
    func executeQuery(
        sampleType: HKSampleType,
        predicate: NSPredicate?,
        anchor: HKQueryAnchor?,
        limit: Int
    ) async throws -> [HKWorkout] {
        try await withCheckedThrowingContinuation { continuation in
            let query = HKAnchoredObjectQuery(
                type: sampleType,
                predicate: predicate,
                anchor: anchor,
                limit: limit
            ) { [weak self] query, samplesOrNil, deletedObjectsOrNil, newAnchor, errorOrNil in
                guard let self = self else { return }

                if let error = errorOrNil {
                    SQLogger.shared.log(
                        "HKAnchoredObjectQuery initialResultsHandler with identifier \(sampleType.identifier) error: \(error.localizedDescription)",
                        .error,
                        context: .dataProcessing
                    )
                    continuation.resume(throwing: error)
                    return
                }

                SQLogger.shared.log(
                    "HKAnchoredObjectQuery initialResultsHandler has returned for \(sampleType.identifier)",
                    .debug,
                    context: .dataProcessing
                )

                // Update anchor for sample type
                self.updateAnchor(newAnchor, from: query)

                let hkWorkouts = samplesOrNil?.compactMap { $0 as? HKWorkout } ?? []
                continuation.resume(returning: hkWorkouts)
            }

            Self.healthStore.execute(query)
        }
    }
}

// MARK: - Routes

extension SQHealthKitManager {
    
    private func fetchRoutes(for workout: HKWorkout) async throws -> [HKWorkoutRoute] {
        let routeType = HKSeriesType.workoutRoute()
        let predicate = HKQuery.predicateForObjects(from: workout)

        return try await withCheckedThrowingContinuation { continuation in
            let q = HKSampleQuery(
                sampleType: routeType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: nil
            ) { _, samples, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                continuation.resume(returning: (samples as? [HKWorkoutRoute]) ?? [])
            }

            Self.healthStore.execute(q)
        }
    }
    
    private func readLocations(for route: HKWorkoutRoute) async throws -> [CLLocation] {
        try await withCheckedThrowingContinuation { continuation in
            var all: [CLLocation] = []

            let q = HKWorkoutRouteQuery(route: route) { _, locations, done, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                if let locations {
                    all.append(contentsOf: locations)
                }

                if done {
                    continuation.resume(returning: all)
                }
            }

            Self.healthStore.execute(q)
        }
    }
    
    func fetchRouteLocations(for workout: HKWorkout) async throws -> [CLLocation] {
        try await Self.healthStore.requestAuthorization(
            toShare: allTypesToReadWrite,
            read: allTypesToReadWrite
        )

        let routes = try await fetchRoutes(for: workout)
        guard routes.isEmpty == false else { return [] }

        var allLocations: [CLLocation] = []
        allLocations.reserveCapacity(2048)

        for route in routes {
            let locations = try await readLocations(for: route)
            allLocations.append(contentsOf: locations)
        }

        // Ensure chronological order for drawing polylines / distance calc
        allLocations.sort { $0.timestamp < $1.timestamp }
        return allLocations
    }
    
    func fetchRouteLocations(for healthKitId: String) async throws -> [CLLocation] {
        guard let uuid = UUID(uuidString: healthKitId) else {
            throw SQError.standard(withDescription: "Unexpected UUID format")
        }

        let workoutType = HKObjectType.workoutType()
        let predicate = HKQuery.predicateForObject(with: uuid)

        let workouts: [HKWorkout] = try await withCheckedThrowingContinuation { continuation in
            let q = HKSampleQuery(sampleType: workoutType, predicate: predicate, limit: 1, sortDescriptors: nil) {
                _, samples, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: (samples as? [HKWorkout]) ?? [])
                }
            }
            Self.healthStore.execute(q)
        }

        guard let workout = workouts.first else {
            throw SQError.standard(withDescription: "HealthKit workout not found")
        }

        return try await fetchRouteLocations(for: workout)
    }

    func weatherTemperatureCelsius(from workout: HKWorkout) -> Double? {
        print("PTD Weather 1", workout.startDate)
        guard let quantity = workout.metadata?[HKMetadataKeyWeatherTemperature] as? HKQuantity else {
            return nil
        }
        print("PTD Weather 2", quantity, workout.startDate)
        return quantity.doubleValue(for: .degreeCelsius())
    }
}

enum SQHealthKitError: Error {
    case healthDataUnavailable
    case authorizationFailed
}


// MARK: - Filter duplicates

extension SQHealthKitManager {
    
    /// Filters out likely duplicate workouts.
    /// Duplicates are defined as workouts with the same activity type whose
    /// time ranges either:
    ///  - start & end within a small tolerance, OR
    ///  - overlap by a large percentage of their duration.
    ///
    /// If a duplicate is found, we prefer the workout with heart rate metadata (if available).
    static func filterDuplicateWorkouts(_ workouts: [HKWorkout]) -> [HKWorkout] {
        let sorted = workouts.sorted { lhs, rhs in
            lhs.startDate < rhs.startDate
        }
        
        var unique: [HKWorkout] = []
        
        for workout in sorted {
            let start = workout.startDate
            let end = workout.endDate
            
            let duplicateIndex = unique.firstIndex { existing in
                guard existing.workoutActivityType == workout.workoutActivityType else {
                    return false
                }
                
                let existingStart = existing.startDate
                let existingEnd = existing.endDate
                
                // 1) Near-identical start/end times
                let startDiff = abs(existingStart.timeIntervalSince(start))
                let endDiff = abs(existingEnd.timeIntervalSince(end))
                let timeTolerance: TimeInterval = 10
                
                if startDiff <= timeTolerance && endDiff <= timeTolerance {
                    return true
                }
                
                // 2) High overlap ratio
                let overlap = min(existingEnd, end).timeIntervalSince(max(existingStart, start))
                if overlap <= 0 { return false }
                
                let existingDuration = existingEnd.timeIntervalSince(existingStart)
                let workoutDuration = end.timeIntervalSince(start)
                let minDuration = min(existingDuration, workoutDuration)
                guard minDuration > 0 else { return false }
                
                let overlapRatio = overlap / minDuration
                let overlapThreshold: Double = 0.9
                
                return overlapRatio >= overlapThreshold
            }
            
            func hasHeartRateData(_ workout: HKWorkout) -> Bool {
                let hrType = HKQuantityType.quantityType(forIdentifier: .heartRate)!
                guard let stats = workout.statistics(for: hrType) else { return false }
                return stats.averageQuantity() != nil || stats.maximumQuantity() != nil
            }

            if let idx = duplicateIndex {
                let existing = unique[idx]

                let existingHasHR = hasHeartRateData(existing)
                let newHasHR = hasHeartRateData(workout)
                
                if newHasHR && !existingHasHR {
                    unique[idx] = workout
                }
            } else {
                unique.append(workout)
            }
        }
        
        return unique
    }
}

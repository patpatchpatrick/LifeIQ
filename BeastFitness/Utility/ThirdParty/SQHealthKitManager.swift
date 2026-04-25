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

enum SQHealthKitDashboardAccessStatus {
    case available
    case unavailable
}

enum SQHealthKitDashboardDomain {
    case workouts
    case sleep
    case heart
    case vo2Max
}

actor SQHealthKitAuthorizationCoordinator {
    private var inFlightAuthorizationTask: Task<Void, Error>?

    func authorize(
        healthStore: HKHealthStore,
        shareTypes: Set<HKSampleType>,
        readTypes: Set<HKObjectType>
    ) async throws {
        if let inFlightAuthorizationTask {
            try await inFlightAuthorizationTask.value
            return
        }

        let task = Task { @MainActor in
            try await healthStore.requestAuthorization(
                toShare: shareTypes,
                read: readTypes
            )
        }

        inFlightAuthorizationTask = task

        do {
            try await task.value
            inFlightAuthorizationTask = nil
        } catch {
            inFlightAuthorizationTask = nil
            throw error
        }
    }
}

protocol SQHealthKitManaging {
    func requestAppAuthorization() async throws

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

    /// Returns HealthKit-backed metric values keyed by `anchorDayKey` and metric id.
    func fetchMetricFallbackValues(
        for definitions: [SQMetricDefinition],
        from startDate: Date,
        to endDate: Date
    ) async throws -> [String: [String: SQMetricLoggedValue]]

    /// Upserts a LifeIQ-authored HealthKit sample for a metric on the provided day.
    func upsertMetricSample(
        for definition: SQMetricDefinition,
        metricId: String,
        loggedValue: SQMetricLoggedValue,
        date: Date
    ) async throws

    /// Deletes the LifeIQ-authored HealthKit sample for a metric on the provided day.
    func deleteMetricSample(
        for definition: SQMetricDefinition,
        metricId: String,
        date: Date
    ) async throws

    func dashboardAccessStatus() async -> SQHealthKitDashboardAccessStatus
    func dashboardAccessStatus(for domain: SQHealthKitDashboardDomain) async -> SQHealthKitDashboardAccessStatus
}


final class SQHealthKitManager: SQHealthKitManaging {
    static let shared = SQHealthKitManager()
    static let healthStore: HKHealthStore = HKHealthStore()
    private static let authorizationCoordinator = SQHealthKitAuthorizationCoordinator()

    /// Keep this list aligned with the HealthKit privacy strings in the project settings.
    private let allTypesToRead: Set<HKObjectType> = [
        HKObjectType.workoutType(),
        HKSeriesType.workoutRoute(),

        HKQuantityType(.activeEnergyBurned),
        HKQuantityType(.distanceCycling),
        HKQuantityType(.distanceWalkingRunning),
        HKQuantityType(.distanceWheelchair),
        HKQuantityType(.heartRate),
        HKQuantityType(.restingHeartRate),
        HKQuantityType(.vo2Max),
        HKQuantityType(.bodyMass),
        HKQuantityType(.dietaryCaffeine),
        HKQuantityType(.dietaryWater),
        HKQuantityType(.numberOfAlcoholicBeverages),

        HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!
    ]

    private let allTypesToWrite: Set<HKSampleType> = [
        HKObjectType.workoutType(),
        HKQuantityType(.bodyMass),
        HKQuantityType(.dietaryCaffeine),
        HKQuantityType(.dietaryWater),
        HKQuantityType(.numberOfAlcoholicBeverages)
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

    private var dashboardAuthorizationTypes: Set<HKObjectType> {
        [
            HKObjectType.workoutType(),
            HKQuantityType(.activeEnergyBurned),
            HKQuantityType(.distanceCycling),
            HKQuantityType(.distanceWalkingRunning),
            HKQuantityType(.heartRate),
            HKQuantityType(.vo2Max),
            HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!
        ]
    }

    private func authorizationTypes(for domain: SQHealthKitDashboardDomain) -> Set<HKObjectType> {
        switch domain {
        case .workouts:
            return [
                HKObjectType.workoutType()
            ]
        case .sleep:
            return [
                HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!
            ]
        case .heart:
            return [
                HKQuantityType(.heartRate),
                HKQuantityType(.restingHeartRate)
            ]
        case .vo2Max:
            return [
                HKQuantityType(.vo2Max)
            ]
        }
    }

    func requestAppAuthorization() async throws {
        try await Self.authorizationCoordinator.authorize(
            healthStore: Self.healthStore,
            shareTypes: allTypesToWrite,
            readTypes: allTypesToRead
        )
    }

    @MainActor @discardableResult
    func saveWorkout(
        workout: SQWorkoutSessionable
    ) async throws -> HKWorkout? {
        
        guard let startDate = workout.startDate else {
               // You need a start date for HealthKit
               return nil
           }

        let endDate = workout.endDate ?? .now
        
        try await requestAppAuthorization()

        // TODO: - Deprecated Finish configuration, add calories, heartRate, locationType, etc..
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
        
        // TODO: - Deprecated Hack to add inactive time for now, update later to properly use workout events
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

        try await requestAppAuthorization()

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

    func dashboardAccessStatus() async -> SQHealthKitDashboardAccessStatus {
        guard HKHealthStore.isHealthDataAvailable() else {
            return .unavailable
        }

        let authorizationStatuses = dashboardAuthorizationTypes.map { Self.healthStore.authorizationStatus(for: $0) }
        let isFullyAuthorized = authorizationStatuses.allSatisfy { $0 == .sharingAuthorized }
        if isFullyAuthorized {
            return .available
        }

        do {
            let requestStatus = try await Self.healthStore.statusForAuthorizationRequest(
                toShare: [],
                read: dashboardAuthorizationTypes
            )

            switch requestStatus {
            case .unnecessary:
                return isFullyAuthorized ? .available : .unavailable
            case .shouldRequest, .unknown:
                return .unavailable
            @unknown default:
                return .unavailable
            }
        } catch {
            SQLogger.shared.log(
                "Unable to determine HealthKit dashboard authorization status: \(error.localizedDescription)",
                .error,
                context: .healthKit
            )
            return .unavailable
        }
    }

    func dashboardAccessStatus(for domain: SQHealthKitDashboardDomain) async -> SQHealthKitDashboardAccessStatus {
        guard HKHealthStore.isHealthDataAvailable() else {
            return .unavailable
        }

        let domainTypes = authorizationTypes(for: domain)
        let authorizationStatuses = domainTypes.map { Self.healthStore.authorizationStatus(for: $0) }
        let isFullyAuthorized = authorizationStatuses.allSatisfy { $0 == .sharingAuthorized }
        if isFullyAuthorized {
            return .available
        }

        do {
            let requestStatus = try await Self.healthStore.statusForAuthorizationRequest(
                toShare: [],
                read: domainTypes
            )

            switch requestStatus {
            case .unnecessary:
                return isFullyAuthorized ? .available : .unavailable
            case .shouldRequest, .unknown:
                return .unavailable
            @unknown default:
                return .unavailable
            }
        } catch {
            SQLogger.shared.log(
                "Unable to determine HealthKit authorization status for domain \(String(describing: domain)): \(error.localizedDescription)",
                .error,
                context: .healthKit
            )
            return .unavailable
        }
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
        try await requestAppAuthorization()

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
        guard let quantity = workout.metadata?[HKMetadataKeyWeatherTemperature] as? HKQuantity else {
            return nil
        }
        
        return quantity.doubleValue(for: .degreeCelsius())
    }
}

extension SQHealthKitManager {
    func fetchMetricFallbackValues(
        for definitions: [SQMetricDefinition],
        from startDate: Date,
        to endDate: Date
    ) async throws -> [String: [String: SQMetricLoggedValue]] {
        let supportedDefinitions = definitions.filter { $0.isHealthKitReadEnabledEffective }
        guard !supportedDefinitions.isEmpty else { return [:] }
        guard HKHealthStore.isHealthDataAvailable() else { return [:] }

        try await requestAppAuthorization()

        let groupedDefinitions = Dictionary(grouping: supportedDefinitions, by: \.healthKitType)
        var fallbackValues = [String: [String: SQMetricLoggedValue]]()

        for (healthKitType, linkedDefinitions) in groupedDefinitions {
            guard
                let quantityType = quantityType(for: healthKitType),
                let unit = canonicalHKUnit(for: healthKitType)
            else {
                continue
            }

            let dayValues: [String: Double]
            switch healthKitType.aggregationStyle {
            case .cumulativeDailyTotal:
                dayValues = try await fetchDailyCumulativeTotals(
                    quantityType: quantityType,
                    unit: unit,
                    from: startDate,
                    to: endDate
                )
            case .latestSamplePerDay:
                dayValues = try await fetchDailyLatestValues(
                    quantityType: quantityType,
                    unit: unit,
                    from: startDate,
                    to: endDate
                )
            }

            for (anchorDayKey, totalValue) in dayValues where totalValue > 0 {
                for definition in linkedDefinitions {
                    guard let loggedValue = healthKitLoggedValue(for: definition, quantityValue: Float(totalValue)) else {
                        continue
                    }
                    fallbackValues[anchorDayKey, default: [:]][definition.id] = loggedValue
                }
            }
        }

        return fallbackValues
    }

    func upsertMetricSample(
        for definition: SQMetricDefinition,
        metricId: String,
        loggedValue: SQMetricLoggedValue,
        date: Date
    ) async throws {
        guard definition.isHealthKitWriteEnabledEffective else { return }
        guard HKHealthStore.isHealthDataAvailable() else { return }
        guard definition.isSingleDailyValue else { return }
        guard
            let quantityType = quantityType(for: definition.healthKitType),
            let unit = canonicalHKUnit(for: definition.healthKitType),
            let desiredQuantityValue = healthKitQuantityValue(for: definition, loggedValue: loggedValue)
        else {
            return
        }

        try await requestAppAuthorization()

        try await deleteMetricSample(for: definition, metricId: metricId, date: date)

        let syncIdentifier = metricSyncIdentifier(metricId: metricId, date: date)
        let quantityToSave: Double
        switch definition.healthKitType.aggregationStyle {
        case .cumulativeDailyTotal:
            let existingAuthoredTotal = try await authoredMetricTotal(
                quantityType: quantityType,
                unit: unit,
                syncIdentifier: syncIdentifier
            )
            let allDayTotal = try await totalQuantityValue(
                quantityType: quantityType,
                unit: unit,
                date: date
            )
            let externalTotal = max(0, allDayTotal - existingAuthoredTotal)
            quantityToSave = max(0, Double(desiredQuantityValue) - externalTotal)
        case .latestSamplePerDay:
            quantityToSave = Double(desiredQuantityValue)
        }

        guard quantityToSave > 0 else { return }

        let sampleDate = canonicalMetricSampleDate(for: date)
        let metadata: [String: Any] = [
            HKMetadataKeySyncIdentifier: syncIdentifier,
            HKMetadataKeySyncVersion: 1
        ]
        let quantity = HKQuantity(unit: unit, doubleValue: quantityToSave)
        let sample = HKQuantitySample(
            type: quantityType,
            quantity: quantity,
            start: sampleDate,
            end: sampleDate,
            metadata: metadata
        )

        try await save(sample)
    }

    func deleteMetricSample(
        for definition: SQMetricDefinition,
        metricId: String,
        date: Date
    ) async throws {
        guard definition.hasHealthKitLink else { return }
        guard HKHealthStore.isHealthDataAvailable() else { return }
        guard let quantityType = quantityType(for: definition.healthKitType) else { return }

        try await requestAppAuthorization()

        let syncIdentifier = metricSyncIdentifier(metricId: metricId, date: date)
        let samples = try await authoredMetricSamples(
            quantityType: quantityType,
            syncIdentifier: syncIdentifier
        )

        for sample in samples {
            try await delete(sample)
        }
    }

    private func healthKitLoggedValue(
        for definition: SQMetricDefinition,
        quantityValue: Float
    ) -> SQMetricLoggedValue? {
        guard let metricQuantityValue = metricQuantityValue(
            fromHealthKitQuantityValue: quantityValue,
            for: definition
        ) else {
            return nil
        }

        switch definition.defaultEntryMode {
        case .scale:
            guard let scaleValue = definition.scaleValue(forQuantityValue: metricQuantityValue) else {
                return nil
            }
            return .init(
                enteredMode: .scale,
                rawValue: scaleValue,
                scaleValue: scaleValue,
                quantityValue: metricQuantityValue
            )
        case .quantity:
            return .init(
                enteredMode: .quantity,
                rawValue: metricQuantityValue,
                scaleValue: definition.scaleValue(forQuantityValue: metricQuantityValue),
                quantityValue: metricQuantityValue
            )
        case .unknown:
            return .init(
                enteredMode: .quantity,
                rawValue: metricQuantityValue,
                scaleValue: definition.scaleValue(forQuantityValue: metricQuantityValue),
                quantityValue: metricQuantityValue
            )
        }
    }

    private func canonicalQuantityValue(
        for definition: SQMetricDefinition,
        loggedValue: SQMetricLoggedValue
    ) -> Float? {
        if let quantityValue = loggedValue.quantityValue {
            return quantityValue
        }

        switch loggedValue.enteredMode {
        case .scale:
            return definition.quantityValue(forScaleValue: loggedValue.rawValue)
        case .quantity, .unknown:
            return loggedValue.rawValue
        }
    }

    private func healthKitQuantityValue(
        for definition: SQMetricDefinition,
        loggedValue: SQMetricLoggedValue
    ) -> Float? {
        guard let metricQuantityValue = canonicalQuantityValue(for: definition, loggedValue: loggedValue) else {
            return nil
        }

        guard let healthKitMetricUnit = canonicalHealthKitMetricUnit(for: definition.healthKitType) else {
            return metricQuantityValue
        }

        return definition.quantityUnit.convert(metricQuantityValue, to: healthKitMetricUnit) ?? metricQuantityValue
    }

    private func metricQuantityValue(
        fromHealthKitQuantityValue value: Float,
        for definition: SQMetricDefinition
    ) -> Float? {
        guard let healthKitMetricUnit = canonicalHealthKitMetricUnit(for: definition.healthKitType) else {
            return value
        }

        return healthKitMetricUnit.convert(value, to: definition.quantityUnit) ?? value
    }

    private func quantityType(for type: SQMetricHealthKitType) -> HKQuantityType? {
        guard let identifier = quantityTypeIdentifier(for: type) else { return nil }
        return HKObjectType.quantityType(forIdentifier: identifier)
    }

    private func quantityTypeIdentifier(for type: SQMetricHealthKitType) -> HKQuantityTypeIdentifier? {
        switch type {
        case .bodyMass:
            return .bodyMass
        case .dietaryWater:
            return .dietaryWater
        case .dietaryCaffeine:
            return .dietaryCaffeine
        case .numberOfAlcoholicBeverages:
            return .numberOfAlcoholicBeverages
        case .none, .unknown:
            return nil
        }
    }

    private func canonicalHKUnit(for type: SQMetricHealthKitType) -> HKUnit? {
        switch type {
        case .bodyMass:
            return SQUnit.kilogram.hkUnit
        case .dietaryWater:
            return SQUnit.milliliter.hkUnit
        case .dietaryCaffeine:
            return SQUnit.milligram.hkUnit
        case .numberOfAlcoholicBeverages:
            return SQUnit.count.hkUnit
        case .none, .unknown:
            return nil
        }
    }

    private func canonicalHealthKitMetricUnit(for type: SQMetricHealthKitType) -> SQMetricUnit? {
        switch type {
        case .bodyMass:
            return .kilograms
        case .dietaryWater:
            return .milliliters
        case .dietaryCaffeine:
            return .milligrams
        case .numberOfAlcoholicBeverages:
            return .count
        case .none, .unknown:
            return nil
        }
    }

    private func fetchDailyCumulativeTotals(
        quantityType: HKQuantityType,
        unit: HKUnit,
        from startDate: Date,
        to endDate: Date
    ) async throws -> [String: Double] {
        let calendar = Calendar.current
        let queryStart = calendar.startOfDay(for: startDate)
        guard let queryEnd = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: endDate)) else {
            return [:]
        }

        let predicate = HKQuery.predicateForSamples(
            withStart: queryStart,
            end: queryEnd,
            options: [.strictStartDate]
        )
        let interval = DateComponents(day: 1)

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKStatisticsCollectionQuery(
                quantityType: quantityType,
                quantitySamplePredicate: predicate,
                options: [.cumulativeSum],
                anchorDate: queryStart,
                intervalComponents: interval
            )

            query.initialResultsHandler = { _, results, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                guard let results else {
                    continuation.resume(returning: [:])
                    return
                }

                var totals = [String: Double]()
                results.enumerateStatistics(from: queryStart, to: queryEnd) { stats, _ in
                    guard let sum = stats.sumQuantity()?.doubleValue(for: unit), sum > 0 else {
                        return
                    }

                    let dayKey = stats.startDate.anchorDayKey()
                    totals[dayKey] = sum
                }

                continuation.resume(returning: totals)
            }

            Self.healthStore.execute(query)
        }
    }

    private func fetchDailyLatestValues(
        quantityType: HKQuantityType,
        unit: HKUnit,
        from startDate: Date,
        to endDate: Date
    ) async throws -> [String: Double] {
        let calendar = Calendar.current
        let queryStart = calendar.startOfDay(for: startDate)
        guard let queryEnd = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: endDate)) else {
            return [:]
        }

        let predicate = HKQuery.predicateForSamples(
            withStart: queryStart,
            end: queryEnd,
            options: [.strictStartDate]
        )

        let sortDescriptors = [
            NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        ]

        let samples = try await quantitySamples(
            quantityType: quantityType,
            predicate: predicate,
            sortDescriptors: sortDescriptors
        )

        var latestValues = [String: Double]()
        for sample in samples {
            let dayKey = sample.endDate.anchorDayKey()
            guard latestValues[dayKey] == nil else { continue }
            latestValues[dayKey] = sample.quantity.doubleValue(for: unit)
        }

        return latestValues
    }

    private func totalQuantityValue(
        quantityType: HKQuantityType,
        unit: HKUnit,
        date: Date
    ) async throws -> Double {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        guard let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) else {
            return 0
        }

        let predicate = HKQuery.predicateForSamples(
            withStart: startOfDay,
            end: endOfDay,
            options: [.strictStartDate]
        )

        let samples = try await quantitySamples(
            quantityType: quantityType,
            predicate: predicate
        )

        return samples.reduce(0) { partialResult, sample in
            partialResult + sample.quantity.doubleValue(for: unit)
        }
    }

    private func authoredMetricTotal(
        quantityType: HKQuantityType,
        unit: HKUnit,
        syncIdentifier: String
    ) async throws -> Double {
        let samples = try await authoredMetricSamples(
            quantityType: quantityType,
            syncIdentifier: syncIdentifier
        )

        return samples.reduce(0) { partialResult, sample in
            partialResult + sample.quantity.doubleValue(for: unit)
        }
    }

    private func authoredMetricSamples(
        quantityType: HKQuantityType,
        syncIdentifier: String
    ) async throws -> [HKQuantitySample] {
        let predicate = HKQuery.predicateForObjects(
            withMetadataKey: HKMetadataKeySyncIdentifier,
            operatorType: .equalTo,
            value: syncIdentifier
        )

        return try await quantitySamples(quantityType: quantityType, predicate: predicate)
    }

    private func quantitySamples(
        quantityType: HKQuantityType,
        predicate: NSPredicate?,
        sortDescriptors: [NSSortDescriptor]? = nil
    ) async throws -> [HKQuantitySample] {
        try await withCheckedThrowingContinuation { continuation in
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

                continuation.resume(returning: samples as? [HKQuantitySample] ?? [])
            }

            Self.healthStore.execute(query)
        }
    }

    private func save(_ sample: HKQuantitySample) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            Self.healthStore.save(sample) { success, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if success {
                    continuation.resume(returning: ())
                } else {
                    continuation.resume(throwing: SQError.standard)
                }
            }
        }
    }

    private func delete(_ object: HKObject) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            Self.healthStore.delete(object) { success, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if success {
                    continuation.resume(returning: ())
                } else {
                    continuation.resume(throwing: SQError.standard)
                }
            }
        }
    }

    private func metricSyncIdentifier(metricId: String, date: Date) -> String {
        "lifeiq.metric.\(metricId).\(date.anchorDayKey())"
    }

    private func canonicalMetricSampleDate(for date: Date) -> Date {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        return calendar.date(byAdding: .hour, value: 12, to: startOfDay) ?? startOfDay
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

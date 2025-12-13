//
//  SQHealthKitManager.swift
//  BeastFitness
//
//  Created by Patrick Doyle on 10/14/24.
//

import Foundation
import HealthKit

final class SQHealthKitManager {
    static let shared = SQHealthKitManager()
    static let healthStore: HKHealthStore = HKHealthStore()
    
    let allQuantityTypes: Set = [
        HKQuantityType.workoutType(),
        HKQuantityType(.activeEnergyBurned),
        HKQuantityType(.distanceCycling),
        HKQuantityType(.distanceWalkingRunning),
        HKQuantityType(.distanceWheelchair),
        HKQuantityType(.heartRate),
        HKObjectType.categoryType(forIdentifier: HKCategoryTypeIdentifier.sleepAnalysis)!
    ]
    
    private let userDefaults = UserDefaults.standard
    private let anchorKeyPrefix = "Anchor_"
    
    func fetchWorkouts(_ timeRange: SQTimeRange, filterDuplicates: Bool = true) async throws -> [HKWorkout] {
        guard HKHealthStore.isHealthDataAvailable() else {
            throw SQStandardError.standard
        }

        try await Self.healthStore.requestAuthorization(
            toShare: allQuantityTypes,
            read: allQuantityTypes
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
            anchor: nil,   // 👈 force full fetch for the time range PTD TODO: Update to use anchor later
            limit: limit
        )

        if filterDuplicates {
            workouts = Self.filterDuplicateWorkouts(workouts)
            workouts = workouts.filter { $0.workoutActivityType != .other }
        }

        return workouts
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

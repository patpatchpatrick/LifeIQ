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
    
    func fetchWorkouts(_ timeRange: SQTimeRange, filterDuplicates: Bool = true) async throws -> [SQWorkoutable] {
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
        // let anchor = getAnchor(for: workoutType)   // not needed here

        var workouts = try await executeQuery(
            sampleType: workoutType,
            predicate: predicate,
            anchor: nil,   // 👈 force full fetch for the time range PTD TODO: Update to use anchor later
            limit: limit
        )

        if filterDuplicates {
            workouts = Self.filterDuplicateWorkouts(workouts)
            workouts = workouts.filter { $0.activityType != .other }
        }

        return workouts
    }

    
    func anchorKey(for type: HKSampleType) -> String {
        return anchorKeyPrefix + type.identifier
    }
    
    
    /// Returns the saved anchor used in a long-running anchored object query for a particular sample type.
    /// Returns nil if a query has never been run.
    func getAnchor(for type: HKSampleType) -> HKQueryAnchor? {
        if let anchorData = userDefaults.object(forKey: anchorKey(for: type)) as? Data {
            return try? NSKeyedUnarchiver.unarchivedObject(ofClass: HKQueryAnchor.self, from: anchorData)
        }
        
        return nil
    }
    
    /// Update the saved anchor used in a long-running anchored object query for a particular sample type.
    func setAnchor(_ queryAnchor: HKQueryAnchor?, for type: HKSampleType) {
        if let queryAnchor = queryAnchor,
            let data = try? NSKeyedArchiver.archivedData(withRootObject: queryAnchor, requiringSecureCoding: true) {
            userDefaults.set(data, forKey: anchorKey(for: type))
        }
    }
    
    func updateAnchor(_ newAnchor: HKQueryAnchor?, from query: HKAnchoredObjectQuery) {
        if let sampleType = query.objectType as? HKSampleType {
            setAnchor(newAnchor, for: sampleType)
        } else {
            if let identifier = query.objectType?.identifier {
                print("anchoredObjectQueryDidUpdate error: Did not save anchor for \(identifier) – Not an HKSampleType.")
            } else {
                print("anchoredObjectQueryDidUpdate error: query doesn't not have non-nil objectType.")
            }
        }
    }
    
    func executeQuery(
        sampleType: HKSampleType,
        predicate: NSPredicate?,
        anchor: HKQueryAnchor?,
        limit: Int
    ) async throws -> [SQWorkoutable] {
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
                        .error
                    )
                    continuation.resume(throwing: error)
                    return
                }

                SQLogger.shared.log(
                    "HKAnchoredObjectQuery initialResultsHandler has returned for \(sampleType.identifier)",
                    .debug
                )

                // Update anchor for sample type
                self.updateAnchor(newAnchor, from: query)

                let hkWorkouts = samplesOrNil?.compactMap { $0 as? HKWorkout } ?? []
                let sqWorkouts: [SQWorkout] = hkWorkouts.map {
                    .init(.hkWorkout(.init(hkWorkout: $0)))
                }

                continuation.resume(returning: sqWorkouts)
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
    /// Duplicates are defined as workouts with the same activityType whose
    /// time ranges either:
    ///  - start & end within a small tolerance, OR
    ///  - overlap by a large percentage of their duration.
    static func filterDuplicateWorkouts(_ workouts: [SQWorkoutable]) -> [SQWorkoutable] {
        // Sort by start date so comparisons are stable and somewhat chronological.
        let sorted = workouts.sorted { lhs, rhs in
            (lhs.startDate ?? .distantPast) < (rhs.startDate ?? .distantPast)
        }
        
        var unique: [SQWorkoutable] = []
        
        for workout in sorted {
            guard let start = workout.startDate,
                  let end = workout.endDate else {
                // If we don't have times, we can't dedupe reliably; just keep it.
                unique.append(workout)
                continue
            }
            
            // Find a duplicate instead of just "contains"
            let duplicateIndex = unique.firstIndex { existing in
                guard existing.activityType == workout.activityType,
                      let existingStart = existing.startDate,
                      let existingEnd = existing.endDate else {
                    return false
                }
                
                // 1) Check near-identical start/end times
                let startDiff = abs(existingStart.timeIntervalSince(start))
                let endDiff = abs(existingEnd.timeIntervalSince(end))
                let timeTolerance: TimeInterval = 10 // seconds
                
                if startDiff <= timeTolerance && endDiff <= timeTolerance {
                    return true
                }
                
                // 2) Check for high overlap ratio
                let overlap = min(existingEnd, end).timeIntervalSince(max(existingStart, start))
                if overlap <= 0 {
                    return false
                }
                
                let existingDuration = existingEnd.timeIntervalSince(existingStart)
                let workoutDuration = end.timeIntervalSince(start)
                let minDuration = min(existingDuration, workoutDuration)
                
                // How much of the shorter one is overlapped?
                let overlapRatio = overlap / minDuration
                let overlapThreshold: Double = 0.9 // 90%+ overlap -> likely duplicate
                
                return overlapRatio >= overlapThreshold
            }
            
            if let idx = duplicateIndex {
                let existing = unique[idx]
                
                // Prefer the workout with heart rate data
                let existingHR = existing.avgOutputFor(.heartRate)
                let newHR = workout.avgOutputFor(.heartRate)
                
                let existingHasHR = (existingHR ?? 0) > 0
                let newHasHR = (newHR ?? 0) > 0
                
                if newHasHR && !existingHasHR {
                    unique[idx] = workout
                }
                // else: keep existing, ignore new
            } else {
                unique.append(workout)
            }
        }
        
        return unique
    }

}


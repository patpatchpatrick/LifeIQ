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
    
    func fetchWorkouts(_ timeRange: SQTimeRange) async -> WorkoutQueryResult {
        do {
            guard HKHealthStore.isHealthDataAvailable() else {
                throw SQStandardError.standard
            }
            
            try await Self.healthStore.requestAuthorization(toShare: allQuantityTypes, read: allQuantityTypes)
            
            let predicate = HKQuery.predicateForSamples(withStart: timeRange.startDate, end: timeRange.endDate)
            let limit = HKObjectQueryNoLimit
            let workoutType: HKSampleType = .workoutType()
            let anchor = getAnchor(for: workoutType)
            
            return await self.executeQuery(sampleType: workoutType, predicate: predicate, anchor: nil, limit: limit)
        } catch {
            SQLogger.shared.log("Error requesting healthStore auth: \(error.localizedDescription)", .error)
            return .error(error)
        }
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
    
    enum WorkoutQueryResult {
        case success([SQWorkout])
        case error(Error)
        
        var workouts: [SQWorkout]? {
            switch self {
            case .success(let workouts):
                return workouts
            case .error:
                return nil
            }
        }
    }
    private var queryResultContinuation: CheckedContinuation<WorkoutQueryResult, Never>?
    private func completeQueryResultContinuation(_ result: WorkoutQueryResult) {
        /// Never execute a continuation twice.  It causes a crash
        queryResultContinuation?.resume(returning: result)
        queryResultContinuation = nil
    }
    func executeQuery(sampleType: HKSampleType, predicate: NSPredicate?, anchor: HKQueryAnchor?, limit: Int) async -> WorkoutQueryResult {
        let query = HKAnchoredObjectQuery(
            type: sampleType,
            predicate: predicate,
            anchor: anchor,
            limit: limit,
            resultsHandler: { (query, samplesOrNil, deletedObjectsOrNil, newAnchor, errorOrNil) in
                // Handle error
                if let error = errorOrNil {
                    SQLogger.shared.log("HKAnchoredObjectQuery initialResultsHandler with identifier \(sampleType.identifier) error: \(error.localizedDescription)", .error)
                    self.completeQueryResultContinuation(.error(error))
                    return
                }
                
                SQLogger.shared.log("HKAnchoredObjectQuery initialResultsHandler has returned for \(sampleType.identifier)", .debug)
                
                // Update anchor for sample type
                self.updateAnchor(newAnchor, from: query)
                
                let hkWorkouts = samplesOrNil?.compactMap { $0 as? HKWorkout } ?? []
                let sqWorkouts: [SQWorkout] = hkWorkouts.map { .init(.hkWorkout(.init(hkWorkout: $0))) }
                
                self.completeQueryResultContinuation(.success(sqWorkouts))
                return
            })
        
        Self.healthStore.execute(query)
        
        return await withCheckedContinuation { continuation in
            self.queryResultContinuation = continuation
        }
    }
    
    // MARK: - Sleep
    var sleepQueryResultContinuation: CheckedContinuation<SleepQueryResult, Never>?
    func completeSleepQueryResultContinuation(_ result: SleepQueryResult) {
        /// Never execute a continuation twice.  It causes a crash
        sleepQueryResultContinuation?.resume(returning: result)
        sleepQueryResultContinuation = nil
    }
}

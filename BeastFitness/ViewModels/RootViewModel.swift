//
//  RootViewModel.swift
//  BeastFitness
//
//  Created by Patrick Doyle on 9/30/24.
//

import Foundation
import HealthKit

@Observable
class RootViewModel {
    
    static let healthStore: HKHealthStore = HKHealthStore()
    let deepLinkManager = SQDeepLinkManager()
    
    // MARK: - Vars
    
    private let allQuantityTypes: Set = [
        HKQuantityType.workoutType(),
        HKQuantityType(.activeEnergyBurned),
        HKQuantityType(.distanceCycling),
        HKQuantityType(.distanceWalkingRunning),
        HKQuantityType(.distanceWheelchair),
        HKQuantityType(.heartRate)
    ]
    
    private let userDefaults = UserDefaults.standard
    private let anchorKeyPrefix = "Anchor_"
    
    private(set) var activitySection: RootActivitySectionViewModel = .init(
        isPlaceholder: true,
        title: "Activity Stats",
        workouts: [])
    
    init () {
        Task {
            await fetchWorkouts()
        }
    }
    
    // MARK: UI
    
    private func refreshUi(with workouts: [SQWorkout]?) {
        activitySection = .init(title: "Activity Stats", workouts: workouts)
    }
    
    // MARK: - HealthKit
    
    func fetchWorkouts() async {
        do {
            /// Check that Health data is available on the device.
            if HKHealthStore.isHealthDataAvailable() {
                
                try await Self.healthStore.requestAuthorization(toShare: allQuantityTypes, read: allQuantityTypes)
                
                let predicate = createLastWeekPredicate()
                let limit = HKObjectQueryNoLimit
                let workoutType: HKSampleType = .workoutType()
                let anchor = getAnchor(for: workoutType)
                // PTD Add anchor back eventually
                executeQuery(withSampleType: workoutType, predicate: predicate, anchor: nil, limit: limit)
                
            }
        } catch {
            SQLogger.shared.log("Error requesting healthStore auth: \(error.localizedDescription)", .error)
        }
    }
    
    private func getLastWeekStartDate(from date: Date = Date()) -> Date {
        return Calendar.current.date(byAdding: .year, value: -10, to: date)!
    }
    
    private func createLastWeekPredicate(from endDate: Date = Date()) -> NSPredicate {
        let startDate = getLastWeekStartDate(from: endDate)
        return HKQuery.predicateForSamples(withStart: startDate, end: endDate)
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
    
    func executeQuery(withSampleType sampleType: HKSampleType, predicate: NSPredicate, anchor: HKQueryAnchor?, limit: Int) {
        
        // Create HKAnchoredObjecyQuery
        let query = HKAnchoredObjectQuery(type: sampleType, predicate: predicate, anchor: anchor, limit: limit) {
            (query, samplesOrNil, deletedObjectsOrNil, newAnchor, errorOrNil) in
            
            // Handle error
            if let error = errorOrNil {
                print("HKAnchoredObjectQuery initialResultsHandler with identifier \(sampleType.identifier) error: \(error.localizedDescription)")
                
                return
            }
            
            print("HKAnchoredObjectQuery initialResultsHandler has returned for \(sampleType.identifier)!")
            
            // Update anchor for sample type
            self.updateAnchor(newAnchor, from: query)
            
            print("PTD Samples", samplesOrNil)
            for (idx, sample) in samplesOrNil!.enumerated() {
                if let workout = sample as? HKWorkout {
                    print("PTD Workout", workout.workoutActivityType.name, workout)
                    print("PTD Workout Id", workout.uuid)
                    if let workoutMetadata = workout.metadata {
                        if let workoutElevation = workoutMetadata["HKElevationAscended"] as? HKQuantity {
                            print("PTD Elevation = \(workoutElevation.doubleValue(for: HKUnit.meter()))m")
                        }
                    }
                    for (key, statistic) in workout.allStatistics {
                        print("PTD Stat Key", key)
                        print("PTD Stat Data\nQuantityType\(statistic.quantityType)\n\(statistic.duration())\nStartDate\(statistic.startDate)\nEndDate\(statistic.endDate)\nMaximum\(statistic.maximumQuantity())\nMinimum\(statistic.minimumQuantity())\nAverage\(statistic.averageQuantity())\nRecentQuantity\(statistic.mostRecentQuantity())\nSumQuantity\(statistic.sumQuantity())")
                        
                    }
                }
                print("PTD Sample \(idx)", sample)
            }
            
            self.refreshUi(with: samplesOrNil?.compactMap { $0 as? HKWorkout }.compactMap { .init($0) } )
            
        }
        
        Self.healthStore.execute(query)
    }
}

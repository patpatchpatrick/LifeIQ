//
//  SQHealthKitManager.swift
//  BeastFitness
//
//  Created by Patrick Doyle on 10/9/24.
//

import Foundation
import HealthKit

final class SQHealthKitManager {
    static let shared = SQHealthKitManager()
    static let healthStore: HKHealthStore = HKHealthStore()
    
    private let allQuantityTypes: Set = [
        HKQuantityType.workoutType(),
        HKQuantityType(.activeEnergyBurned),
        HKQuantityType(.distanceCycling),
        HKQuantityType(.distanceWalkingRunning),
        HKQuantityType(.distanceWheelchair),
        HKQuantityType(.heartRate)
    ]
    
    func saveWorkout(_ stravaWorkout: SQStravaActivity) async {
        do {
            guard let start_date = stravaWorkout.start_date,
                  let elapsed_time = stravaWorkout.elapsed_time,
                  let moving_time = stravaWorkout.moving_time,
                  let distanceMeters = stravaWorkout.distance
            else {
                return
            }
            
            let endDate = start_date.addingTimeInterval(elapsed_time)
            let distance = HKQuantity(unit: HKUnit.meter(), doubleValue: distanceMeters)
            
            /// Check that Health data is available on the device.
            if HKHealthStore.isHealthDataAvailable() {
                
                try await Self.healthStore.requestAuthorization(toShare: allQuantityTypes, read: allQuantityTypes)
                
                let workout = HKWorkout(
                    activityType: stravaWorkout.sport_type.activityType,
                    start: start_date,
                    end: endDate,
                    duration: moving_time,
                    totalEnergyBurned: nil,
                    totalDistance: distance,
                    metadata: nil
                )
                
                try await Self.healthStore.save(workout)
                
                var samplesDate = [HKSample]()
                
                if let avgHeartRate = stravaWorkout.average_heartrate,
                    let heartRateType =
                    HKObjectType.quantityType(forIdentifier:
                        HKQuantityTypeIdentifier.heartRate)  {
                    let heartRateForInterval = HKQuantity(unit: HKUnit(from: "count/min"),
                                                          doubleValue: avgHeartRate)
                    
                    let heartRateForIntervalSample =
                        HKQuantitySample(type: heartRateType,
                                         quantity: heartRateForInterval,
                                         start: start_date,
                                         end: endDate)
                }
                
                
                try await Self.healthStore.addSamples(samplesDate, to: workout)
                
            }
        } catch {
            SQLogger.shared.log("Error saving strave workout to healthKit: \(error.localizedDescription)", .error)
        }
    }
}

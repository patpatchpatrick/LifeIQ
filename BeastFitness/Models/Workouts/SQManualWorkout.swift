//
//  SQManualWorkout.swift
//  BeastFitness
//
//  Created by Patrick Doyle on 12/6/25.
//

import Foundation
import HealthKit

struct SQManualWorkout: SQWorkoutSourcable {
    // Core identity
    var id: UUID
    var activityType: HKWorkoutActivityType

    // Time (seconds)
    var elapsedTime: Double?      // total duration
    var movingTime: Double?       // active duration (if different)

    // Heart rate
    var averageHeartRate: Double? // bpm
    var maxHeartRate: Double?     // bpm

    // Start / end
    var startDate: Date?
    
    // Distance / energy
    var distance: Double?         // meters
    var totalCalories: Double?    // kilocalories

    // MARK: - SQWorkoutSourcable
    
    var coreOutputQuantityTypeId: SQQuantityType? {
        activityType.coreOutputQuantityTypeId
    }
    
    var coreOutputUnit: SQUnit? {
        activityType.coreOutputUnit
    }
    
    /// Active duration in seconds
    var activeDuration: Double? {
        movingTime ?? elapsedTime
    }
    
    var endDate: Date? {
        guard let startDate, let elapsedTime else { return nil }
        return startDate.addingTimeInterval(elapsedTime)
    }
    
    func sumOutputFor(_ quantityTypeIdentifier: SQQuantityType) -> Double? {
        guard let unit = quantityTypeIdentifier.unit else {
            SQLogger.shared.log(
                "Missing unit for manual workout sum output",
                .error,
                context: .dataProcessing
            )
            return nil
        }
        
        switch quantityTypeIdentifier {
        case .distanceWalkingRunning,
             .distanceCycling,
             .distanceSwimming,
             .distanceRowing,
             .distanceDownhillSnowSports,
             .distanceCrossCountrySkiing:
            return SQUnit.convert(distance, from: .meter, to: unit)
            
        case .activeKilocaloriesBurned:
            return SQUnit.convert(totalCalories, from: .kilocalorie, to: unit)
            
        case .heartRate,
             .flightsClimbed:
            return nil
        }
    }
    
    func avgOutputFor(_ quantityTypeIdentifier: SQQuantityType) -> Double? {
        guard let unit = quantityTypeIdentifier.unit else {
            SQLogger.shared.log(
                "Missing unit for manual workout avg output",
                .error,
                context: .dataProcessing
            )
            return nil
        }
        
        switch quantityTypeIdentifier {
        case .heartRate:
            return SQUnit.convert(averageHeartRate, from: .countPerMinute, to: unit)
            
        case .distanceCycling,
             .distanceWalkingRunning,
             .activeKilocaloriesBurned,
             .distanceSwimming,
             .distanceRowing,
             .distanceDownhillSnowSports,
             .distanceCrossCountrySkiing,
             .flightsClimbed:
            return nil
        }
    }
    
    // If you have a default implementation of `coreOutput` / `outputString`
    // in a `SQWorkoutSourcable` extension, you don't need to implement them here.
    // Otherwise you can mirror what you did for SQWorkoutSessionable.
}

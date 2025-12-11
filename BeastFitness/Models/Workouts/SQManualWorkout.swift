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
    let id: UUID
    let activityType: HKWorkoutActivityType
    let device: SQWorkoutDevice?
    let startDate: Date?
    let endDate: Date?
    let activeDuration: Double?
    let averageHeartRate: Double?
    let totalCalories: Double?
    
    let details: SQWorkoutDetails?

    // MARK: - SQWorkoutSourcable
    
    func sumOutputFor(_ quantityTypeIdentifier: SQQuantityType) -> Double? {
        // TODO: - Implement this for all Quantity Types that are supported with manual workouts
        switch quantityTypeIdentifier {
        case .activeKilocaloriesBurned:
            return totalCalories
        default:
            return nil
        }
    }
    
    func avgOutputFor(_ quantityTypeIdentifier: SQQuantityType) -> Double? {
        // TODO: - Implement this for all Quantity Types that are supported with manual workouts
        switch quantityTypeIdentifier {
        case .heartRate:
            return averageHeartRate
        default:
            return nil
        }
    }
    
    // If you have a default implementation of `coreOutput` / `outputString`
    // in a `SQWorkoutSourcable` extension, you don't need to implement them here.
    // Otherwise you can mirror what you did for SQWorkoutSessionable.
}

extension SQManualWorkout {
    static var mock: SQManualWorkout {
        let now = Date()
        
        // Create a 1-hour mock workout
        let activeDuration: Double = 3600
        
        return SQManualWorkout(
            id: UUID(),
            activityType: .running,
            device: SQWorkoutDevice(name: "iPhone Mock"),
            startDate: now.addingTimeInterval(-activeDuration),
            endDate: now,
            activeDuration: activeDuration,
            averageHeartRate: 145,
            totalCalories: 620,
            details: nil
        )
    }
}

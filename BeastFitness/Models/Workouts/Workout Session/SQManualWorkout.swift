//
//  SQManualWorkout.swift
//  BeastFitness
//
//  Created by Patrick Doyle on 12/6/25.
//

import Foundation
import HealthKit

struct SQManualWorkout: SQWorkoutSourcable {
    let sourceId: String
    let activityType: HKWorkoutActivityType
    let device: SQWorkoutDevice?
    let startDate: Date?
    let endDate: Date?
    let activeDuration: Double?
    let averageHeartRate: Double?
    let totalCalories: Double?
    
    let details: SQWorkoutActivityDetails?

    // MARK: - SQWorkoutSourcable
    
    func sumOutputFor(_ quantityTypeIdentifier: SQQuantityType) -> Double? {
        // TODO: - Implement this for all Quantity Types that are supported with manual workouts
        switch quantityTypeIdentifier {
        case .distanceWalkingRunning, .distanceCycling, .distanceSwimming, .distanceRowing, .distanceDownhillSnowSports, .distanceCrossCountrySkiing, .flightsClimbed, .heartRate:
            return nil
            
        case .activeKilocaloriesBurned:
            return totalCalories
            
        case .sqPaceRunning, .unknown:
            return nil
            
        case .sqTotalVolumeLifted:
            guard let details else { return nil }
            switch details {
            case .strength(let details):
                return details.totalVolume
            }
            
        }
    }
    
    func avgOutputFor(_ quantityTypeIdentifier: SQQuantityType) -> Double? {
        // TODO: - Implement this for all Quantity Types that are supported with manual workouts
        switch quantityTypeIdentifier {
        case .distanceWalkingRunning, .distanceCycling, .distanceSwimming, .distanceRowing, .distanceDownhillSnowSports, .distanceCrossCountrySkiing, .flightsClimbed, .activeKilocaloriesBurned, .sqTotalVolumeLifted, .sqPaceRunning, .unknown:
            return nil
        case .heartRate:
            return averageHeartRate
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
            sourceId: UUID().uuidString,
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

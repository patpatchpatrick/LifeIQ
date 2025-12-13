//
//  SQHKWorkout.swift
//  BeastFitness
//
//  Created by Patrick Doyle on 10/14/24.
//

import Foundation
import HealthKit

struct SQHKWorkout: SQWorkoutSourcable {
    let hkWorkout: HKWorkout
    
    init(hkWorkout: HKWorkout) {
        self.hkWorkout = hkWorkout
    }
    
    var activityType: HKWorkoutActivityType {
        hkWorkout.workoutActivityType
    }
    
    func sumOutputFor(_ quantityTypeIdentifier: SQQuantityType) -> Double? {
        
        switch quantityTypeIdentifier {
        case .sqPaceRunning, .sqTotalVolumeLifted, .unknown:
            return nil
            
        case .distanceWalkingRunning, .distanceCycling, .distanceSwimming, .distanceRowing, .distanceDownhillSnowSports, .distanceCrossCountrySkiing, .flightsClimbed, .activeKilocaloriesBurned, .heartRate:
            /// Continue below since these are all supported in HealhKit
            break
        }
        
        return hkWorkout.sumOutputFor(quantityTypeIdentifier)
    }
    
    func avgOutputFor(_ quantityTypeIdentifier: SQQuantityType) -> Double? {
        
        switch quantityTypeIdentifier {
            
        case .unknown:
            return nil
            
        case .sqPaceRunning, .sqTotalVolumeLifted:
            
            guard  let totalDistance = sumOutputFor(.distanceWalkingRunning), let activeDuration else { return nil }
            return activeDuration / totalDistance
            
        case .distanceWalkingRunning, .distanceCycling, .distanceSwimming, .distanceRowing, .distanceDownhillSnowSports, .distanceCrossCountrySkiing, .flightsClimbed, .activeKilocaloriesBurned, .heartRate:
            /// Continue below since these are all supported in HealhKit
            break
        }
        
        return hkWorkout.avgOutputFor(quantityTypeIdentifier)
    }
    
    var activeDuration: Double? {
        workoutActiveDuration(from: hkWorkout)
    }
    
    var startDate: Date? {
        hkWorkout.startDate
    }
    
    var endDate: Date? {
        hkWorkout.endDate
    }
    
    var device: SQWorkoutDevice? {
        guard let device = hkWorkout.device else { return nil }
        return .init(name: device.friendlyDescription)
    }

    // TODO: - Pass workout details for existing HK workouts if they exist
    var details: SQWorkoutDetails? {
        nil
    }
    
    func workoutActiveDuration(from workout: HKWorkout) -> TimeInterval? {
        // If there are no events, fall back to total duration
        guard let events = workout.workoutEvents, !events.isEmpty else {
            return workout.duration
        }

        var activeTime: TimeInterval = 0
        var lastStart = workout.startDate

        for event in events {
            switch event.type {
            case .pause:
                // Add time from lastStart to this pause
                activeTime += event.dateInterval.start.timeIntervalSince(lastStart)
            case .resume:
                // Resume timer from this point
                lastStart = event.dateInterval.start
            default:
                break
            }
        }

        // Add any remaining time from lastStart to endDate
        activeTime += workout.endDate.timeIntervalSince(lastStart)

        if activeTime > 0 { return activeTime}
        
        return workout.duration
    }
}

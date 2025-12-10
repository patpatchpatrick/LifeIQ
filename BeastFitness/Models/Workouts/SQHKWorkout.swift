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
    
    var coreOutputQuantityTypeId: SQQuantityType? {
        activityType.coreOutputQuantityTypeId
    }
    
    var coreOutputUnit: SQUnit? {
        activityType.coreOutputUnit
    }
    
    func sumOutputFor(_ quantityTypeIdentifier: SQQuantityType) -> Double? {
        hkWorkout.sumOutputFor(quantityTypeIdentifier)
    }
    
    func avgOutputFor(_ quantityTypeIdentifier: SQQuantityType) -> Double? {
        hkWorkout.avgOutputFor(quantityTypeIdentifier)
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

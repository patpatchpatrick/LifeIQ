//
//  SQHKWorkout.swift
//  BeastFitness
//
//  Created by Patrick Doyle on 10/14/24.
//

import Foundation
import HealthKit

struct SQHKWorkout: SQWorkoutable {
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
        hkWorkout.duration
    }
    
    var startDate: Date? {
        hkWorkout.startDate
    }
    
    var endDate: Date? {
        hkWorkout.endDate
    }
}

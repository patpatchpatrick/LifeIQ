//
//  SQDisplayableWorkout.swift
//  BeastFitness
//
//  Created by Patrick Doyle on 10/7/24.
//

import Foundation
import HealthKit

final class SQWorkout: SQWorkoutable {
    let workoutType: SQWorkoutType
    
    // MARK: - Init
    
    init(_ workoutType: SQWorkoutType) {
        self.workoutType = workoutType
    }
    
    var activityType: HKWorkoutActivityType {
        workoutType.workoutable.activityType
    }
    
    var coreOutputQuantityTypeId: SQQuantityType? {
        workoutType.workoutable.activityType.coreOutputQuantityTypeId
    }
    
    var coreOutputUnit: SQUnit? {
        workoutType.workoutable.activityType.coreOutputUnit
    }
    
    func sumOutputFor(_ quantityTypeIdentifier: SQQuantityType) -> Double? {
        workoutType.workoutable.sumOutputFor(quantityTypeIdentifier)
    }
    
    func avgOutputFor(_ quantityTypeIdentifier: SQQuantityType) -> Double? {
        workoutType.workoutable.avgOutputFor(quantityTypeIdentifier)
    }
    
    var activeDuration: Double? {
        workoutType.workoutable.activeDuration
    }
    
    var startDate: Date? {
        workoutType.workoutable.startDate
    }
    
    var endDate: Date? {
        workoutType.workoutable.endDate
    }
}

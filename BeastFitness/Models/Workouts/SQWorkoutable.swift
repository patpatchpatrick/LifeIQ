//
//  SQWorkoutable.swift
//  BeastFitness
//
//  Created by Patrick Doyle on 11/13/25.
//

import Foundation
import HealthKit


protocol SQWorkoutable {
    var activityType: HKWorkoutActivityType { get }
    var coreOutputQuantityTypeId: SQQuantityType? { get }
    var coreOutputUnit: SQUnit? { get }
    func sumOutputFor(_ quantityTypeIdentifier: SQQuantityType) -> Double?
    func avgOutputFor(_ quantityTypeIdentifier: SQQuantityType) -> Double?
    var activeDuration: Double? { get } /// Seconds
    var startDate: Date? { get }
    var endDate: Date? { get }
    var coreOutput: Double? { get }
    var outputString: String? { get }
}

extension SQWorkoutable {
    
    var coreOutput: Double? {
        guard let coreOutputQuantityTypeId
        else { return nil }
        
        let sumOutput = sumOutputFor(coreOutputQuantityTypeId) ?? 0
        return sumOutput
    }
    
    var outputString: String? {
        guard let coreOutput,
                let coreOutputUnit = activityType.coreOutputUnit
        else { return nil }
        
        return "\(coreOutput.sqShortString) \(coreOutputUnit.unitString ?? "")"
    }
    
}

enum SQWorkoutType {
    case hkWorkout(SQHKWorkout)
    case stravaWorkout(SQStravaWorkout)
    
    var workoutable: SQWorkoutable {
        switch self {
        case .hkWorkout(let workout):
            return workout
        case .stravaWorkout(let workout):
            return workout
        }
    }
}


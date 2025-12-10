//
//  SQWorkoutSource.swift
//  BeastFitness
//
//  Created by Patrick Doyle on 11/13/25.
//

import Foundation
import HealthKit

protocol SQWorkoutSourcable {
    var activityType: HKWorkoutActivityType { get }
    var coreOutputQuantityTypeId: SQQuantityType? { get }
    var coreOutputUnit: SQUnit? { get }
    func sumOutputFor(_ quantityTypeIdentifier: SQQuantityType) -> Double?
    func avgOutputFor(_ quantityTypeIdentifier: SQQuantityType) -> Double?
    var activeDuration: Double? { get } /// Seconds
    var totalCalories: Double? { get }
    var startDate: Date? { get }
    var endDate: Date? { get }
    var coreOutput: Double? { get }
    var outputString: String? { get }
    var device: SQWorkoutDevice? { get }
}

extension SQWorkoutSourcable {
    
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
    
    var totalCalories: Double? {
        sumOutputFor(.activeKilocaloriesBurned)
    }
    
    // Default mapper: sourcable → session (source-agnostic)
    func buildWorkout(id: UUID = UUID(), source: SQWorkoutSource) -> SQWorkoutSessionable {
        SQWorkoutSession(
            id: id,
            workoutSource: source,
            device: device,
            activityType: activityType,
            coreOutputQuantityTypeId: coreOutputQuantityTypeId,
            coreOutputUnit: coreOutputUnit,
            activeDuration: activeDuration,
            startDate: startDate,
            endDate: endDate,
            totalCalories: totalCalories
        )
    }
}

enum SQWorkoutSource {
    case hkWorkout(SQHKWorkout)
    case stravaWorkout(SQStravaWorkout)
    case manual(SQManualWorkout)
    
    var sourcableData: SQWorkoutSourcable {
        switch self {
        case .hkWorkout(let workout):
            return workout
        case .stravaWorkout(let workout):
            return workout
        case .manual(let workout):
            return workout
        }
    }
    
    func buildWorkout(id: UUID = UUID()) -> SQWorkoutSessionable {
        sourcableData.buildWorkout(id: id, source: self)
    }
}


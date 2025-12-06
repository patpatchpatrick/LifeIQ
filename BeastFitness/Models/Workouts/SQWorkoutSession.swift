//
//  SQDisplayableWorkout.swift
//  BeastFitness
//
//  Created by Patrick Doyle on 10/7/24.
//

import Foundation
import HealthKit

protocol SQWorkoutSessionable {
    // Core identifying info
    var activityType: HKWorkoutActivityType { get set }
    var coreOutputQuantityTypeId: SQQuantityType? { get set }
    var coreOutputUnit: SQUnit? { get set }
    
    // Time
    var activeDuration: Double? { get set }
    var startDate: Date? { get set }
    var endDate: Date? { get set }
    
    // Summary values
    var totalCalories: Double? { get set }
    
    // Workout specific Details
    var details: SQWorkoutDetails? { get set }
    
    // Required function hooks
    func sumOutputFor(_ quantityTypeIdentifier: SQQuantityType) -> Double?
    func avgOutputFor(_ quantityTypeIdentifier: SQQuantityType) -> Double?
    
    // Derived properties (still fine as computed)
    var coreOutput: Double? { get }
    var outputString: String? { get }
}

// TODO: - Rename to SQWorkoutSession
struct SQWorkoutSession: SQWorkoutSessionable {
    let id: UUID
    let workoutSource: SQWorkoutSource
    
    // Stored properties required by SQWorkoutable
    var activityType: HKWorkoutActivityType
    var coreOutputQuantityTypeId: SQQuantityType?
    var coreOutputUnit: SQUnit?
    
    var activeDuration: Double?
    var startDate: Date?
    var endDate: Date?
    var totalCalories: Double?
    var details: SQWorkoutDetails?
    
    func sumOutputFor(_ quantityTypeIdentifier: SQQuantityType) -> Double? {
        workoutSource.sourcableData.sumOutputFor(quantityTypeIdentifier)
    }
    
    func avgOutputFor(_ quantityTypeIdentifier: SQQuantityType) -> Double? {
        workoutSource.sourcableData.avgOutputFor(quantityTypeIdentifier)
    }
    
    var coreOutput: Double? {
        guard let coreOutputQuantityTypeId else { return nil }
        return sumOutputFor(coreOutputQuantityTypeId)
    }
    
    var outputString: String? {
        guard let coreOutput,
              let coreOutputUnit else { return nil }
        
        return "\(coreOutput.sqShortString) \(coreOutputUnit.unitString ?? "")"
    }
}

enum SQWorkoutDetails {
    case strength(SQStrengthDetails)
    /// Add more activtiies
    // case other(... ) if you want
}

struct SQStrengthDetails: Hashable {
    var muscleGroups: [SQMuscleGroup]
    var exercises: [SQStrengthExercise]

    var totalVolume: Double {
        exercises.reduce(0) { $0 + $1.totalVolume }
    }
}

enum SQMuscleGroup: String, CaseIterable, Hashable {
    case chest, back, shoulders, legs, arms, core, fullBody, other
}

struct SQStrengthExercise: Identifiable, Hashable {
    let id: UUID
    var name: String
    var muscleGroup: SQMuscleGroup
    var sets: [SQStrengthSet]

    var totalVolume: Double {
        sets.reduce(0) { $0 + ($1.weight * Double($1.reps)) }
    }
}

struct SQStrengthSet: Identifiable, Hashable {
    let id: UUID
    var setIndex: Int       // 1, 2, 3...
    var reps: Int
    var weight: Double      // you can pair this with a unit if needed
    var rpe: Double?        // optional: perceived exertion
    var isWarmup: Bool
}

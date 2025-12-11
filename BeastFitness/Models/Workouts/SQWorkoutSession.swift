//
//  SQDisplayableWorkout.swift
//  BeastFitness
//
//  Created by Patrick Doyle on 10/7/24.
//

import Foundation
import HealthKit

protocol SQWorkoutSessionable {
    var id: UUID { get }
    // Core identifying info
    var activityType: HKWorkoutActivityType { get set }
    var coreOutputQuantityTypeId: SQQuantityType? { get set }
    var coreOutputUnit: SQUnit? { get set }
    var device: SQWorkoutDevice? { get }
    
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
    var outputAndUnitString: String? { get }
}

// TODO: - Rename to SQWorkoutSession
struct SQWorkoutSession: SQWorkoutSessionable {
    let id: UUID
    let workoutSource: SQWorkoutSource
    let device: SQWorkoutDevice?
    
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
    
    var outputAndUnitString: String? {
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

// MARK: - Raw Exercise Metadata

struct SQRawStrengthExercise: Identifiable, Codable, Hashable {
    let id: String
    let name: String

    let category: SQExerciseCategory
    let equipment: SQExerciseEquipment?
    let force: SQExerciseForce?
    let level: SQExerciseLevel
    let mechanic: SQExerciseMechanic?

    let primaryMuscles: [SQMuscleGroup]
    let secondaryMuscles: [SQMuscleGroup]
    let instructions: [String]
}

enum SQExerciseCategory: String, Codable, CaseIterable, UnfrozenEnum {
    case strength = "strength"
    case cardio = "cardio"
    case plyometrics = "plyometrics"
    case powerlifting = "powerlifting"
    case stretching = "stretching"
    case strongman = "strongman"
    case olympicWeightlifting = "olympic weightlifting"
    case unknown = "unknown"
}

enum SQExerciseEquipment: String, Codable, CaseIterable, UnfrozenEnum {
    case bands = "bands"
    case barbell = "barbell"
    case bodyOnly = "body only"
    case cable = "cable"
    case dumbbell = "dumbbell"
    case ezCurlBar = "e-z curl bar"
    case exerciseBall = "exercise ball"
    case foamRoll = "foam roll"
    case kettlebells = "kettlebells"
    case machine = "machine"
    case medicineBall = "medicine ball"
    case other = "other"
    case unknown = "unknown"
}

enum SQExerciseForce: String, Codable, CaseIterable, UnfrozenEnum {
    case push = "push"
    case pull = "pull"
    case `static` = "static"
    case unknown = "unknown"
}

enum SQExerciseLevel: String, Codable, CaseIterable, UnfrozenEnum {
    case beginner = "beginner"
    case intermediate = "intermediate"
    case expert = "expert"
    case unknown = "unknown"
}

enum SQExerciseMechanic: String, Codable, CaseIterable, UnfrozenEnum {
    case compound = "compound"
    case isolation = "isolation"
    case unknown = "unknown"
}

enum SQMuscleGroup: String, Codable, CaseIterable, UnfrozenEnum {
    case abdominals = "abdominals"
    case abductors = "abductors"
    case adductors = "adductors"
    case biceps = "biceps"
    case calves = "calves"
    case chest = "chest"
    case forearms = "forearms"
    case glutes = "glutes"
    case hamstrings = "hamstrings"
    case lats = "lats"
    case lowerBack = "lower back"
    case middleBack = "middle back"
    case neck = "neck"
    case quadriceps = "quadriceps"
    case shoulders = "shoulders"
    case traps = "traps"
    case triceps = "triceps"
    case unknown = "unknown"
}

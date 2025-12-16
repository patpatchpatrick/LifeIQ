//
//  SQWorkoutStrengthDetails.swift
//  BeastFitness
//
//  Created by Patrick Doyle on 12/15/25.
//

import Foundation

struct SQStrengthDetails: Codable, Hashable {
    var muscleGroups: [SQMuscleGroup]
    var exercises: [SQStrengthExercise]

    var totalVolume: Double {
        exercises.reduce(0) { $0 + $1.totalVolume }
    }
}

struct SQStrengthExercise: Codable, Identifiable, Hashable {
    let id: UUID
    var name: String
    var muscleGroup: SQMuscleGroup
    var sets: [SQStrengthSet]

    var totalVolume: Double {
        sets.reduce(0) { $0 + ($1.weight * Double($1.reps)) }
    }
}

struct SQStrengthSet: Codable, Identifiable, Hashable {
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

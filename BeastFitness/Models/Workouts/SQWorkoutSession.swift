//
//  SQDisplayableWorkout.swift
//  BeastFitness
//
//  Created by Patrick Doyle on 10/7/24.
//

import Foundation
import HealthKit

struct SQWorkoutMetric {
    let quantityType: SQQuantityType
    let displayName: String
    let unit: SQUnit
    let value: Double
    
    var outputAndUnitString: String {
        "\(value.sqShortString) \(unit.unitString ?? "")"
    }
}

protocol SQWorkoutSessionable {
    var id: UUID { get }
    // Core identifying info
    var activityType: HKWorkoutActivityType { get }
    var coreMetric: SQWorkoutMetric? { get }
    var device: SQWorkoutDevice? { get }
    
    // Time
    var activeDuration: Double? { get }
    var startDate: Date? { get }
    var endDate: Date? { get  }
    
    // Summary values
    var totalCalories: Double? { get  }
    var averageHeartRate: Double? { get }
    
    // Workout specific Details
    var details: SQWorkoutDetails? { get set }
    
    func getMetric(for quantityType: SQQuantityType) -> SQWorkoutMetric?
}

// TODO: - Rename to SQWorkoutSession
struct SQWorkoutSession: SQWorkoutSessionable {
    let id: UUID
    let coreMetric: SQWorkoutMetric?
    let workoutSource: SQWorkoutSource
    let device: SQWorkoutDevice?
    
    // Stored properties required by SQWorkoutable
    let activityType: HKWorkoutActivityType
    
    let activeDuration: Double?
    let startDate: Date?
    let endDate: Date?
    let totalCalories: Double?
    let averageHeartRate: Double?
    var details: SQWorkoutDetails?
    
    init(id: UUID, workoutSource: SQWorkoutSource, device: SQWorkoutDevice?, activityType: HKWorkoutActivityType, activeDuration: Double?, startDate: Date?, endDate: Date?, totalCalories: Double?, averageHeartRate: Double?) {
        self.id = id
        self.workoutSource = workoutSource
        self.device = device
        self.activityType = activityType
        self.activeDuration = activeDuration
        self.startDate = startDate
        self.endDate = endDate
        self.totalCalories = totalCalories
        self.averageHeartRate = averageHeartRate
        self.details = workoutSource.sourcableData.details
        
        if let coreOutputQuantityTypeId = activityType.coreOutputQuantityTypeId {
            self.coreMetric = Self.getMetric(for: coreOutputQuantityTypeId, workoutSource: workoutSource)
        } else {
            self.coreMetric = nil
        }
    }
    
    func getMetric(for quantityType: SQQuantityType) -> SQWorkoutMetric? {
        Self.getMetric(for: quantityType, workoutSource: workoutSource)
    }
}

// MARK: - SQWorkoutSession Build Metrics

extension SQWorkoutSession {
    
    static func getMetric(for quantityType: SQQuantityType, workoutSource: SQWorkoutSource) -> SQWorkoutMetric? {
        guard let unit = quantityType.unit
        else {
            return nil
        }
        
        switch quantityType.outputCalculationType {
        case .sum:
            
            guard let output = workoutSource.sourcableData.sumOutputFor(quantityType) else { return nil }
            
            return .init(
                quantityType: quantityType,
                displayName: quantityType.displayTitle,
                unit: unit,
                value: output)
            
        case .average:
            
            guard let output = workoutSource.sourcableData.avgOutputFor(quantityType) else { return nil }
            
            return .init(
                quantityType: quantityType,
                displayName: quantityType.displayTitle,
                unit: unit,
                value: output)
        }
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

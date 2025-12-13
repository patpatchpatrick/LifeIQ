//
//  SQDisplayableWorkout.swift
//  BeastFitness
//
//  Created by Patrick Doyle on 10/7/24.
//

import Foundation
import HealthKit

struct SQWorkoutMetric: Codable {
    let quantityType: SQQuantityType
    let displayName: String
    let unit: SQUnit
    let value: Double
    
    var outputAndUnitString: String {
        "\(displayableValue(for: quantityType, value: value)) \(unit.unitString ?? "")"
    }
    
    func displayableValue(for quantityType: SQQuantityType, value: Double) -> String {
        switch quantityType {
            
        case .distanceWalkingRunning, .distanceCycling, .distanceSwimming, .distanceRowing, .distanceDownhillSnowSports, .distanceCrossCountrySkiing, .flightsClimbed, .activeKilocaloriesBurned, .heartRate, .sqTotalVolumeLifted, .unknown:
            return value.sqShortString
            
        case .sqPaceRunning:
            return value.timeCode() /// eg 7:43
        }
    }
}

protocol SQWorkoutSessionable {
    var id: UUID { get }
    
    // Identifying / display
    var activityType: HKWorkoutActivityType { get }
    var coreMetric: SQWorkoutMetric? { get }
    var device: SQWorkoutDevice? { get }
    var title: String { get }
    
    // Time
    var activeDuration: Double? { get }
    var startDate: Date? { get }
    var endDate: Date? { get }
    
    // Summary
    var totalCalories: Double? { get }
    var averageHeartRate: Double? { get }
    
    // Details
    var details: SQWorkoutDetails? { get set }
    func getMetric(for quantityType: SQQuantityType) -> SQWorkoutMetric?
    
    // 🔥 Firestore sync fields
    var createdAt: Date? { get set }
    var updatedAt: Date? { get set }
    var deletedAt: Date? { get set }     // soft delete
    var syncStatus: SQSyncStatus { get set }
    
    /// Optional Firestore document id if you ever diverge from UUID string.
    var remoteId: String? { get set }
}


// TODO: - Rename to SQWorkoutSession
struct SQWorkoutSession: SQWorkoutSessionable {
    let id: UUID
    let title: String
    let coreMetric: SQWorkoutMetric?
    let workoutSource: SQWorkoutSource
    let device: SQWorkoutDevice?
    
    let activityType: HKWorkoutActivityType
    
    let activeDuration: Double?
    let startDate: Date?
    let endDate: Date?
    let totalCalories: Double?
    let averageHeartRate: Double?
    var details: SQWorkoutDetails?
    
    // 🔥 Sync fields
    var createdAt: Date?
    var updatedAt: Date?
    var deletedAt: Date?
    var syncStatus: SQSyncStatus
    var remoteId: String?
    
    init(
        id: UUID,
        title: String? = nil,
        workoutSource: SQWorkoutSource,
        device: SQWorkoutDevice?,
        activityType: HKWorkoutActivityType,
        activeDuration: Double?,
        startDate: Date?,
        endDate: Date?,
        totalCalories: Double?,
        averageHeartRate: Double?,
        createdAt: Date? = nil,
        updatedAt: Date? = nil,
        deletedAt: Date? = nil,
        syncStatus: SQSyncStatus = .pendingUpload,
        remoteId: String? = nil
    ) {
        self.id = id
        self.title = title ?? activityType.name
        self.workoutSource = workoutSource
        self.device = device
        self.activityType = activityType
        self.activeDuration = activeDuration
        self.startDate = startDate
        self.endDate = endDate
        self.totalCalories = totalCalories
        self.averageHeartRate = averageHeartRate
        self.details = workoutSource.sourcableData.details
        
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.deletedAt = deletedAt
        self.syncStatus = syncStatus
        self.remoteId = remoteId
        
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


// MARK: - Workout Session Limits

extension SQWorkoutSession {
    /// Limits
    static let titleMaxChars: Int = 500
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

enum SQWorkoutDetails: Codable {
    case strength(SQStrengthDetails)

    private enum CodingKeys: String, CodingKey { case type, payload }
    private enum Kind: String, Codable { case strength }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(Kind.self, forKey: .type)
        switch type {
        case .strength:
            let payload = try container.decode(SQStrengthDetails.self, forKey: .payload)
            self = .strength(payload)
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .strength(let details):
            try container.encode(Kind.strength, forKey: .type)
            try container.encode(details, forKey: .payload)
        }
    }
}


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

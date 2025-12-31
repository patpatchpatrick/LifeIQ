//
//  SQWatchWorkoutPayload.swift
//  BeastFitnessCore
//
//  Created by Patrick Doyle on 12/30/25.
//

import Foundation

public struct SQWatchWorkoutPayload: Codable, Sendable, Equatable {

    // MARK: - Versioning
    public static let currentVersion = 1

    public let version: Int
    public let updatedAt: Date

    /// Nil = no active exercise selected
    public let activeExercise: ActiveExercise?

    // MARK: - Init
    public init(
        version: Int = SQWatchWorkoutPayload.currentVersion,
        updatedAt: Date = Date(),
        activeExercise: ActiveExercise?
    ) {
        self.version = version
        self.updatedAt = updatedAt
        self.activeExercise = activeExercise
    }
}

// MARK: - Nested Models
public extension SQWatchWorkoutPayload {

    struct ActiveExercise: Codable, Sendable, Equatable {
        public let rawExerciseId: String
        public let name: String

        /// Nil = exercise selected, but no set is active yet
        public let activeSet: ActiveSet?

        public init(
            rawExerciseId: String,
            name: String,
            activeSet: ActiveSet?
        ) {
            self.rawExerciseId = rawExerciseId
            self.name = name
            self.activeSet = activeSet
        }
    }

    struct ActiveSet: Codable, Sendable, Equatable {
        /// 1-based index (matches your VM)
        public let setNumber: Int
        public let reps: Int
        public let weight: Double
        public let isCompleted: Bool

        public init(
            setNumber: Int,
            reps: Int,
            weight: Double,
            isCompleted: Bool
        ) {
            self.setNumber = setNumber
            self.reps = reps
            self.weight = weight
            self.isCompleted = isCompleted
        }
    }
}

public extension SQWatchWorkoutPayload {

    enum WCKey {
        public static let type = "type"
        public static let payloadData = "payloadData"
    }

    enum MessageType: String {
        case workoutState
    }

    func wcMessage() throws -> [String: Any] {
        let data = try JSONEncoder().encode(self)
        return [
            WCKey.type: MessageType.workoutState.rawValue,
            WCKey.payloadData: data
        ]
    }

    static func fromWCMessage(_ message: [String: Any]) throws -> SQWatchWorkoutPayload {
        guard
            let type = message[WCKey.type] as? String,
            type == MessageType.workoutState.rawValue,
            let data = message[WCKey.payloadData] as? Data
        else {
            throw NSError(domain: "SQWatchWorkoutPayload", code: 1)
        }

        return try JSONDecoder().decode(Self.self, from: data)
    }
}

public extension SQWatchWorkoutPayload {

    /// Human-readable description suitable for display on Watch or iOS.
    ///
    /// Examples:
    /// - "No active exercise"
    /// - "Bench Press – preparing"
    /// - "Bench Press – Set 2: 8 reps @ 185.0 lb"
    var visibleDescription: String {
        guard let exercise = activeExercise else {
            return "No active exercise"
        }

        guard let set = exercise.activeSet else {
            return "\(exercise.name) – preparing"
        }

        let weightString = formatWeight(set.weight)

        return "\(exercise.name) – Set \(set.setNumber): \(set.reps) reps @ \(weightString)"
    }

    // MARK: - Formatting helpers

    private func formatWeight(_ weight: Double) -> String {
        // Avoid trailing .0 when possible
        if weight.truncatingRemainder(dividingBy: 1) == 0 {
            return "\(Int(weight)) lb"
        } else {
            return String(format: "%.1f lb", weight)
        }
    }
}

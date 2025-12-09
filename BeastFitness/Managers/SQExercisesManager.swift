//
//  SQExercisesManager.swift
//  BeastFitness
//
//  Created by Patrick Doyle on 12/8/25.
//

import Foundation

enum SQExerciseLoadError: Error {
    case fileNotFound
}

final class SQExercisesManager {
    static let shared = SQExercisesManager()

    private(set) var exercises: [SQRawStrengthExercise] = []
    private(set) var exercisesByID: [String: SQRawStrengthExercise] = [:]

    private init() {
        do {
            exercises = try Self.loadExercises()
            exercisesByID = Dictionary(uniqueKeysWithValues: exercises.map { ($0.id, $0) })
        } catch {
            // Handle however you want (assert, log, etc.)
            assertionFailure("Failed to load exercises: \(error)")
        }
    }

    private static func loadExercises() throws -> [SQRawStrengthExercise] {
        // If this JSON is in the app target:
        guard let url = Bundle.main.url(forResource: "exercises_all", withExtension: "json") else {
            throw SQExerciseLoadError.fileNotFound
        }

        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        // Your keys already look like camelCase, so no special strategy needed
        return try decoder.decode([SQRawStrengthExercise].self, from: data)
    }
}

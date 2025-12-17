//
//  SQUserDefaults.swift
//  BeastFitness
//
//  Created by Patrick Doyle on 12/17/25.
//

import Foundation

final class SQUserDefaults {
    static let shared = SQUserDefaults()
    private init() {}

    // MARK: - Keys

    /// Set of workout IDs that should be hidden from the UI
    private static let keyHiddenWorkouts = "workouts.hidden-list"

    // MARK: - Private helpers

    private var hiddenWorkoutIds: Set<String> {
        get {
            let array = UserDefaults.standard.stringArray(forKey: Self.keyHiddenWorkouts) ?? []
            return Set(array)
        }
        set {
            UserDefaults.standard.set(Array(newValue), forKey: Self.keyHiddenWorkouts)
        }
    }

    // MARK: - Public API

    /// Returns true if the workout should be hidden from the UI
    func isWorkoutHidden(_ id: String) -> Bool {
        hiddenWorkoutIds.contains(id)
    }

    /// Hide a workout (e.g. HealthKit workout created by another app)
    func hideWorkout(_ id: String) {
        var set = hiddenWorkoutIds
        set.insert(id)
        hiddenWorkoutIds = set
    }

    /// Un-hide a workout (optional but useful)
    func unhideWorkout(_ id: String) {
        var set = hiddenWorkoutIds
        set.remove(id)
        hiddenWorkoutIds = set
    }

    /// Clear all hidden workouts (debug / reset)
    func clearHiddenWorkouts() {
        UserDefaults.standard.removeObject(forKey: Self.keyHiddenWorkouts)
    }

    /// Convenience: bulk hide
    func hideWorkouts(_ ids: [String]) {
        var set = hiddenWorkoutIds
        set.formUnion(ids)
        hiddenWorkoutIds = set
    }
}

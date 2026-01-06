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

protocol SQExercisesManaging: AnyObject {
    var exercises: [SQRawStrengthExercise] { get }
    var exercisesByID: [String: SQRawStrengthExercise] { get }

    func exercise(id: String) -> SQRawStrengthExercise?

    // Recents
    func markExerciseUsed(id: String)
    func recentExerciseIDs(limit: Int) -> [String]
    func recentUsageById() -> [String: Date]

    // List sorting (recents first)
    func exercisesSortedForList(searchText: String, limitRecents: Int) -> [SQRawStrengthExercise]
}

final class SQExercisesManager: SQExercisesManaging {
    static let shared = SQExercisesManager()

    private(set) var exercises: [SQRawStrengthExercise] = []
    private(set) var exercisesByID: [String: SQRawStrengthExercise] = [:]

    private let defaults: SQUserDefaults
    private var recentLastUsedById: [String: Date]

    private init(defaults: SQUserDefaults = .shared) {
        self.defaults = defaults
        self.recentLastUsedById = defaults.recentExercisesLastUsedAtById()

        do {
            exercises = try Self.loadExercises()
            exercisesByID = Dictionary(uniqueKeysWithValues: exercises.map { ($0.id, $0) })
        } catch {
            assertionFailure("Failed to load exercises: \(error)")
        }

        pruneRecentsNotInCatalog()
    }

    func exercise(id: String) -> SQRawStrengthExercise? {
        exercisesByID[id]
    }

    // MARK: - Recents

    /// Mark an exercise as "used now" (updates last-used timestamp)
    func markExerciseUsed(id: String) {
        guard exercisesByID[id] != nil else { return }
        recentLastUsedById[id] = Date()
        defaults.setRecentExercisesLastUsedAtById(recentLastUsedById)
    }

    /// Returns exercise IDs ordered by last-used descending
    func recentExerciseIDs(limit: Int = 25) -> [String] {
        recentLastUsedById
            .sorted(by: { $0.value > $1.value })
            .prefix(max(0, limit))
            .map(\.key)
    }

    func recentUsageById() -> [String: Date] {
        recentLastUsedById
    }

    // MARK: - Sorting for list (recents first)

    /// Returns exercises sorted with recents first (by last-used desc),
    /// then the remaining exercises alphabetically by name.
    ///
    /// If `searchText` is non-empty, search is applied first, then the above ordering.
    func exercisesSortedForList(searchText: String, limitRecents: Int = 25) -> [SQRawStrengthExercise] {
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)

        let filtered: [SQRawStrengthExercise]
        if trimmed.isEmpty {
            filtered = exercises
        } else {
            let q = trimmed.lowercased()
            filtered = exercises.filter {
                $0.name.lowercased().contains(q) || $0.id.lowercased().contains(q)
            }
        }

        let recentIDsSet = Set(recentExerciseIDs(limit: limitRecents))

        return filtered.sorted { a, b in
            let aIsRecent = recentIDsSet.contains(a.id)
            let bIsRecent = recentIDsSet.contains(b.id)

            if aIsRecent != bIsRecent {
                return aIsRecent && !bIsRecent
            }

            if aIsRecent, bIsRecent {
                let da = recentLastUsedById[a.id] ?? .distantPast
                let db = recentLastUsedById[b.id] ?? .distantPast
                if da != db { return da > db }
            }

            return a.name.localizedCaseInsensitiveCompare(b.name) == .orderedAscending
        }
    }

    private func pruneRecentsNotInCatalog() {
        let validIDs = Set(exercisesByID.keys)
        let before = recentLastUsedById.count
        recentLastUsedById = recentLastUsedById.filter { validIDs.contains($0.key) }
        if recentLastUsedById.count != before {
            defaults.setRecentExercisesLastUsedAtById(recentLastUsedById)
        }
    }

    // MARK: - Load JSON

    private static func loadExercises() throws -> [SQRawStrengthExercise] {
        guard let url = Bundle.main.url(forResource: "exercises_all", withExtension: "json") else {
            throw SQExerciseLoadError.fileNotFound
        }

        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        return try decoder.decode([SQRawStrengthExercise].self, from: data)
    }
}

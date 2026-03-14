//
//  SQDailyNote.swift
//  BeastFitness
//

import Foundation

/// A free-form note logged by the user for a specific calendar day.
/// Notes are shared across morning and evening check-ins — one note per day.
/// Editable from either check-in screen.
struct SQDailyNote: Identifiable, Codable, Hashable {

    /// "YYYY-MM-DD" in the user's local timezone — uniquely identifies the day.
    /// Also serves as the Firestore document ID for this note.
    var anchorDayKey: String

    /// The user's free-form note text.
    var content: String

    /// UTC timestamp of the last edit — used for incremental Firestore sync.
    var updatedAt: Date

    var id: String { anchorDayKey }

    init(anchorDayKey: String, content: String, updatedAt: Date = .now) {
        self.anchorDayKey = anchorDayKey
        self.content = content
        self.updatedAt = updatedAt
    }
}

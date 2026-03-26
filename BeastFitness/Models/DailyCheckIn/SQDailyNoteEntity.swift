//
//  SQDailyNoteEntity.swift
//  BeastFitness
//

import Foundation
import SwiftData

/// SwiftData entity for persisting a user's daily note locally.
/// One note per calendar day, keyed by `anchorDayKey`.
@Model
final class SQDailyNoteEntity {

    /// "YYYY-MM-DD" in the user's local timezone — unique per day; also used as Firestore document ID.
    @Attribute(.unique) var anchorDayKey: String
    /// The user's free-form note text.
    var content: String
    /// UTC timestamp of last edit — used for incremental Firestore sync.
    var updatedAt: Date

    init(note: SQDailyNote) {
        self.anchorDayKey = note.anchorDayKey
        self.content = note.content
        self.updatedAt = note.updatedAt
    }
}

// MARK: - Conversion

extension SQDailyNoteEntity {

    func toNote() -> SQDailyNote {
        SQDailyNote(anchorDayKey: anchorDayKey, content: content, updatedAt: updatedAt)
    }

    /// Upserts a note for the given day. Creates if absent, updates content if present.
    static func upsert(_ note: SQDailyNote, in context: ModelContext) throws {
        let key = note.anchorDayKey
        let descriptor = FetchDescriptor<SQDailyNoteEntity>(
            predicate: #Predicate { $0.anchorDayKey == key }
        )
        if let existing = try context.fetch(descriptor).first {
            existing.content = note.content
            existing.updatedAt = note.updatedAt
        } else {
            context.insert(SQDailyNoteEntity(note: note))
        }
        try context.save()
    }

    /// Returns the note for a given `anchorDayKey`, or nil if none exists.
    static func get(for anchorDayKey: String, context: ModelContext) throws -> SQDailyNote? {
        let descriptor = FetchDescriptor<SQDailyNoteEntity>(
            predicate: #Predicate { $0.anchorDayKey == anchorDayKey }
        )
        return try context.fetch(descriptor).first?.toNote()
    }

    /// Returns all notes updated after a given date (for incremental sync).
    static func getAll(after date: Date, context: ModelContext) throws -> [SQDailyNote] {
        let descriptor = FetchDescriptor<SQDailyNoteEntity>(
            predicate: #Predicate { $0.updatedAt > date }
        )
        return try context.fetch(descriptor).map { $0.toNote() }
    }

    static func getAll(from startDate: Date, to endDate: Date, context: ModelContext) throws -> [SQDailyNote] {
        let startKey = startDate.anchorDayKey()
        let endKey = endDate.anchorDayKey()
        let descriptor = FetchDescriptor<SQDailyNoteEntity>(
            predicate: #Predicate {
                $0.anchorDayKey >= startKey && $0.anchorDayKey <= endKey
            }
        )
        return try context.fetch(descriptor).map { $0.toNote() }
    }
}

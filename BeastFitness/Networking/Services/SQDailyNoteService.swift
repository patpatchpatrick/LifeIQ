//
//  SQDailyNoteService.swift
//  BeastFitness
//

import Foundation

protocol SQDailyNoteServicing {
    static func saveDailyNote(_ note: SQDailyNote, for user: SQUser) async throws
    static func fetchDailyNotes(for user: SQUser, afterDate: Date?) async throws -> [SQDailyNote]
}

final class SQDailyNoteService: SQNetworkService, SQDailyNoteServicing {

    static func saveDailyNote(_ note: SQDailyNote, for user: SQUser) async throws {
        let _: SQVoidWrite = try await performRequest(SQDailyNoteRoute.saveDailyNote(note, user: user))
    }

    static func fetchDailyNotes(for user: SQUser, afterDate: Date? = nil) async throws -> [SQDailyNote] {
        let notes: [SQDailyNote] = try await performRequest(SQDailyNoteRoute.fetchDailyNotes(user: user, afterDate: afterDate))
        return notes
    }
}

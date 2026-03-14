//
//  SQMetricEntryService.swift
//  BeastFitness
//

import Foundation

protocol SQMetricEntryServicing {
    static func saveMetricEntry(_ entry: SQMetricEntry, for user: SQUser) async throws
    static func fetchMetricEntries(for user: SQUser, afterDate: Date?) async throws -> [SQMetricEntry]
}

final class SQMetricEntryService: SQNetworkService, SQMetricEntryServicing {

    static func saveMetricEntry(_ entry: SQMetricEntry, for user: SQUser) async throws {
        let _: SQVoidWrite = try await performRequest(SQMetricEntryRoute.saveMetricEntry(entry, user: user))
    }

    static func fetchMetricEntries(for user: SQUser, afterDate: Date? = nil) async throws -> [SQMetricEntry] {
        let entries: [SQMetricEntry] = try await performRequest(SQMetricEntryRoute.fetchMetricEntries(user: user, afterDate: afterDate))
        return entries
    }
}

//
//  SQMetricEntryService.swift
//  BeastFitness
//

import Foundation

protocol SQMetricEntryServicing {
    static func saveEntryBucket(_ bucket: SQMetricEntryBucket, for user: SQUser) async throws
    static func fetchEntryBuckets(for user: SQUser, afterDate: Date?) async throws -> [SQMetricEntryBucket]
}

final class SQMetricEntryService: SQNetworkService, SQMetricEntryServicing {

    static func saveEntryBucket(_ bucket: SQMetricEntryBucket, for user: SQUser) async throws {
        let _: SQVoidWrite = try await performRequest(SQMetricEntryRoute.saveEntryBucket(bucket, user: user))
    }

    static func fetchEntryBuckets(for user: SQUser, afterDate: Date? = nil) async throws -> [SQMetricEntryBucket] {
        try await performRequest(SQMetricEntryRoute.fetchEntryBuckets(user: user, afterDate: afterDate))
    }
}

//
//  SQDailyCheckInService.swift
//  BeastFitness
//
//  Created by Patrick Doyle on 12/1/25.
//

import Foundation

protocol SQDailyCheckInServicing {
    static func saveDailyCheckInStats(_ stats: SQDailyCheckInStats) async throws
    static func fetchAllDailyCheckIns(for user: SQUser, afterDate: Date?) async throws -> [SQDailyCheckInStats]
}

final class SQDailyCheckInService: SQNetworkService, SQDailyCheckInServicing {

    static func saveDailyCheckInStats(_ stats: SQDailyCheckInStats) async throws {
        let user = await SQAppState.shared.userState.loggedInUser
        let _ : SQVoidWrite = try await performRequest(SQDailyCheckInRoute.saveDailyCheckIn(stats, user))
    }

    /// Fetches all daily check-in stats for a user from Firestore
    /// - Parameters:
    ///   - user: The user whose stats to fetch
    ///   - afterDate: Optional date to fetch only stats after this date (for incremental sync)
    /// - Returns: Array of daily check-in stats, sorted by date ascending
    static func fetchAllDailyCheckIns(for user: SQUser, afterDate: Date? = nil) async throws -> [SQDailyCheckInStats] {
        let stats: [SQDailyCheckInStats] = try await performRequest(SQDailyCheckInRoute.fetchAllDailyCheckIns(user, afterDate: afterDate))
        return stats.sorted { $0.date < $1.date }
    }
}

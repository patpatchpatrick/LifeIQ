//
//  SQDailyCheckInService.swift
//  BeastFitness
//
//  Created by Patrick Doyle on 12/1/25.
//


protocol SQDailyCheckInServicing {
    static func saveDailyCheckInStats(_ stats: SQDailyCheckInStats) async throws
}

final class SQDailyCheckInService: SQNetworkService, SQDailyCheckInServicing {
    
    static func saveDailyCheckInStats(_ stats: SQDailyCheckInStats) async throws {
        let _ : SQVoidWrite = try await performRequest(SQDailyCheckInRoute.saveDailyCheckIn(stats, .mock)) // TODO: - PTD replace with actual user
    }
}

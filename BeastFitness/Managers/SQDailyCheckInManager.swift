//
//  SQDailyCheckInManager.swift
//  BeastFitness
//
//  Created by Patrick Doyle on 12/4/25.
//

import SwiftData
import Foundation
import BeastFitnessCore

protocol SQDailyCheckInManaging {
    /// Saves a daily check in locally and to the server
    func saveDailyCheckInStats(stats: SQDailyCheckInStats, to modelContext: ModelContext) async throws
    /// Gets daily check in stats.  This only checks locally right now, doesn't check Firebase.
    func getDailyCheckInStats(for date: Date, context: ModelContext) async throws -> SQDailyCheckInStats?
}

final class SQDailyCheckInManager: SQDailyCheckInManaging {
    private let dailyCheckInService: SQDailyCheckInServicing.Type
    
    init(dailyCheckInService: SQDailyCheckInServicing.Type = SQDailyCheckInService.self) {
        self.dailyCheckInService = dailyCheckInService
    }
    
    func saveDailyCheckInStats(stats: SQDailyCheckInStats, to modelContext: ModelContext) async throws {
        
        do {
            try SQDailyCheckInEntity.upsert(stats: stats, in: modelContext)
        } catch {
            SQLogger.shared.log(
                "Saving daily stats to SwiftData failed: \(error)",
                .error,
                context: .dailyCheckIn
            )
            
            throw error
        }
        
        do {
            try await dailyCheckInService.saveDailyCheckInStats(stats)
        } catch {
            
            SQLogger.shared.log("Submitting daily stats failed with error: \(error)", .debug, context: .dailyCheckIn)
            // TODO: PTD Error - throw check in error here and let the user know that failed to save to cloud... add a system to retry saving all failed daily check ins in the background in the future.
        }
    }
    
    func getDailyCheckInStats(for date: Date, context: ModelContext) async throws -> SQDailyCheckInStats? {
        return try SQDailyCheckInEntity.get(for: date, context: context)
    }
}

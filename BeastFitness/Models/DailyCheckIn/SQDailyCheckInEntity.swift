//
//  SQDailyCheckInEntity.swift
//  BeastFitness
//
//  Created by Patrick Doyle on 12/2/25.
//

import SwiftData
import Foundation

@Model
final class SQDailyCheckInEntity {
    @Attribute(.unique) var dateKey: String
    var date: Date
    var moodScore: Float?
    var mentalClarityScore: Float?
    var energyScore: Float?
    var sorenessScore: Float?
    var sleepHours: Float?
    var sleepQualityScore: Float?
    var notes: String?

    init(from stats: SQDailyCheckInStats) {
        self.dateKey = stats.uniqueDateKey
        self.date = stats.date
        self.moodScore = stats.moodScore
        self.mentalClarityScore = stats.mentalClarityScore
        self.energyScore = stats.energyScore
        self.sorenessScore = stats.sorenessScore
        self.sleepHours = stats.sleepHours
        self.sleepQualityScore = stats.sleepQualityScore
        self.notes = stats.notes
    }

    func toStats() -> SQDailyCheckInStats {
        SQDailyCheckInStats(
            date: date,
            moodScore: moodScore,
            mentalClarityScore: mentalClarityScore,
            energyScore: energyScore,
            sorenessScore: sorenessScore,
            sleepHours: sleepHours,
            sleepQualityScore: sleepQualityScore,
            notes: notes
        )
    }
    
    func update(from stats: SQDailyCheckInStats) {
            let normalized = Calendar.current.startOfDay(for: stats.date)
            self.date = normalized
            self.moodScore = stats.moodScore
            self.mentalClarityScore = stats.mentalClarityScore
            self.energyScore = stats.energyScore
            self.sorenessScore = stats.sorenessScore
            self.sleepHours = stats.sleepHours
            self.sleepQualityScore = stats.sleepQualityScore
            self.notes = stats.notes
        }
}

extension SQDailyCheckInEntity {
    static func upsert(
        stats: SQDailyCheckInStats,
        in context: ModelContext
    ) throws {
        let dateKey = stats.uniqueDateKey

        let descriptor = FetchDescriptor<SQDailyCheckInEntity>(
            predicate: #Predicate { $0.dateKey == dateKey }
        )

        if let existing = try context.fetch(descriptor).first {
            print("PTD Update Existing entity")
            existing.update(from: stats)
        } else {
            print("PTD Insert new entity")
            // ✅ Create new entry
            let entity = SQDailyCheckInEntity(from: stats)
            context.insert(entity)
        }

        try context.save()
    }
}

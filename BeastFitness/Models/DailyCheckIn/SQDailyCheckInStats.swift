//
//  SQDailyCheckInStats.swift
//  BeastFitness
//
//  Created by Patrick Doyle on 12/2/25.
//

import Foundation

struct SQDailyCheckInStats: Codable {
    var uniqueDateKey: String { date.firebaseDailyDateKey }
    let date: Date
    let moodScore: Float?              /// 0–10
    let mentalClarityScore: Float?     /// 0–10
    let energyScore: Float?            /// 0–10
    let sorenessScore: Float?          /// 0–10 (e.g. 0 very sore → 10 fresh)
    let sleepHours: Float?             /// Hours per day
    let sleepQualityScore: Float?      /// 1–5
    let notes: String?                 /// Free text
}

enum SQDailyCheckInField {
    case mood
    case mentalClarity
    case energy
    case soreness
    case sleepHours
    case sleepQuality
    case notes
    // future: case tags, photo
}

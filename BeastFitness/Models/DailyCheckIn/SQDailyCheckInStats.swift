//
//  SQDailyCheckInStats.swift
//  BeastFitness
//
//  Created by Patrick Doyle on 12/2/25.
//

import Foundation

struct SQDailyCheckInStats: Codable {
    static func getUniqueDateKey(for date: Date) -> String {
        date.firebaseDailyDateKey
    }
    var uniqueDateKey: String { Self.getUniqueDateKey(for: date) }
    let date: Date
    let moodScore: Float?              /// 0–10
    let mentalClarityScore: Float?     /// 0–10
    let energyScore: Float?            /// 0–10
    let sorenessScore: Float?          /// 0–10 (e.g. 0 very sore → 10 fresh)
    let sleepHours: Float?             /// Hours per day
    let sleepQualityScore: Float?      /// 1–5
    let notes: String?                 /// Free text
    
    /// Limits
    static let notesMaxChars: Int = 2500
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

extension SQDailyCheckInStats {
    
    /// Human-readable summary of the day's check-in, e.g.:
    /// "Mood: 🙂 7.5   Clarity: 😌 6.0   Energy: ⚡️8.0   Soreness: 💀 2.0   Sleep: 7.2h   Sleep Q: 4/5"
    /// Only includes fields that are non-nil.
    var summaryString: String {
        var components: [String] = []
        
        if let moodScore {
            let emoji = Self.moodEmoji(for: moodScore)
            components.append("Mood: \(emoji) \(Self.format(score: moodScore))")
        }
        
        if let mentalClarityScore {
            let emoji = Self.clarityEmoji(for: mentalClarityScore)
            components.append("Clarity: \(emoji) \(Self.format(score: mentalClarityScore))")
        }
        
        if let energyScore {
            let emoji = Self.energyEmoji(for: energyScore)
            components.append("Energy: \(emoji) \(Self.format(score: energyScore))")
        }
        
        if let sorenessScore {
            let emoji = Self.sorenessEmoji(for: sorenessScore)
            components.append("Soreness: \(emoji) \(Self.format(score: sorenessScore))")
        }
        
        if let sleepHours {
            let hours = String(format: "%.1f", sleepHours)
            components.append("Sleep: \(hours)h")
        }
        
        if let sleepQualityScore {
            let qualityInt = Int(round(sleepQualityScore))
            components.append("Sleep Q: \(qualityInt)/5")
        }
        
        return components.joined(separator: "   ")
    }
}

// MARK: - Helpers

private extension SQDailyCheckInStats {
    
    static func format(score: Float) -> String {
        String(format: "%.1f", score)
    }
    
    /// 0–10 mood -> emoji
    static func moodEmoji(for score: Float) -> String {
        switch score {
        case ..<2:      return "😫"
        case ..<4:      return "😕"
        case ..<6:      return "😐"
        case ..<8:      return "🙂"
        case ..<9.5:    return "😄"
        default:        return "🤩"
        }
    }
    
    /// 0–10 mental clarity -> emoji
    static func clarityEmoji(for score: Float) -> String {
        switch score {
        case ..<2:      return "🌫️"  // brain fog
        case ..<4:      return "😵‍💫"
        case ..<6:      return "😐"
        case ..<8:      return "🙂"
        case ..<9.5:    return "🧠"
        default:        return "⚡️"
        }
    }
    
    /// 0–10 energy -> emoji
    static func energyEmoji(for score: Float) -> String {
        switch score {
        case ..<2:      return "😴"
        case ..<4:      return "🥱"
        case ..<6:      return "🙂"
        case ..<8:      return "😄"
        case ..<9.5:    return "⚡️"
        default:        return "🔥"
        }
    }
    
    /// 0–10 soreness (0 very sore → 10 fresh) -> emoji
    static func sorenessEmoji(for score: Float) -> String {
        switch score {
        case ..<2:      return "💀"   // wrecked
        case ..<4:      return "😣"
        case ..<6:      return "😬"
        case ..<8:      return "🙂"
        case ..<9.5:    return "💪"
        default:        return "🦾"
        }
    }
}

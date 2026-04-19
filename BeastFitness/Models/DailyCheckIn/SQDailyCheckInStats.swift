//
//  SQDailyCheckInStats.swift
//  BeastFitness
//
//  Created by Patrick Doyle on 12/2/25.
//

import Foundation

struct SQDailyCheckInStats: Codable {
    let date: Date
    /// The check-in period (morning or evening) this submission belongs to.
    /// Nil when stats are fetched across all periods (e.g. for completion checks).
    var period: SQMetricPeriod?
    var values: [String: Float]
    var metricValues: [String: SQMetricLoggedValue]
    var notes: String?
    var healthKitMetricIds: Set<String>

    init(
        date: Date,
        period: SQMetricPeriod?,
        values: [String: Float],
        metricValues: [String: SQMetricLoggedValue] = [:],
        notes: String?,
        healthKitMetricIds: Set<String> = []
    ) {
        self.date = date
        self.period = period
        self.metricValues = metricValues
        self.healthKitMetricIds = healthKitMetricIds

        if !values.isEmpty {
            self.values = values
        } else {
            self.values = metricValues.mapValues(\.displayValue)
        }

        if self.metricValues.isEmpty, !values.isEmpty {
            self.metricValues = values.mapValues {
                SQMetricLoggedValue(
                    enteredMode: .unknown,
                    rawValue: $0,
                    scaleValue: nil,
                    quantityValue: nil
                )
            }
        }

        self.notes = notes
    }

    private enum CodingKeys: String, CodingKey {
        case date
        case period
        case values
        case metricValues
        case notes
        case healthKitMetricIds
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let date = try container.decode(Date.self, forKey: .date)
        let period = try container.decodeIfPresent(SQMetricPeriod.self, forKey: .period)
        let values = try container.decodeIfPresent([String: Float].self, forKey: .values) ?? [:]
        let metricValues = try container.decodeIfPresent([String: SQMetricLoggedValue].self, forKey: .metricValues) ?? [:]
        let notes = try container.decodeIfPresent(String.self, forKey: .notes)
        let healthKitMetricIds = try container.decodeIfPresent(Set<String>.self, forKey: .healthKitMetricIds) ?? []

        self.init(
            date: date,
            period: period,
            values: values,
            metricValues: metricValues,
            notes: notes,
            healthKitMetricIds: healthKitMetricIds
        )
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(date, forKey: .date)
        try container.encodeIfPresent(period, forKey: .period)
        try container.encode(values, forKey: .values)
        try container.encode(metricValues, forKey: .metricValues)
        try container.encodeIfPresent(notes, forKey: .notes)
        if !healthKitMetricIds.isEmpty {
            try container.encode(healthKitMetricIds, forKey: .healthKitMetricIds)
        }
    }

    func metricValue(for metricId: String) -> SQMetricLoggedValue? {
        metricValues[metricId]
    }

    var uniqueDateKey: String { date.firebaseDailyDateKey }
    static func getUniqueDateKey(for date: Date) -> String {
        date.firebaseDailyDateKey
    }
    
    /// Limits
    static let notesMaxChars: Int = 2500
}

enum SQDailyCheckInField: Hashable {
    case metric(id: String)
    case notes
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

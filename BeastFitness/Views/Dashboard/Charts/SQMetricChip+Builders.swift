//
//  SQMetricChip+Builders.swift
//  BeastFitness
//
//  Created by Patrick Doyle on 1/2/26.
//

// MARK: - Daily Check In Stats Chips

extension SQMetricChip.Model {

    static func chips(from stats: SQDailyCheckInStats) -> [SQMetricChip.Model] {

        let mood = stats.values[SQMetricId.mood].map(Double.init)
        let energy = stats.values[SQMetricId.energy].map(Double.init)
        let clarity = stats.values[SQMetricId.mentalClarity].map(Double.init)
        let soreness = stats.values[SQMetricId.soreness].map(Double.init)

        let sleep = stats.values[SQMetricId.sleepHours].map {
            SQDailyCheckInStats.normalizedSleepScore(hours: $0)
        }

        return [
            .init(
                id: SQMetricId.mood,
                title: "Mood",
                systemImage: "face.smiling",
                value: mood,
                maxValue: 10
            ),

            .init(
                id: SQMetricId.energy,
                title: "Energy",
                systemImage: "bolt.fill",
                value: energy,
                maxValue: 10
            ),

            .init(
                id: SQMetricId.mentalClarity,
                title: "Clarity",
                systemImage: "brain.head.profile",
                value: clarity,
                maxValue: 10
            ),

            .init(
                id: SQMetricId.soreness,
                title: "Soreness",
                systemImage: "figure.strengthtraining.traditional",
                value: soreness,
                maxValue: 10
            ),

            .init(
                id: SQMetricId.sleepHours,
                title: "Sleep",
                systemImage: "moon.stars.fill",
                value: sleep,
                maxValue: 10
            )
        ]
    }
}

// MARK: - Sleep normalization (unchanged)

fileprivate extension SQDailyCheckInStats {
    /// Converts sleep hours into a 0–10 visual score.
    /// 0–4h → 0–3
    /// 4–6h → 3–7
    /// 6–8h → 7–10
    /// 9h+ caps at 10
    static func normalizedSleepScore(hours: Float) -> Double {
        let clamped = max(0, min(hours, 10))

        switch clamped {
        case 0..<4:
            return Double(clamped / 4 * 3)
        case 4..<6:
            return Double(3 + (clamped - 4) * 2)
        case 6..<8:
            return Double(7 + (clamped - 6) * 1.5)
        default:
            return 10
        }
    }
}

// MARK: - VO2 Max Chip

extension SQMetricChip.Model {
    static func vo2MaxChip(value: Double?, lastUpdatedText: String?) -> Self {
        .init(
            id: "vo2_max",
            title: "VO₂ max",
            systemImage: "lungs.fill",
            value: value,
            unitSuffix: "ml/kg/min",
            rangeMin: 20,
            rangeMax: 60,
            trailingCaption: lastUpdatedText ?? "Latest"
        )
    }
}

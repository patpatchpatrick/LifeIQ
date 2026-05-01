//
//  SQInsightChangeBuilder.swift
//  BeastFitness
//
//  Created by Codex on 4/23/26.
//

import Foundation
import HealthKit

protocol SQInsightChangeBuilding {
    func buildChanges(
        from snapshots: [SQInsightFeatureSnapshot],
        surfaceIntent: SQInsightSurfaceIntent
    ) -> [SQInsightChange]
}

struct SQInsightChangeBuilder: SQInsightChangeBuilding {
    private struct ChangeDefinition {
        let signalId: String
        let title: String
        let category: SQInsightCategory
        let expectedEffect: SQInsightEffect
        let minimumSampleCount: Int
        let minimumEffectMagnitude: Double
    }

    private struct SignalObservation {
        let value: Double
        let rankingValue: Double
        let activityType: HKWorkoutActivityType?
    }

    private let definitions: [ChangeDefinition]

    init() {
        self.definitions = Self.defaultDefinitions
    }

    func buildChanges(
        from snapshots: [SQInsightFeatureSnapshot],
        surfaceIntent: SQInsightSurfaceIntent
    ) -> [SQInsightChange] {
        let window = window(for: surfaceIntent)

        return definitions.compactMap { definition in
            buildChange(
                definition: definition,
                snapshots: snapshots,
                window: window
            )
        }
        .sorted { $0.rankingScore > $1.rankingScore }
    }

    private func buildChange(
        definition: ChangeDefinition,
        snapshots: [SQInsightFeatureSnapshot],
        window: (recentCount: Int, priorCount: Int)
    ) -> SQInsightChange? {
        let observations = snapshots.compactMap { snapshot -> SignalObservation? in
            guard let value = snapshot.rawSignalValue(for: definition.signalId) else { return nil }
            return .init(
                value: value,
                rankingValue: rankingValue(
                    for: definition.signalId,
                    rawValue: value,
                    snapshot: snapshot
                ),
                activityType: snapshot.workoutActivityType(for: definition.signalId)
            )
        }

        let minimumRequired = max(definition.minimumSampleCount, 2)
        guard observations.count >= max(window.recentCount + window.priorCount, minimumRequired * 2) else {
            return nil
        }

        var recentValues = Array(observations.suffix(window.recentCount))
        var priorValues = Array(observations.dropLast(window.recentCount).suffix(window.priorCount))

        var title = definition.title
        if definition.signalId == SQInsightAnalysisMetricId.workoutPerformance,
           let recentActivityType = dominantActivityType(in: recentValues) {
            recentValues = recentValues.filter { $0.activityType == recentActivityType }
            priorValues = priorValues.filter { $0.activityType == recentActivityType }
            title = "\(recentActivityType.name) Performance"
        }

        guard recentValues.count >= minimumRequired,
              priorValues.count >= minimumRequired,
              let recentAverage = average(of: recentValues.map(\.value)),
              let priorAverage = average(of: priorValues.map(\.value)),
              let recentRankingAverage = average(of: recentValues.map(\.rankingValue)),
              let priorRankingAverage = average(of: priorValues.map(\.rankingValue)) else {
            return nil
        }

        let delta = recentAverage - priorAverage
        let effectMagnitude = abs(recentRankingAverage - priorRankingAverage)
        guard effectMagnitude >= effectiveMinimumEffectMagnitude(for: definition) else {
            return nil
        }

        let direction = directionForChange(
            delta: delta,
            expectedEffect: definition.expectedEffect
        )
        let sampleCount = recentValues.count + priorValues.count
        let rankingScore = SQInsightScoring.rankingScore(
            sampleCount: sampleCount,
            effectMagnitude: effectMagnitude,
            confidence: SQInsightScoring.confidence(
                sampleCount: sampleCount,
                effectMagnitude: effectMagnitude
            )
        )

        return .init(
            id: "change.\(definition.signalId).\(direction == .improved ? "improved" : "worsened")",
            signalId: definition.signalId,
            title: title,
            summary: changeSummary(
                title: title,
                direction: direction,
                effectMagnitude: effectMagnitude
            ),
            timeframeText: timeframeText(for: window),
            category: definition.category,
            direction: direction,
            recentAverage: recentAverage,
            priorAverage: priorAverage,
            deltaText: signedDeltaText(delta),
            effectMagnitude: effectMagnitude,
            rankingScore: rankingScore
        )
    }

    private func window(
        for surfaceIntent: SQInsightSurfaceIntent
    ) -> (recentCount: Int, priorCount: Int) {
        switch surfaceIntent {
        case .today:
            return (recentCount: 2, priorCount: 3)
        case .pastWeek:
            return (recentCount: 3, priorCount: 4)
        case .pastYear:
            return (recentCount: 7, priorCount: 14)
        }
    }

    private func directionForChange(
        delta: Double,
        expectedEffect: SQInsightEffect
    ) -> SQInsightChangeDirection {
        switch expectedEffect {
        case .positive:
            return delta >= 0 ? .improved : .worsened
        case .negative:
            return delta >= 0 ? .worsened : .improved
        case .neutral:
            return .improved
        }
    }

    private func changeSummary(
        title: String,
        direction: SQInsightChangeDirection,
        effectMagnitude: Double
    ) -> String {
        switch direction {
        case .improved:
            return "\(title) has moved in a better direction by \(format(effectMagnitude)) recently."
        case .worsened:
            return "\(title) has moved in a worse direction by \(format(effectMagnitude)) recently."
        }
    }

    private func timeframeText(
        for window: (recentCount: Int, priorCount: Int)
    ) -> String {
        "Last \(window.recentCount) days vs previous \(window.priorCount)"
    }

    private func dominantActivityType(
        in observations: [SignalObservation]
    ) -> HKWorkoutActivityType? {
        let counts = observations.reduce(into: [HKWorkoutActivityType: Int]()) { partialResult, observation in
            guard let activityType = observation.activityType else { return }
            partialResult[activityType, default: 0] += 1
        }

        return counts.max(by: { lhs, rhs in
            if lhs.value == rhs.value {
                return lhs.key.rawValue < rhs.key.rawValue
            }
            return lhs.value < rhs.value
        })?.key
    }

    private func rankingValue(
        for signalId: String,
        rawValue: Double,
        snapshot: SQInsightFeatureSnapshot
    ) -> Double {
        switch signalId {
        case SQInsightAnalysisMetricId.workoutPerformance,
             SQInsightAnalysisMetricId.workoutDifficulty,
             SQInsightAnalysisMetricId.restingHeartRate:
            return rawValue
        default:
            break
        }

        guard let feature = snapshot.signalFeatures[signalId] else {
            return rawValue
        }

        if let goalUtilityScore = feature.goalUtilityScore {
            return goalUtilityScore / 10
        }

        if abs(rawValue) > 10,
           let normalizedValue = feature.normalizedValue {
            return normalizedValue * 10
        }

        return rawValue
    }

    private func effectiveMinimumEffectMagnitude(for definition: ChangeDefinition) -> Double {
        switch definition.signalId {
        case SQMetricId.caffeine:
            return max(definition.minimumEffectMagnitude, 1.1)
        case SQMetricId.alcohol,
             SQMetricId.weed,
             SQMetricId.nicotine,
             SQMetricId.porn:
            return max(definition.minimumEffectMagnitude, 0.9)
        default:
            return definition.minimumEffectMagnitude
        }
    }

    private func average(of values: [Double]) -> Double? {
        guard !values.isEmpty else { return nil }
        return values.reduce(0, +) / Double(values.count)
    }

    private func format(_ value: Double) -> String {
        if value.rounded() == value {
            return String(Int(value))
        }

        return String(format: "%.1f", value)
    }

    private func signedDeltaText(_ value: Double) -> String {
        let magnitude = format(abs(value))
        return value >= 0 ? "+\(magnitude)" : "-\(magnitude)"
    }

    private static let defaultDefinitions: [ChangeDefinition] = [
        .init(
            signalId: SQMetricId.sleepHours,
            title: "Sleep Hours",
            category: .sleep,
            expectedEffect: .positive,
            minimumSampleCount: 2,
            minimumEffectMagnitude: 0.75
        ),
        .init(
            signalId: SQMetricId.sleepQuality,
            title: "Sleep Quality",
            category: .sleep,
            expectedEffect: .positive,
            minimumSampleCount: 2,
            minimumEffectMagnitude: 0.75
        ),
        .init(
            signalId: SQInsightAnalysisMetricId.restingHeartRate,
            title: "Resting HR",
            category: .recovery,
            expectedEffect: .negative,
            minimumSampleCount: 2,
            minimumEffectMagnitude: 2.0
        ),
        .init(
            signalId: SQMetricId.energy,
            title: "Energy",
            category: .recovery,
            expectedEffect: .positive,
            minimumSampleCount: 2,
            minimumEffectMagnitude: 0.75
        ),
        .init(
            signalId: SQMetricId.mood,
            title: "Mood",
            category: .habits,
            expectedEffect: .positive,
            minimumSampleCount: 2,
            minimumEffectMagnitude: 0.75
        ),
        .init(
            signalId: SQMetricId.mentalClarity,
            title: "Mental Clarity",
            category: .recovery,
            expectedEffect: .positive,
            minimumSampleCount: 2,
            minimumEffectMagnitude: 0.75
        ),
        .init(
            signalId: SQMetricId.motivation,
            title: "Motivation",
            category: .training,
            expectedEffect: .positive,
            minimumSampleCount: 2,
            minimumEffectMagnitude: 0.75
        ),
        .init(
            signalId: SQMetricId.stress,
            title: "Stress",
            category: .recovery,
            expectedEffect: .negative,
            minimumSampleCount: 2,
            minimumEffectMagnitude: 0.75
        ),
        .init(
            signalId: SQMetricId.anxiety,
            title: "Anxiety",
            category: .recovery,
            expectedEffect: .negative,
            minimumSampleCount: 2,
            minimumEffectMagnitude: 0.75
        ),
        .init(
            signalId: SQMetricId.soreness,
            title: "Recovery",
            category: .recovery,
            expectedEffect: .positive,
            minimumSampleCount: 2,
            minimumEffectMagnitude: 0.75
        ),
        .init(
            signalId: SQMetricId.alcohol,
            title: "Alcohol",
            category: .habits,
            expectedEffect: .negative,
            minimumSampleCount: 2,
            minimumEffectMagnitude: 0.75
        ),
        .init(
            signalId: SQMetricId.caffeine,
            title: "Caffeine",
            category: .habits,
            expectedEffect: .negative,
            minimumSampleCount: 2,
            minimumEffectMagnitude: 0.75
        ),
        .init(
            signalId: SQMetricId.weed,
            title: "Weed",
            category: .habits,
            expectedEffect: .negative,
            minimumSampleCount: 2,
            minimumEffectMagnitude: 0.75
        ),
        .init(
            signalId: SQInsightAnalysisMetricId.workoutPerformance,
            title: "Workout Performance",
            category: .training,
            expectedEffect: .positive,
            minimumSampleCount: 2,
            minimumEffectMagnitude: 0.4
        ),
        .init(
            signalId: SQInsightAnalysisMetricId.workoutDifficulty,
            title: "Workout Difficulty",
            category: .training,
            expectedEffect: .negative,
            minimumSampleCount: 2,
            minimumEffectMagnitude: 0.4
        )
    ]
}

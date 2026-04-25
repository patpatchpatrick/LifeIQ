//
//  SQInsightDriverBuilder.swift
//  BeastFitness
//
//  Created by Codex on 4/23/26.
//

import Foundation

protocol SQInsightDriverBuilding {
    func buildDrivers(
        from snapshots: [SQInsightFeatureSnapshot],
        surfaceIntent: SQInsightSurfaceIntent
    ) -> [SQInsightDriver]
}

struct SQInsightDriverBuilder: SQInsightDriverBuilding {
    private struct DriverDefinition {
        let signalId: String
        let title: String
        let category: SQInsightCategory
        let expectedEffect: SQInsightEffect
        let minimumSampleCount: Int
        let minimumEffectMagnitude: Double
    }

    private struct SignalObservation {
        let value: Double
    }

    private let definitions: [DriverDefinition]

    init() {
        self.definitions = Self.defaultDefinitions
    }

    func buildDrivers(
        from snapshots: [SQInsightFeatureSnapshot],
        surfaceIntent: SQInsightSurfaceIntent
    ) -> [SQInsightDriver] {
        let window = window(for: surfaceIntent)

        return definitions.compactMap { definition in
            buildDriver(
                definition: definition,
                snapshots: snapshots,
                window: window
            )
        }
        .sorted { $0.rankingScore > $1.rankingScore }
    }

    private func buildDriver(
        definition: DriverDefinition,
        snapshots: [SQInsightFeatureSnapshot],
        window: (recentCount: Int, baselineCount: Int)
    ) -> SQInsightDriver? {
        let observations = snapshots.compactMap { snapshot -> SignalObservation? in
            guard let value = snapshot.rawSignalValue(for: definition.signalId) else { return nil }
            return .init(value: value)
        }

        let minimumRequired = max(definition.minimumSampleCount, 2)
        guard observations.count >= max(window.recentCount + window.baselineCount, minimumRequired + window.recentCount) else {
            return nil
        }

        let recentValues = Array(observations.suffix(window.recentCount))
        let baselineValues = Array(observations.dropLast(window.recentCount).suffix(window.baselineCount))

        guard recentValues.count >= window.recentCount,
              baselineValues.count >= minimumRequired,
              let recentAverage = average(of: recentValues.map(\.value)),
              let baselineAverage = average(of: baselineValues.map(\.value)) else {
            return nil
        }

        let delta = recentAverage - baselineAverage
        let effectMagnitude = abs(delta)
        guard effectMagnitude >= definition.minimumEffectMagnitude else {
            return nil
        }

        let direction = directionForDriver(
            delta: delta,
            expectedEffect: definition.expectedEffect
        )
        let sampleCount = recentValues.count + baselineValues.count
        let rankingScore = SQInsightScoring.rankingScore(
            sampleCount: sampleCount,
            effectMagnitude: effectMagnitude,
            confidence: SQInsightScoring.confidence(
                sampleCount: sampleCount,
                effectMagnitude: effectMagnitude
            )
        )

        return .init(
            id: "driver.\(definition.signalId).\(direction == .supportive ? "supportive" : "drag")",
            signalId: definition.signalId,
            title: definition.title,
            summary: driverSummary(
                title: definition.title,
                direction: direction,
                effectMagnitude: effectMagnitude
            ),
            category: definition.category,
            direction: direction,
            recentAverage: recentAverage,
            baselineAverage: baselineAverage,
            deltaText: signedDeltaText(delta),
            effectMagnitude: effectMagnitude,
            rankingScore: rankingScore
        )
    }

    private func window(
        for surfaceIntent: SQInsightSurfaceIntent
    ) -> (recentCount: Int, baselineCount: Int) {
        switch surfaceIntent {
        case .today:
            return (recentCount: 1, baselineCount: 14)
        case .pastWeek:
            return (recentCount: 3, baselineCount: 14)
        case .pastYear:
            return (recentCount: 7, baselineCount: 30)
        }
    }

    private func directionForDriver(
        delta: Double,
        expectedEffect: SQInsightEffect
    ) -> SQInsightDriverDirection {
        switch expectedEffect {
        case .positive:
            return delta >= 0 ? .supportive : .drag
        case .negative:
            return delta >= 0 ? .drag : .supportive
        case .neutral:
            return .supportive
        }
    }

    private func driverSummary(
        title: String,
        direction: SQInsightDriverDirection,
        effectMagnitude: Double
    ) -> String {
        switch direction {
        case .supportive:
            return "\(title) is helping right now by \(format(effectMagnitude)) versus baseline."
        case .drag:
            return "\(title) is dragging right now by \(format(effectMagnitude)) versus baseline."
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

    private static let defaultDefinitions: [DriverDefinition] = [
        .init(
            signalId: SQMetricId.sleepHours,
            title: "Sleep Hours",
            category: .sleep,
            expectedEffect: .positive,
            minimumSampleCount: 3,
            minimumEffectMagnitude: 0.75
        ),
        .init(
            signalId: SQMetricId.sleepQuality,
            title: "Sleep Quality",
            category: .sleep,
            expectedEffect: .positive,
            minimumSampleCount: 3,
            minimumEffectMagnitude: 0.75
        ),
        .init(
            signalId: SQMetricId.energy,
            title: "Energy",
            category: .recovery,
            expectedEffect: .positive,
            minimumSampleCount: 3,
            minimumEffectMagnitude: 0.75
        ),
        .init(
            signalId: SQMetricId.mood,
            title: "Mood",
            category: .habits,
            expectedEffect: .positive,
            minimumSampleCount: 3,
            minimumEffectMagnitude: 0.75
        ),
        .init(
            signalId: SQMetricId.alcohol,
            title: "Alcohol",
            category: .habits,
            expectedEffect: .negative,
            minimumSampleCount: 3,
            minimumEffectMagnitude: 0.75
        ),
        .init(
            signalId: SQMetricId.caffeine,
            title: "Caffeine",
            category: .habits,
            expectedEffect: .negative,
            minimumSampleCount: 3,
            minimumEffectMagnitude: 0.75
        ),
        .init(
            signalId: SQMetricId.weed,
            title: "Weed",
            category: .habits,
            expectedEffect: .negative,
            minimumSampleCount: 3,
            minimumEffectMagnitude: 0.75
        ),
        .init(
            signalId: SQInsightAnalysisMetricId.workoutPerformance,
            title: "Workout Performance",
            category: .training,
            expectedEffect: .positive,
            minimumSampleCount: 2,
            minimumEffectMagnitude: 0.4
        )
    ]
}

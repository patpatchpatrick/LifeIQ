//
//  SQInsightDriverBuilder.swift
//  BeastFitness
//
//  Created by Codex on 4/23/26.
//

import Foundation
import HealthKit

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
        let activityType: HKWorkoutActivityType?
    }

    private let definitions: [DriverDefinition]

    init() {
        self.definitions = Self.defaultDefinitions
    }

    func buildDrivers(
        from snapshots: [SQInsightFeatureSnapshot],
        surfaceIntent: SQInsightSurfaceIntent
    ) -> [SQInsightDriver] {
        return definitions.compactMap { definition in
            buildDriver(
                definition: definition,
                snapshots: snapshots,
                surfaceIntent: surfaceIntent
            )
        }
        .sorted { $0.rankingScore > $1.rankingScore }
    }

    private func buildDriver(
        definition: DriverDefinition,
        snapshots: [SQInsightFeatureSnapshot],
        surfaceIntent: SQInsightSurfaceIntent
    ) -> SQInsightDriver? {
        let window = window(for: surfaceIntent, signalId: definition.signalId)
        let observations = snapshots.compactMap { snapshot -> SignalObservation? in
            guard let value = snapshot.rawSignalValue(for: definition.signalId) else { return nil }
            return .init(
                value: value,
                activityType: snapshot.workoutActivityType(for: definition.signalId)
            )
        }

        let minimumRequired = max(
            effectiveMinimumSampleCount(
                for: definition.signalId,
                base: definition.minimumSampleCount,
                surfaceIntent: surfaceIntent
            ),
            2
        )
        guard observations.count >= max(window.recentCount + window.baselineCount, minimumRequired + window.recentCount) else {
            return nil
        }

        var recentValues = Array(observations.suffix(window.recentCount))
        var baselineValues = Array(observations.dropLast(window.recentCount).suffix(window.baselineCount))
        var title = definition.title

        if definition.signalId == SQInsightAnalysisMetricId.workoutPerformance,
           let recentActivityType = dominantActivityType(in: recentValues) {
            recentValues = recentValues.filter { $0.activityType == recentActivityType }
            baselineValues = baselineValues.filter { $0.activityType == recentActivityType }
            title = "\(recentActivityType.name) Performance"
        }

        guard recentValues.count >= window.recentCount,
              baselineValues.count >= minimumRequired,
              let recentAverage = average(of: recentValues.map(\.value)),
              let baselineAverage = average(of: baselineValues.map(\.value)) else {
            return nil
        }

        let delta = recentAverage - baselineAverage
        let effectMagnitude = abs(delta)
        let minimumEffectMagnitude = effectiveMinimumEffectMagnitude(
            for: definition.signalId,
            base: definition.minimumEffectMagnitude,
            surfaceIntent: surfaceIntent
        )
        guard effectMagnitude >= minimumEffectMagnitude else {
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
            title: title,
            summary: driverSummary(
                title: title,
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
        for surfaceIntent: SQInsightSurfaceIntent,
        signalId: String
    ) -> (recentCount: Int, baselineCount: Int) {
        switch surfaceIntent {
        case .today:
            if Self.todayPreferredSignalIds.contains(signalId) {
                return (recentCount: 1, baselineCount: 7)
            }
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

    private func effectiveMinimumSampleCount(
        for signalId: String,
        base: Int,
        surfaceIntent: SQInsightSurfaceIntent
    ) -> Int {
        guard surfaceIntent == .today, Self.todayPreferredSignalIds.contains(signalId) else {
            return base
        }

        return min(base, 2)
    }

    private func effectiveMinimumEffectMagnitude(
        for signalId: String,
        base: Double,
        surfaceIntent: SQInsightSurfaceIntent
    ) -> Double {
        guard surfaceIntent == .today, Self.todayPreferredSignalIds.contains(signalId) else {
            return base
        }

        return min(base, 0.35)
    }

    private static let todayPreferredSignalIds: Set<String> = [
        SQMetricId.sleepHours,
        SQMetricId.sleepQuality,
        SQMetricId.energy,
        SQMetricId.mood,
        SQInsightAnalysisMetricId.workoutPerformance,
        SQInsightAnalysisMetricId.workoutDifficulty
    ]

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

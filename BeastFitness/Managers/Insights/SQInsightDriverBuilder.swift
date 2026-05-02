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
        surfaceIntent: SQInsightSurfaceIntent,
        referenceDate: Date
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
        let date: Date
        let value: Double
        let activityType: HKWorkoutActivityType?
    }

    private let definitions: [DriverDefinition]

    init() {
        self.definitions = Self.defaultDefinitions
    }

    func buildDrivers(
        from snapshots: [SQInsightFeatureSnapshot],
        surfaceIntent: SQInsightSurfaceIntent,
        referenceDate: Date
    ) -> [SQInsightDriver] {
        return definitions.compactMap { definition in
            buildDriver(
                definition: definition,
                snapshots: snapshots,
                surfaceIntent: surfaceIntent,
                referenceDate: referenceDate
            )
        }
        .sorted { $0.rankingScore > $1.rankingScore }
    }

    private func buildDriver(
        definition: DriverDefinition,
        snapshots: [SQInsightFeatureSnapshot],
        surfaceIntent: SQInsightSurfaceIntent,
        referenceDate: Date
    ) -> SQInsightDriver? {
        let window = window(for: surfaceIntent, signalId: definition.signalId)
        let observations = snapshots.compactMap { snapshot -> SignalObservation? in
            guard let value = snapshot.rawSignalValue(for: definition.signalId) else { return nil }
            return .init(
                date: snapshot.date,
                value: value,
                activityType: snapshot.workoutActivityType(for: definition.signalId)
            )
        }
        .sorted { $0.date < $1.date }

        guard hasFreshTodayObservation(
            observations,
            signalId: definition.signalId,
            surfaceIntent: surfaceIntent,
            referenceDate: referenceDate
        ) else {
            return nil
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
        let scoringEffectMagnitude = scoringEffectMagnitude(
            for: definition.signalId,
            rawEffectMagnitude: effectMagnitude
        )
        let minimumEffectMagnitude = effectiveMinimumScoringEffectMagnitude(
            for: definition.signalId,
            base: definition.minimumEffectMagnitude,
            surfaceIntent: surfaceIntent
        )
        guard scoringEffectMagnitude >= minimumEffectMagnitude else {
            return nil
        }

        let direction = directionForDriver(
            delta: delta,
            expectedEffect: definition.expectedEffect
        )
        guard shouldSurfaceDriver(
            signalId: definition.signalId,
            direction: direction,
            recentAverage: recentAverage
        ) else {
            return nil
        }

        let sampleCount = recentValues.count + baselineValues.count
        let confidence = SQInsightScoring.confidence(
            sampleCount: sampleCount,
            effectMagnitude: scoringEffectMagnitude
        )
        let rankingScore = SQInsightScoring.rankingScore(
            sampleCount: sampleCount,
            effectMagnitude: scoringEffectMagnitude,
            confidence: confidence
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

    private func shouldSurfaceDriver(
        signalId: String,
        direction: SQInsightDriverDirection,
        recentAverage: Double
    ) -> Bool {
        guard direction == .supportive else {
            return true
        }

        return SQInsightSupportiveReadinessGate.allowsSupportiveSignal(
            signalId: signalId,
            recentAverage: recentAverage
        )
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

    private func hasFreshTodayObservation(
        _ observations: [SignalObservation],
        signalId: String,
        surfaceIntent: SQInsightSurfaceIntent,
        referenceDate: Date
    ) -> Bool {
        guard surfaceIntent == .today,
              let latestDate = observations.map(\.date).max() else {
            return true
        }

        let calendar = Calendar.current
        let latestDay = calendar.startOfDay(for: latestDate)
        let referenceDay = calendar.startOfDay(for: referenceDate)
        let daysSinceLatest = calendar.dateComponents([.day], from: latestDay, to: referenceDay).day ?? Int.max

        guard daysSinceLatest >= 0 else {
            return true
        }

        return daysSinceLatest <= maximumTodayObservationAgeDays(for: signalId)
    }

    private func maximumTodayObservationAgeDays(for signalId: String) -> Int {
        switch signalId {
        case SQMetricId.sleepHours,
             SQMetricId.sleepQuality,
             SQInsightAnalysisMetricId.restingHeartRate,
             SQMetricId.energy,
             SQMetricId.mood,
             SQMetricId.mentalClarity,
             SQMetricId.motivation,
             SQMetricId.stress,
             SQMetricId.anxiety,
             SQMetricId.soreness:
            return 0
        case SQInsightAnalysisMetricId.workoutPerformance,
             SQInsightAnalysisMetricId.workoutDifficulty,
             SQMetricId.alcohol,
             SQMetricId.caffeine,
             SQMetricId.weed,
             SQMetricId.nicotine,
             SQMetricId.porn:
            return 1
        default:
            return 0
        }
    }

    private func effectiveMinimumSampleCount(
        for signalId: String,
        base: Int,
        surfaceIntent: SQInsightSurfaceIntent
    ) -> Int {
        guard surfaceIntent == .today, Self.todayPreferredSignalIds.contains(signalId) else {
            return base
        }

        if signalId == SQInsightAnalysisMetricId.restingHeartRate {
            return base
        }

        return min(base, 2)
    }

    private func effectiveMinimumScoringEffectMagnitude(
        for signalId: String,
        base: Double,
        surfaceIntent: SQInsightSurfaceIntent
    ) -> Double {
        let normalizedBase = max(
            0.35,
            scoringEffectMagnitude(
                for: signalId,
                rawEffectMagnitude: base
            )
        )

        guard surfaceIntent == .today, Self.todayPreferredSignalIds.contains(signalId) else {
            return normalizedBase
        }

        if signalId == SQInsightAnalysisMetricId.restingHeartRate {
            return normalizedBase
        }

        return min(normalizedBase, 0.45)
    }

    private func scoringEffectMagnitude(
        for signalId: String,
        rawEffectMagnitude: Double
    ) -> Double {
        switch signalId {
        case SQMetricId.caffeine:
            return rawEffectMagnitude / 85
        case SQInsightAnalysisMetricId.restingHeartRate:
            return rawEffectMagnitude / 4
        case SQMetricId.sleepHours:
            return rawEffectMagnitude / 0.75
        default:
            return rawEffectMagnitude
        }
    }

    private static let todayPreferredSignalIds: Set<String> = [
        SQMetricId.sleepHours,
        SQMetricId.sleepQuality,
        SQInsightAnalysisMetricId.restingHeartRate,
        SQMetricId.energy,
        SQMetricId.mood,
        SQMetricId.mentalClarity,
        SQMetricId.motivation,
        SQMetricId.stress,
        SQMetricId.anxiety,
        SQMetricId.soreness,
        SQMetricId.alcohol,
        SQMetricId.caffeine,
        SQMetricId.weed,
        SQMetricId.nicotine,
        SQMetricId.porn,
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
            signalId: SQInsightAnalysisMetricId.restingHeartRate,
            title: "Resting HR",
            category: .recovery,
            expectedEffect: .negative,
            minimumSampleCount: 3,
            minimumEffectMagnitude: 2.0
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
            signalId: SQMetricId.mentalClarity,
            title: "Mental Clarity",
            category: .recovery,
            expectedEffect: .positive,
            minimumSampleCount: 3,
            minimumEffectMagnitude: 0.75
        ),
        .init(
            signalId: SQMetricId.motivation,
            title: "Motivation",
            category: .training,
            expectedEffect: .positive,
            minimumSampleCount: 3,
            minimumEffectMagnitude: 0.75
        ),
        .init(
            signalId: SQMetricId.stress,
            title: "Stress",
            category: .recovery,
            expectedEffect: .negative,
            minimumSampleCount: 3,
            minimumEffectMagnitude: 0.75
        ),
        .init(
            signalId: SQMetricId.anxiety,
            title: "Anxiety",
            category: .recovery,
            expectedEffect: .negative,
            minimumSampleCount: 3,
            minimumEffectMagnitude: 0.75
        ),
        .init(
            signalId: SQMetricId.soreness,
            title: "Soreness",
            category: .recovery,
            expectedEffect: .negative,
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
            signalId: SQMetricId.nicotine,
            title: "Nicotine",
            category: .habits,
            expectedEffect: .negative,
            minimumSampleCount: 3,
            minimumEffectMagnitude: 0.75
        ),
        .init(
            signalId: SQMetricId.porn,
            title: "Porn",
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

//
//  SQInsightFeatureSnapshot.swift
//  BeastFitness
//
//  Created by Codex on 4/22/26.
//

import Foundation
import HealthKit

enum SQInsightAnalysisMetricId {
    static let workoutPerformance = "insight.workoutPerformance"
    static let workoutDifficulty = "insight.workoutDifficulty"
    static let restingHeartRate = "insight.restingHeartRate"
}

enum SQInsightSignalSource: String, Hashable, Codable {
    case userLogged
    case healthKitFallback
    case healthKitDerived
    case workoutDerived
}

struct SQInsightSignalFeature: Hashable {
    let signalId: String
    let title: String
    let rawValue: Double
    /// Normalized against metric min/max as 0...1 when available.
    let normalizedValue: Double?
    /// Goal-aware utility from 0...100 where 100 is best for that metric.
    let goalUtilityScore: Double?
    let signalRole: SQMetricSignalRole
    let lifeScoreImpact: SQMetricLifeScoreImpact
    let insightMode: SQMetricInsightMode
    let sensitivity: SQMetricSensitivity
    let source: SQInsightSignalSource
}

struct SQInsightFeatureSnapshot: Identifiable {
    let date: Date
    let anchorDayKey: String
    let rawSignalValues: [String: Double]
    let normalizedSignalValues: [String: Double]
    let signalFeatures: [String: SQInsightSignalFeature]
    let workoutCount: Int
    let averageWorkoutPerformance: Double?
    let workoutPerformanceActivityTypeRaw: UInt?
    let averageWorkoutDifficulty: Double?
    let workoutDifficultyActivityTypeRaw: UInt?

    var id: String { anchorDayKey }

    var hasWorkout: Bool {
        workoutCount > 0
    }

    func rawSignalValue(for signalId: String) -> Double? {
        switch signalId {
        case SQInsightAnalysisMetricId.workoutPerformance:
            return averageWorkoutPerformance
        case SQInsightAnalysisMetricId.workoutDifficulty:
            return averageWorkoutDifficulty
        default:
            return rawSignalValues[signalId]
        }
    }

    func normalizedSignalValue(for signalId: String) -> Double? {
        switch signalId {
        case SQInsightAnalysisMetricId.workoutPerformance:
            return averageWorkoutPerformance
        case SQInsightAnalysisMetricId.workoutDifficulty:
            return averageWorkoutDifficulty
        default:
            return normalizedSignalValues[signalId]
        }
    }

    func workoutActivityType(for signalId: String) -> HKWorkoutActivityType? {
        switch signalId {
        case SQInsightAnalysisMetricId.workoutPerformance:
            guard let workoutPerformanceActivityTypeRaw else { return nil }
            return HKWorkoutActivityType(rawValue: workoutPerformanceActivityTypeRaw)
        case SQInsightAnalysisMetricId.workoutDifficulty:
            guard let workoutDifficultyActivityTypeRaw else { return nil }
            return HKWorkoutActivityType(rawValue: workoutDifficultyActivityTypeRaw)
        default:
            return nil
        }
    }
}

struct SQDynamicMetricInsightBuilder {
    private let semanticResolver = SQMetricSemanticResolver()

    func buildInsights(
        from snapshots: [SQInsightFeatureSnapshot],
        metricDefinitions: [SQMetricDefinition],
        surfaceIntent: SQInsightSurfaceIntent,
        referenceDate: Date
    ) -> [SQInsight] {
        guard surfaceIntent == .today else { return [] }

        let candidates = metricDefinitions.compactMap { definition -> DynamicMetricInsightCandidate? in
            guard
                definition.isEnabled,
                !definition.isArchived,
                !definition.isPreset,
                semanticResolver.insightMode(for: definition) != .off,
                isEligibleRole(semanticResolver.signalRole(for: definition))
            else {
                return nil
            }

            let points = signalPoints(metricId: definition.id, snapshots: snapshots)
            guard
                points.count >= 14,
                hasEnoughVariance(points.map(\.utilityValue)),
                latestPointIsCurrent(points.last?.date, referenceDate: referenceDate)
            else {
                return nil
            }

            let baselineCandidate = baselineInsightCandidate(
                definition: definition,
                points: points
            )
            let trendCandidate = trendInsightCandidate(
                definition: definition,
                points: points
            )

            return [baselineCandidate, trendCandidate]
                .compactMap { $0 }
                .sorted { $0.rankingScore > $1.rankingScore }
                .first
        }

        return candidates
            .sorted { $0.rankingScore > $1.rankingScore }
            .prefix(1)
            .map(\.insight)
    }

    private struct SignalPoint {
        let date: Date
        let rawValue: Double
        let utilityValue: Double
    }

    private struct DynamicMetricInsightCandidate {
        let insight: SQInsight
        let rankingScore: Double
    }

    private func signalPoints(
        metricId: String,
        snapshots: [SQInsightFeatureSnapshot]
    ) -> [SignalPoint] {
        snapshots.compactMap { snapshot in
            guard let feature = snapshot.signalFeatures[metricId],
                  let utilityValue = feature.goalUtilityScore ?? feature.normalizedValue.map({ $0 * 100 }) else {
                return nil
            }

            return .init(
                date: snapshot.date,
                rawValue: feature.rawValue,
                utilityValue: utilityValue
            )
        }
        .sorted { $0.date < $1.date }
    }

    private func baselineInsightCandidate(
        definition: SQMetricDefinition,
        points: [SignalPoint]
    ) -> DynamicMetricInsightCandidate? {
        guard let latest = points.last else { return nil }
        let baselinePoints = points.dropLast().suffix(21)
        guard baselinePoints.count >= 10 else { return nil }

        let baselineUtilityAverage = baselinePoints.map(\.utilityValue).average ?? 0
        let baselineRawAverage = baselinePoints.map(\.rawValue).average ?? 0
        let utilityDelta = latest.utilityValue - baselineUtilityAverage
        guard abs(utilityDelta) >= 12 else { return nil }

        let title = baselineTitle(
            for: definition,
            utilityDelta: utilityDelta,
            rawDelta: latest.rawValue - baselineRawAverage
        )
        let insight = customMetricInsight(
            definition: definition,
            insightClass: .baselineChange,
            title: title,
            summary: "\(definition.title) is standing out compared with your recent baseline.",
            evidenceText: "Latest goal utility is \(signedWholeNumber(utilityDelta)) points versus the recent baseline.",
            deltaText: signedWholeNumber(utilityDelta),
            effect: utilityDelta >= 0 ? .positive : .negative,
            sampleCount: points.count,
            rankingScore: customRankingScore(
                definition: definition,
                strength: abs(utilityDelta),
                base: 10
            )
        )

        return .init(
            insight: insight,
            rankingScore: insight.rankingScore
        )
    }

    private func trendInsightCandidate(
        definition: SQMetricDefinition,
        points: [SignalPoint]
    ) -> DynamicMetricInsightCandidate? {
        let recent = points.suffix(7)
        let prior = points.dropLast(recent.count).suffix(14)
        guard recent.count >= 4, prior.count >= 8 else { return nil }

        let recentAverage = recent.map(\.utilityValue).average ?? 0
        let priorAverage = prior.map(\.utilityValue).average ?? 0
        let utilityDelta = recentAverage - priorAverage
        guard abs(utilityDelta) >= 8 else { return nil }

        let isImproving = utilityDelta >= 0
        let title = "\(definition.title) has been trending \(isImproving ? "better" : "worse")"
        let insight = customMetricInsight(
            definition: definition,
            insightClass: .trend,
            title: title,
            summary: "\(definition.title) has moved \(isImproving ? "in a better direction" : "in a tougher direction") across recent logs.",
            evidenceText: "Recent goal utility is \(signedWholeNumber(utilityDelta)) points versus the prior window.",
            deltaText: signedWholeNumber(utilityDelta),
            effect: isImproving ? .positive : .negative,
            sampleCount: recent.count + prior.count,
            rankingScore: customRankingScore(
                definition: definition,
                strength: abs(utilityDelta),
                base: 9
            )
        )

        return .init(
            insight: insight,
            rankingScore: insight.rankingScore
        )
    }

    private func customMetricInsight(
        definition: SQMetricDefinition,
        insightClass: SQInsightClass,
        title: String,
        summary: String,
        evidenceText: String,
        deltaText: String,
        effect: SQInsightEffect,
        sampleCount: Int,
        rankingScore: Double
    ) -> SQInsight {
        let kindKey = insightClass == .trend ? "trend" : "baseline"
        let effectKey = effect == .positive ? "positive" : "negative"

        return .init(
            id: "customMetric.\(definition.id).\(kindKey).\(effectKey)",
            familyKey: "customMetric.\(definition.id).\(kindKey)",
            insightClass: insightClass,
            variantPriority: 4,
            inputSignalId: definition.id,
            outputSignalId: nil,
            recommendationFamily: .observeAndCompare,
            title: title,
            summary: summary,
            evidenceText: evidenceText,
            actionText: "Keep tracking it and compare it with the rest of your day.",
            driverText: definition.title,
            outcomeText: "personal metric",
            deltaText: deltaText,
            category: category(for: definition),
            confidence: sampleCount >= 21 ? .medium : .low,
            effect: effect,
            sampleCount: sampleCount,
            rankingScore: rankingScore
        )
    }

    private func baselineTitle(
        for definition: SQMetricDefinition,
        utilityDelta: Double,
        rawDelta: Double
    ) -> String {
        if utilityDelta >= 0 {
            switch definition.goalStyle {
            case .keepLow, .avoidIt:
                return rawDelta < 0
                    ? "\(definition.title) is lower than usual"
                    : "\(definition.title) is in a better range than usual"
            case .stayInRange:
                return "\(definition.title) is in a better range than usual"
            case .buildUp, .justTrack, .unknown:
                return "\(definition.title) is above your baseline"
            }
        }

        switch definition.goalStyle {
        case .keepLow, .avoidIt:
            return rawDelta > 0
                ? "\(definition.title) is higher than usual"
                : "\(definition.title) is in a tougher range than usual"
        case .stayInRange:
            return "\(definition.title) is farther from your target range"
        case .buildUp, .justTrack, .unknown:
            return "\(definition.title) is below your baseline"
        }
    }

    private func customRankingScore(
        definition: SQMetricDefinition,
        strength: Double,
        base: Double
    ) -> Double {
        let impact = semanticResolver.lifeScoreImpact(for: definition)
        let impactBonus = (impact == .light || impact == .standard) ? 4.0 : 0.0
        return base + min(strength, 12) + impactBonus
    }

    private func category(for definition: SQMetricDefinition) -> SQInsightCategory {
        switch semanticResolver.signalRole(for: definition) {
        case .symptom, .bodyStat:
            return .recovery
        case .behavior:
            return .habits
        case .outcome, .context, .automatic, .unknown:
            return .habits
        }
    }

    private func isEligibleRole(_ role: SQMetricSignalRole) -> Bool {
        switch role {
        case .outcome, .symptom, .bodyStat, .behavior:
            return true
        case .context, .automatic, .unknown:
            return false
        }
    }

    private func latestPointIsCurrent(
        _ date: Date?,
        referenceDate: Date
    ) -> Bool {
        guard let date else { return false }
        let calendar = Calendar.current
        let latestDay = calendar.startOfDay(for: date)
        let referenceDay = calendar.startOfDay(for: referenceDate)
        let dayDelta = calendar.dateComponents([.day], from: latestDay, to: referenceDay).day ?? Int.max
        return dayDelta <= 1
    }

    private func hasEnoughVariance(_ values: [Double]) -> Bool {
        guard let min = values.min(), let max = values.max() else { return false }
        return max - min >= 5
    }

    private func signedWholeNumber(_ value: Double) -> String {
        let rounded = Int(value.rounded())
        return rounded >= 0 ? "+\(rounded)" : "\(rounded)"
    }
}

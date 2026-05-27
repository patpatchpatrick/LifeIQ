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
    static let workoutMinutes = "insight.workoutMinutes"
    static let cardioMinutes = "insight.cardioMinutes"
    static let cardioDay = "insight.cardioDay"
    static let restingHeartRate = "insight.restingHeartRate"
    static let sleepRemMinutes = "insight.sleep.remMinutes"
    static let sleepRemPercent = "insight.sleep.remPercent"
    static let sleepDeepMinutes = "insight.sleep.deepMinutes"
    static let sleepCoreMinutes = "insight.sleep.coreMinutes"
    static let sleepAwakeMinutes = "insight.sleep.awakeMinutes"
    static let sleepAwakeningCount = "insight.sleep.awakeningCount"
    static let sleepContinuity = "insight.sleep.continuity"
    static let sleepFragmentationScore = "insight.sleep.fragmentationScore"
    static let sleepEfficiency = "insight.sleep.efficiency"
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

        let candidates = metricDefinitions.flatMap { definition -> [DynamicMetricInsightCandidate] in
            guard
                definition.isEnabled,
                !definition.isArchived,
                !definition.isPreset,
                semanticResolver.insightMode(for: definition) != .off,
                isEligibleRole(semanticResolver.signalRole(for: definition))
            else {
                return []
            }

            let points = signalPoints(metricId: definition.id, snapshots: snapshots)
            guard
                points.count >= 14,
                hasEnoughVariance(points.map(\.utilityValue)),
                latestPointIsCurrent(points.last?.date, referenceDate: referenceDate)
            else {
                return []
            }

            let baselineCandidate = baselineInsightCandidate(
                definition: definition,
                points: points
            )
            let trendCandidate = trendInsightCandidate(
                definition: definition,
                points: points
            )
            let goalUtilityCandidate = goalUtilityInsightCandidate(
                definition: definition,
                points: points
            )

            return [baselineCandidate, trendCandidate, goalUtilityCandidate]
                .compactMap { $0 }
                .sorted { $0.rankingScore > $1.rankingScore }
        }

        return candidates
            .sorted { $0.rankingScore > $1.rankingScore }
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
        guard abs(utilityDelta) >= 10 else { return nil }

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
        guard abs(utilityDelta) >= 6 else { return nil }

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

    private func goalUtilityInsightCandidate(
        definition: SQMetricDefinition,
        points: [SignalPoint]
    ) -> DynamicMetricInsightCandidate? {
        guard let latest = points.last else { return nil }
        let baselinePoints = points.dropLast().suffix(21)
        guard baselinePoints.count >= 10 else { return nil }

        let baselineUtilityAverage = baselinePoints.map(\.utilityValue).average ?? 0
        let utilityDelta = latest.utilityValue - baselineUtilityAverage
        let isStrongPositive = latest.utilityValue >= 92 && utilityDelta >= 5
        let isStrongNegative = latest.utilityValue <= 58 && utilityDelta <= -5
        let isExtremeNegative = latest.utilityValue <= 45
        guard isStrongPositive || isStrongNegative || isExtremeNegative else { return nil }

        let isPositive = isStrongPositive && !isExtremeNegative
        let title = isPositive
            ? "\(definition.title) is notably better than usual"
            : "\(definition.title) is notably worse than usual"
        let insight = customMetricInsight(
            definition: definition,
            insightClass: .baselineChange,
            kindKey: "goalUtility",
            title: title,
            summary: "\(definition.title) is in an unusually \(isPositive ? "strong" : "tough") range for your recent logs.",
            evidenceText: "Latest goal utility is \(wholeNumber(latest.utilityValue)) versus a recent baseline of \(wholeNumber(baselineUtilityAverage)).",
            deltaText: signedWholeNumber(utilityDelta),
            effect: isPositive ? .positive : .negative,
            sampleCount: points.count,
            rankingScore: customRankingScore(
                definition: definition,
                strength: max(abs(utilityDelta), abs(latest.utilityValue - 75)),
                base: 10
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
        kindKey: String? = nil,
        title: String,
        summary: String,
        evidenceText: String,
        deltaText: String,
        effect: SQInsightEffect,
        sampleCount: Int,
        rankingScore: Double
    ) -> SQInsight {
        let kindKey = kindKey ?? (insightClass == .trend ? "trend" : "baseline")
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

    private func wholeNumber(_ value: Double) -> String {
        String(Int(value.rounded()))
    }
}

struct SQCustomRelationshipInsightBuilder {
    private enum RelationshipCandidateType {
        case actionableDriverCandidate
        case coMovementCandidate
        case timingAmbiguousCandidate
    }

    private struct RelationshipSample {
        let date: Date
        let input: Double
        let output: Double
    }

    private struct RelationshipCandidate {
        let inputDefinition: SQMetricDefinition
        let outputDefinition: SQMetricDefinition
        let timing: String
        let dayShift: Int
        let effectSize: Double
        let sampleCount: Int
        let lowBucketCount: Int
        let highBucketCount: Int
        let lowAverage: Double
        let highAverage: Double
        let confidence: SQInsightConfidence
        let inputSensitivity: SQMetricSensitivity
    }

    private let semanticResolver = SQMetricSemanticResolver()

    func buildInsights(
        from snapshots: [SQInsightFeatureSnapshot],
        metricDefinitions: [SQMetricDefinition],
        surfaceIntent: SQInsightSurfaceIntent,
        referenceDate: Date
    ) -> [SQInsight] {
        guard surfaceIntent == .today else { return [] }

        let outputDefinitions = metricDefinitions.filter {
            $0.isEnabled
                && !$0.isArchived
                && !$0.isPreset
                && semanticResolver.insightMode(for: $0) == .exploratoryRelationships
                && isOutputEligible(definition: $0)
        }
        guard !outputDefinitions.isEmpty else { return [] }

        var candidates = [RelationshipCandidate]()
        for outputDefinition in outputDefinitions {
            for inputDefinition in metricDefinitions where inputDefinition.id != outputDefinition.id {
                guard inputDefinition.isEnabled,
                      !inputDefinition.isArchived,
                      semanticResolver.insightMode(for: inputDefinition) != .off,
                      isInputEligible(definition: inputDefinition) else {
                    continue
                }

                if let sameDay = relationshipCandidate(
                    inputDefinition: inputDefinition,
                    outputDefinition: outputDefinition,
                    snapshots: snapshots,
                    timing: "same day",
                    dayShift: 0,
                    referenceDate: referenceDate
                ) {
                    candidates.append(sameDay)
                }

                if semanticResolver.signalRole(for: inputDefinition) == .behavior,
                   let nextDay = relationshipCandidate(
                        inputDefinition: inputDefinition,
                        outputDefinition: outputDefinition,
                        snapshots: snapshots,
                        timing: "next day",
                        dayShift: 1,
                        referenceDate: referenceDate
                   ) {
                    candidates.append(nextDay)
                }
            }
        }

        return candidates
            .sorted {
                if $0.confidence != $1.confidence {
                    return $0.confidence == .high
                }

                if abs($0.effectSize) != abs($1.effectSize) {
                    return abs($0.effectSize) > abs($1.effectSize)
                }

                return $0.sampleCount > $1.sampleCount
            }
            .prefix(1)
            .map { insight(from: $0) }
    }

    private func relationshipCandidate(
        inputDefinition: SQMetricDefinition,
        outputDefinition: SQMetricDefinition,
        snapshots: [SQInsightFeatureSnapshot],
        timing: String,
        dayShift: Int,
        referenceDate: Date
    ) -> RelationshipCandidate? {
        guard customRelationshipCandidateType(
            inputDefinition: inputDefinition,
            outputDefinition: outputDefinition,
            timing: timing
        ) == .actionableDriverCandidate else {
            return nil
        }

        let samples = relationshipSamples(
            inputDefinition: inputDefinition,
            outputDefinition: outputDefinition,
            snapshots: snapshots,
            dayShift: dayShift
        )
        guard samples.count >= 21,
              hasRecentSample(samples, referenceDate: referenceDate),
              hasEnoughVariance(samples.map(\.output)) else {
            return nil
        }

        let buckets = bucketedSamples(samples, inputDefinition: inputDefinition)
        guard buckets.low.count >= 6,
              buckets.high.count >= 6,
              let lowAverage = buckets.low.average,
              let highAverage = buckets.high.average else {
            return nil
        }

        let effectSize = highAverage - lowAverage
        guard abs(effectSize) >= 7 else { return nil }

        let confidence = confidence(sampleCount: samples.count, effectSize: effectSize)
        guard confidence == .medium || confidence == .high else { return nil }

        return .init(
            inputDefinition: inputDefinition,
            outputDefinition: outputDefinition,
            timing: timing,
            dayShift: dayShift,
            effectSize: effectSize,
            sampleCount: samples.count,
            lowBucketCount: buckets.low.count,
            highBucketCount: buckets.high.count,
            lowAverage: lowAverage,
            highAverage: highAverage,
            confidence: confidence,
            inputSensitivity: semanticResolver.sensitivity(for: inputDefinition)
        )
    }

    private func relationshipSamples(
        inputDefinition: SQMetricDefinition,
        outputDefinition: SQMetricDefinition,
        snapshots: [SQInsightFeatureSnapshot],
        dayShift: Int
    ) -> [RelationshipSample] {
        let snapshotsByDay = Dictionary(uniqueKeysWithValues: snapshots.map { ($0.anchorDayKey, $0) })
        let calendar = Calendar.current

        return snapshots.compactMap { inputSnapshot in
            let outputDate = calendar.date(byAdding: .day, value: dayShift, to: inputSnapshot.date) ?? inputSnapshot.date
            let outputDayKey = outputDate.firebaseDailyDateKey

            guard let inputFeature = inputSnapshot.signalFeatures[inputDefinition.id],
                  let outputFeature = snapshotsByDay[outputDayKey]?.signalFeatures[outputDefinition.id],
                  let outputValue = outputFeature.goalUtilityScore ?? outputFeature.normalizedValue.map({ $0 * 100 }) else {
                return nil
            }

            let inputValue = inputFeature.normalizedValue.map { $0 * 100 } ?? inputFeature.rawValue
            return .init(
                date: inputSnapshot.date,
                input: inputValue,
                output: outputValue
            )
        }
    }

    private func bucketedSamples(
        _ samples: [RelationshipSample],
        inputDefinition: SQMetricDefinition
    ) -> (low: [Double], high: [Double]) {
        if inputDefinition.goalStyle == .avoidIt {
            return (
                low: samples.filter { $0.input <= 0.01 }.map(\.output),
                high: samples.filter { $0.input > 0.01 }.map(\.output)
            )
        }

        let sortedInputs = samples.map(\.input).sorted()
        let median = sortedInputs[sortedInputs.count / 2]
        return (
            low: samples.filter { $0.input <= median }.map(\.output),
            high: samples.filter { $0.input > median }.map(\.output)
        )
    }

    private func insight(from candidate: RelationshipCandidate) -> SQInsight {
        let timingKey = candidate.timing.replacingOccurrences(of: " ", with: "-")
        let directionText = candidate.effectSize >= 0 ? "better" : "lower"
        let title: String
        if candidate.dayShift > 0 {
            title = "\(candidate.inputDefinition.title) has lined up with \(directionText) next-day \(candidate.outputDefinition.title)"
        } else {
            title = "\(candidate.inputDefinition.title) has lined up with \(directionText) \(candidate.outputDefinition.title)"
        }

        let isSensitive = candidate.inputSensitivity == .sensitive || candidate.inputSensitivity == .medicationLike
        let summary = isSensitive
            ? "This is only an observe-and-compare pattern, not a suggestion to change timing or usage."
            : "This may be worth watching across future logs."
        let actionText = isSensitive
            ? "Keep logging both and compare the pattern with care."
            : "Keep tracking both and see if this pattern holds."

        return .init(
            id: "customRelationship.\(candidate.inputDefinition.id).\(candidate.outputDefinition.id).\(timingKey)",
            familyKey: "customRelationship.\(candidate.inputDefinition.id).\(candidate.outputDefinition.id).\(timingKey)",
            insightClass: .relationship,
            variantPriority: 5,
            inputSignalId: candidate.inputDefinition.id,
            outputSignalId: candidate.outputDefinition.id,
            recommendationFamily: .observeAndCompare,
            title: title,
            summary: summary,
            evidenceText: "\(candidate.outputDefinition.title) averaged \(format(candidate.highAverage)) on higher \(candidate.inputDefinition.title.lowercased()) buckets vs \(format(candidate.lowAverage)) on lower buckets across \(candidate.sampleCount) matched days.",
            actionText: actionText,
            driverText: candidate.inputDefinition.title,
            outcomeText: candidate.outputDefinition.title,
            deltaText: signedDecimal(candidate.effectSize),
            category: category(for: candidate.inputDefinition),
            confidence: candidate.confidence,
            effect: candidate.effectSize >= 0 ? .positive : .negative,
            sampleCount: candidate.sampleCount,
            rankingScore: relationshipRankingScore(for: candidate)
        )
    }

    private func customRelationshipCandidateType(
        inputDefinition: SQMetricDefinition,
        outputDefinition: SQMetricDefinition,
        timing: String
    ) -> RelationshipCandidateType {
        let inputRole = semanticResolver.signalRole(for: inputDefinition)
        let outputRole = semanticResolver.signalRole(for: outputDefinition)

        if inputRole == .outcome && outputRole == .outcome && timing == "same day" {
            return .coMovementCandidate
        }

        if inputRole == .symptom,
           outputRole == .outcome,
           timing == "same day",
           !isSleepRecoveryStateSignal(inputDefinition.id) {
            return .coMovementCandidate
        }

        if inputRole == .behavior,
           timing == "same day",
           inputDefinition.periods.contains(.evening),
           inputDefinition.periods != Set([SQMetricPeriod.morning]) {
            return .timingAmbiguousCandidate
        }

        return .actionableDriverCandidate
    }

    private func confidence(sampleCount: Int, effectSize: Double) -> SQInsightConfidence {
        if sampleCount >= 28 && abs(effectSize) >= 9 {
            return .high
        }

        if sampleCount >= 21 && abs(effectSize) >= 7 {
            return .medium
        }

        return .low
    }

    private func relationshipRankingScore(for candidate: RelationshipCandidate) -> Double {
        let confidenceBonus = candidate.confidence == .high ? 6.0 : 3.0
        return 16 + min(abs(candidate.effectSize), 14) + min(Double(candidate.sampleCount) / 3, 12) + confidenceBonus
    }

    private func category(for definition: SQMetricDefinition) -> SQInsightCategory {
        switch semanticResolver.signalRole(for: definition) {
        case .bodyStat, .symptom, .outcome:
            return .recovery
        case .behavior:
            return .habits
        case .context, .automatic, .unknown:
            return .habits
        }
    }

    private func isInputEligible(definition: SQMetricDefinition) -> Bool {
        switch semanticResolver.signalRole(for: definition) {
        case .behavior, .bodyStat, .context:
            return true
        case .symptom:
            return [
                SQMetricId.stress,
                SQMetricId.anxiety,
                SQMetricId.soreness
            ].contains(definition.id)
        case .outcome:
            return [
                SQMetricId.sleepQuality,
                SQMetricId.sleepHours,
                SQMetricId.energy,
                SQMetricId.mentalClarity,
                SQMetricId.mood
            ].contains(definition.id)
        case .automatic, .unknown:
            return false
        }
    }

    private func isOutputEligible(definition: SQMetricDefinition) -> Bool {
        switch semanticResolver.signalRole(for: definition) {
        case .outcome, .symptom:
            return true
        case .behavior, .bodyStat, .context, .automatic, .unknown:
            return false
        }
    }

    private func isSleepRecoveryStateSignal(_ signalId: String) -> Bool {
        [
            SQMetricId.sleepQuality,
            SQMetricId.sleepHours,
            SQMetricId.soreness
        ].contains(signalId)
    }

    private func hasEnoughVariance(_ values: [Double]) -> Bool {
        guard let min = values.min(), let max = values.max() else { return false }
        return max - min >= 5
    }

    private func hasRecentSample(
        _ samples: [RelationshipSample],
        referenceDate: Date
    ) -> Bool {
        guard let latestSampleDate = samples.map(\.date).max() else {
            return false
        }

        let calendar = Calendar.current
        let latestDay = calendar.startOfDay(for: latestSampleDate)
        let referenceDay = calendar.startOfDay(for: referenceDate)
        let dayDelta = calendar.dateComponents([.day], from: latestDay, to: referenceDay).day ?? Int.max
        return dayDelta <= 14
    }

    private func format(_ value: Double) -> String {
        if value.rounded() == value {
            return String(Int(value))
        }

        return String(format: "%.1f", value)
    }

    private func signedDecimal(_ value: Double) -> String {
        let prefix = value >= 0 ? "+" : ""
        return prefix + format(value)
    }
}

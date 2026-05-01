//
//  SQInsightRelationshipAnalyzer.swift
//  BeastFitness
//
//  Created by Codex on 4/22/26.
//

import Foundation

enum SQInsightAnalysisResult {
    case insight(SQInsight)
    case readiness(SQInsightReadinessItem)
}

struct SQInsightRelationshipAnalyzer {
    private struct MatchedObservation {
        let sourceValue: Double
        let outcomeValue: Double
    }

    private struct ComparisonBuckets {
        let lowValues: [Double]
        let highValues: [Double]
        let lowLabel: String
        let highLabel: String
    }

    func analyze(
        snapshots: [SQInsightFeatureSnapshot],
        relationship: SQInsightRelationshipDefinition,
        variant: SQInsightRelationshipVariantDefinition,
        surfaceIntent: SQInsightSurfaceIntent,
        surfacingPolicy: SQInsightSurfacingPolicy
    ) -> SQInsightAnalysisResult {
        let observations = matchedObservations(
            from: snapshots,
            relationship: relationship,
            variant: variant
        )

        guard !observations.isEmpty else {
            return .readiness(.init(
                id: variant.id,
                title: displayTitle(for: relationship, variant: variant),
                status: .needsMoreData,
                summary: noObservationSummary(for: relationship, variant: variant)
            ))
        }

        guard let comparisons = selectedComparisonBuckets(from: observations, relationship: relationship) else {
            return .readiness(.init(
                id: variant.id,
                title: displayTitle(for: relationship, variant: variant),
                status: .needsMoreData,
                summary: readinessSummary(for: observations, relationship: relationship, variant: variant)
            ))
        }

        guard let lowAverage = average(of: comparisons.lowValues),
              let highAverage = average(of: comparisons.highValues) else {
            return .readiness(.init(
                id: variant.id,
                title: displayTitle(for: relationship, variant: variant),
                status: .needsMoreData,
                summary: "Need more matched \(displayOutcomeTitle(for: relationship, variant: variant).lowercased()) entries across \(comparisons.lowLabel) and \(comparisons.highLabel)."
            ))
        }

        let difference = highAverage - lowAverage
        let effectMagnitude = abs(difference)

        guard passesExpectedDirection(difference, expectedEffect: relationship.expectedEffect) else {
            return .readiness(.init(
                id: variant.id,
                title: displayTitle(for: relationship, variant: variant),
                status: .weakSignal,
                summary: "Enough matched days were found, but \(relationship.inputTitle.lowercased()) is trending the opposite direction for \(displayOutcomeTitle(for: relationship, variant: variant).lowercased()) so far."
            ))
        }

        guard effectMagnitude >= relationship.minimumEffectMagnitude else {
            return .readiness(.init(
                id: variant.id,
                title: displayTitle(for: relationship, variant: variant),
                status: .weakSignal,
                summary: "Enough matched days were found, but \(relationship.driverText.lowercased()) is only linked to a \(format(effectMagnitude)) point \(outcomeDeltaSummary(for: relationship, variant: variant)) so far."
            ))
        }

        let sampleCount = comparisons.lowValues.count + comparisons.highValues.count
        let confidence = SQInsightScoring.confidence(sampleCount: sampleCount, effectMagnitude: effectMagnitude)
        let baseRankingScore = SQInsightScoring.rankingScore(
            sampleCount: sampleCount,
            effectMagnitude: effectMagnitude,
            confidence: confidence
        )
        let rankingScore = surfacingPolicy.adjustedRankingScore(
            baseScore: baseRankingScore,
            relationship: relationship,
            variant: variant,
            surfaceIntent: surfaceIntent
        )
        let isSubtle = effectMagnitude < 0.8

        return .insight(
            SQInsight(
                id: variant.id,
                familyKey: relationship.familyKey,
                insightClass: relationship.insightClass,
                variantPriority: variant.priority,
                inputSignalId: relationship.inputSignalId,
                outputSignalId: relationship.outputSignalId,
                recommendationFamily: relationship.recommendationFamily,
                title: isSubtle
                    ? subtleInsightTitle(for: relationship, variant: variant)
                    : strongInsightTitle(for: relationship, variant: variant),
                summary: summaryText(effectMagnitude: effectMagnitude, relationship: relationship, variant: variant),
                evidenceText: "\(displayOutcomeTitle(for: relationship, variant: variant)) averaged \(format(highAverage)) after \(comparisons.highLabel) vs \(format(lowAverage)) after \(comparisons.lowLabel) across \(sampleCount) matched days\(evidenceContextSuffix(for: relationship, variant: variant)).",
                actionText: isSubtle ? relationship.subtleActionText : relationship.strongActionText,
                driverText: relationship.driverText,
                outcomeText: relationship.outcomeText,
                deltaText: deltaText(effectMagnitude: effectMagnitude, expectedEffect: relationship.expectedEffect),
                category: relationship.category,
                confidence: confidence,
                effect: relationship.expectedEffect,
                sampleCount: sampleCount,
                rankingScore: rankingScore
            )
        )
    }

    private func matchedObservations(
        from snapshots: [SQInsightFeatureSnapshot],
        relationship: SQInsightRelationshipDefinition,
        variant: SQInsightRelationshipVariantDefinition
    ) -> [MatchedObservation] {
        var observations = [MatchedObservation]()
        let calendar = Calendar.current

        switch variant.timing {
        case .sameDay:
            for snapshot in snapshots {
                guard let sourceValue = snapshot.rawSignalValue(for: relationship.inputSignalId),
                      let outcomeValue = snapshot.normalizedSignalValue(for: relationship.outputSignalId) else {
                    continue
                }

                observations.append(.init(sourceValue: sourceValue, outcomeValue: outcomeValue))
            }

        case .nextDay:
            guard snapshots.count >= 2 else { return [] }

            for index in 0..<(snapshots.count - 1) {
                let current = snapshots[index]
                let next = snapshots[index + 1]
                let dayDelta = calendar.dateComponents([.day], from: current.date, to: next.date).day

                guard dayDelta == 1,
                      let sourceValue = current.rawSignalValue(for: relationship.inputSignalId),
                      let outcomeValue = next.normalizedSignalValue(for: relationship.outputSignalId),
                      matchesOutcomeDayControl(nextSnapshot: next, relationship: relationship, variant: variant) else {
                    continue
                }

                observations.append(.init(sourceValue: sourceValue, outcomeValue: outcomeValue))
            }
        }

        return observations
    }

    private func matchesOutcomeDayControl(
        nextSnapshot: SQInsightFeatureSnapshot,
        relationship: SQInsightRelationshipDefinition,
        variant: SQInsightRelationshipVariantDefinition
    ) -> Bool {
        guard case .nextDay(let controlMetricId, _, let controlRequirement) = variant.timing,
              let controlRequirement else {
            return true
        }

        let metricId = controlMetricId ?? relationship.inputSignalId
        guard let controlValue = nextSnapshot.rawSignalValue(for: metricId) else {
            return false
        }

        switch controlRequirement {
        case .absent:
            return controlValue <= 0
        case .present:
            return controlValue > 0
        }
    }

    private func selectedComparisonBuckets(
        from observations: [MatchedObservation],
        relationship: SQInsightRelationshipDefinition
    ) -> ComparisonBuckets? {
        let strategies: [ComparisonBuckets?] = [
            zeroVsNonZeroBuckets(from: observations, relationship: relationship),
            configuredThresholdBuckets(from: observations, relationship: relationship),
            dynamicSplitBuckets(from: observations, relationship: relationship)
        ]

        return strategies
            .compactMap { $0 }
            .first(where: { hasRequiredSamples($0, minimumSampleCount: relationship.minimumBucketSampleCount) })
    }

    private func readinessSummary(
        for observations: [MatchedObservation],
        relationship: SQInsightRelationshipDefinition,
        variant: SQInsightRelationshipVariantDefinition
    ) -> String {
        if let zeroVsNonZero = zeroVsNonZeroBuckets(from: observations, relationship: relationship),
           zeroVsNonZero.lowValues.count > 0 || zeroVsNonZero.highValues.count > 0 {
            return bucketShortageSummary(for: zeroVsNonZero, minimumSampleCount: relationship.minimumBucketSampleCount)
        }

        if let configuredThresholds = configuredThresholdBuckets(from: observations, relationship: relationship),
           configuredThresholds.lowValues.count > 0 || configuredThresholds.highValues.count > 0 {
            return bucketShortageSummary(for: configuredThresholds, minimumSampleCount: relationship.minimumBucketSampleCount)
        }

        if let dynamicBuckets = dynamicSplitBuckets(from: observations, relationship: relationship),
           dynamicBuckets.lowValues.count > 0 || dynamicBuckets.highValues.count > 0 {
            return bucketShortageSummary(for: dynamicBuckets, minimumSampleCount: relationship.minimumBucketSampleCount)
        }

        let uniqueValues = Set(observations.map { roundedSourceKey(for: $0.sourceValue) })
        if uniqueValues.count < 2 {
            return "Need more variation in \(relationship.inputTitle.lowercased()) values to compare lower vs higher \(relationship.inputTitle.lowercased()) \(relationship.bucketUnitName)\(readinessContextSuffix(for: relationship, variant: variant))."
        }

        let remainingDays = max(0, (relationship.minimumBucketSampleCount * 2) - observations.count)
        if remainingDays > 0 {
            return "Need about \(remainingDays) more matched \(relationship.bucketUnitName) with both \(relationship.inputTitle.lowercased()) and \(displayOutcomeTitle(for: relationship, variant: variant).lowercased()) data."
        }

        return "Need a wider range of logged \(relationship.inputTitle.lowercased()) values before LifeIQ can compare lower vs higher \(relationship.inputTitle.lowercased()) \(relationship.bucketUnitName)\(readinessContextSuffix(for: relationship, variant: variant))."
    }

    private func noObservationSummary(
        for relationship: SQInsightRelationshipDefinition,
        variant: SQInsightRelationshipVariantDefinition
    ) -> String {
        switch variant.timing {
        case .sameDay:
            return "Need more logged \(relationship.bucketUnitName) with both \(relationship.inputTitle.lowercased()) and \(relationship.outputTitle.lowercased()) data."

        case .nextDay(_, _, let controlRequirement):
            switch controlRequirement {
            case .absent:
                return "Need more logged \(relationship.bucketUnitName) with \(relationship.inputTitle.lowercased()) data and next-day \(relationship.outputTitle.lowercased()) data when \(noNextDayControlPhrase(for: relationship, variant: variant))."
            case .present:
                return "Need more logged \(relationship.bucketUnitName) with \(relationship.inputTitle.lowercased()) data and next-day \(relationship.outputTitle.lowercased()) data where \(controlDisplayTitle(for: relationship, variant: variant).lowercased()) continues."
            case .none:
                return "Need more logged \(relationship.bucketUnitName) with both \(relationship.inputTitle.lowercased()) and next-day \(relationship.outputTitle.lowercased()) data."
            }
        }
    }

    private func zeroVsNonZeroBuckets(
        from observations: [MatchedObservation],
        relationship: SQInsightRelationshipDefinition
    ) -> ComparisonBuckets? {
        var zeroValues = [Double]()
        var nonZeroValues = [Double]()

        for observation in observations {
            if observation.sourceValue <= 0 {
                zeroValues.append(observation.outcomeValue)
            } else {
                nonZeroValues.append(observation.outcomeValue)
            }
        }

        guard !zeroValues.isEmpty || !nonZeroValues.isEmpty else { return nil }

        return .init(
            lowValues: zeroValues,
            highValues: nonZeroValues,
            lowLabel: "zero \(relationship.inputTitle.lowercased()) \(relationship.bucketUnitName)",
            highLabel: "non-zero \(relationship.inputTitle.lowercased()) \(relationship.bucketUnitName)"
        )
    }

    private func configuredThresholdBuckets(
        from observations: [MatchedObservation],
        relationship: SQInsightRelationshipDefinition
    ) -> ComparisonBuckets? {
        var lowValues = [Double]()
        var highValues = [Double]()

        for observation in observations {
            if observation.sourceValue <= relationship.lowBucketUpperBound {
                lowValues.append(observation.outcomeValue)
            } else if observation.sourceValue >= relationship.highBucketLowerBound {
                highValues.append(observation.outcomeValue)
            }
        }

        guard !lowValues.isEmpty || !highValues.isEmpty else { return nil }

        return .init(
            lowValues: lowValues,
            highValues: highValues,
            lowLabel: "lower \(relationship.inputTitle.lowercased()) \(relationship.bucketUnitName) (0-\(formattedBound(relationship.lowBucketUpperBound)))",
            highLabel: "higher \(relationship.inputTitle.lowercased()) \(relationship.bucketUnitName) (\(formattedBound(relationship.highBucketLowerBound))+)"
        )
    }

    private func dynamicSplitBuckets(
        from observations: [MatchedObservation],
        relationship: SQInsightRelationshipDefinition
    ) -> ComparisonBuckets? {
        guard observations.count >= 2 else { return nil }

        let sorted = observations.sorted { lhs, rhs in
            if lhs.sourceValue == rhs.sourceValue {
                return lhs.outcomeValue < rhs.outcomeValue
            }

            return lhs.sourceValue < rhs.sourceValue
        }

        let uniqueValues = Set(sorted.map { roundedSourceKey(for: $0.sourceValue) })
        guard uniqueValues.count >= 2 else { return nil }

        let bucketCount = sorted.count / 2
        guard bucketCount > 0 else { return nil }

        let lowBucket = Array(sorted.prefix(bucketCount))
        let highBucket = Array(sorted.suffix(bucketCount))
        guard let lowAverageSource = average(of: lowBucket.map(\.sourceValue)),
              let highAverageSource = average(of: highBucket.map(\.sourceValue)),
              highAverageSource > lowAverageSource else {
            return nil
        }

        return .init(
            lowValues: lowBucket.map(\.outcomeValue),
            highValues: highBucket.map(\.outcomeValue),
            lowLabel: "lower \(relationship.inputTitle.lowercased()) \(relationship.bucketUnitName) (\(bucketRangeLabel(for: lowBucket)))",
            highLabel: "higher \(relationship.inputTitle.lowercased()) \(relationship.bucketUnitName) (\(bucketRangeLabel(for: highBucket)))"
        )
    }

    private func bucketShortageSummary(
        for comparison: ComparisonBuckets,
        minimumSampleCount: Int
    ) -> String {
        let neededLowBucket = max(0, minimumSampleCount - comparison.lowValues.count)
        let neededHighBucket = max(0, minimumSampleCount - comparison.highValues.count)
        return "Need \(neededLowBucket) more \(comparison.lowLabel) and \(neededHighBucket) more \(comparison.highLabel)."
    }

    private func hasRequiredSamples(
        _ comparison: ComparisonBuckets,
        minimumSampleCount: Int
    ) -> Bool {
        comparison.lowValues.count >= minimumSampleCount &&
        comparison.highValues.count >= minimumSampleCount
    }

    private func displayTitle(
        for relationship: SQInsightRelationshipDefinition,
        variant: SQInsightRelationshipVariantDefinition
    ) -> String {
        "\(relationship.inputTitle) -> \(relationship.outputTitle)\(variantTitleSuffix(for: relationship, variant: variant))"
    }

    private func variantTitleSuffix(
        for relationship: SQInsightRelationshipDefinition,
        variant: SQInsightRelationshipVariantDefinition
    ) -> String {
        switch variant.timing {
        case .sameDay:
            return " (same day)"
        case .nextDay(_, _, .absent):
            return " (next day, no \(controlDisplayTitle(for: relationship, variant: variant).lowercased()))"
        case .nextDay(_, _, .present):
            return " (next day, with \(controlDisplayTitle(for: relationship, variant: variant).lowercased()))"
        case .nextDay:
            return " (next day)"
        }
    }

    private func controlDisplayTitle(
        for relationship: SQInsightRelationshipDefinition,
        variant: SQInsightRelationshipVariantDefinition
    ) -> String {
        switch variant.timing {
        case .sameDay:
            return relationship.inputTitle
        case .nextDay(_, let controlTitle, _):
            return controlTitle ?? relationship.inputTitle
        }
    }

    private func noNextDayControlPhrase(
        for relationship: SQInsightRelationshipDefinition,
        variant: SQInsightRelationshipVariantDefinition
    ) -> String {
        let title = controlDisplayTitle(for: relationship, variant: variant).lowercased()

        switch title {
        case "alcohol":
            return "the next day was alcohol-free"
        case "caffeine":
            return "there was no caffeine logged the next day"
        case "weed":
            return "there was no weed logged the next day"
        default:
            return "there was no next-day \(title)"
        }
    }

    private func displayOutcomeTitle(
        for relationship: SQInsightRelationshipDefinition,
        variant: SQInsightRelationshipVariantDefinition
    ) -> String {
        switch variant.timing {
        case .sameDay:
            return relationship.outputTitle
        case .nextDay(_, _, .absent):
            return "Next-day \(relationship.outputTitle.lowercased())"
        case .nextDay(_, _, .present):
            return "Next-day \(relationship.outputTitle.lowercased()) with \(controlDisplayTitle(for: relationship, variant: variant).lowercased())"
        case .nextDay:
            return "Next-day \(relationship.outputTitle.lowercased())"
        }
    }

    private func evidenceContextSuffix(
        for relationship: SQInsightRelationshipDefinition,
        variant: SQInsightRelationshipVariantDefinition
    ) -> String {
        switch variant.timing {
        case .sameDay:
            return " on the same day"
        case .nextDay(_, _, .absent):
            return " even when \(noNextDayControlPhrase(for: relationship, variant: variant))"
        case .nextDay(_, _, .present):
            return " when \(controlDisplayTitle(for: relationship, variant: variant).lowercased()) continued the next day"
        case .nextDay:
            return ""
        }
    }

    private func readinessContextSuffix(
        for relationship: SQInsightRelationshipDefinition,
        variant: SQInsightRelationshipVariantDefinition
    ) -> String {
        switch variant.timing {
        case .sameDay:
            return ""
        case .nextDay(_, _, .absent):
            return " when \(noNextDayControlPhrase(for: relationship, variant: variant))"
        case .nextDay(_, _, .present):
            return " when \(controlDisplayTitle(for: relationship, variant: variant).lowercased()) continues the next day"
        case .nextDay:
            return ""
        }
    }

    private func strongInsightTitle(
        for relationship: SQInsightRelationshipDefinition,
        variant: SQInsightRelationshipVariantDefinition
    ) -> String {
        switch relationship.expectedEffect {
        case .negative:
            return "\(relationship.driverText) tends to hurt \(timingAdjustedOutcomeTitle(for: relationship, variant: variant))"
        case .positive:
            return "\(relationship.driverText) tends to help \(timingAdjustedOutcomeTitle(for: relationship, variant: variant))"
        case .neutral:
            return "\(relationship.driverText) tends to shift \(timingAdjustedOutcomeTitle(for: relationship, variant: variant))"
        }
    }

    private func subtleInsightTitle(
        for relationship: SQInsightRelationshipDefinition,
        variant: SQInsightRelationshipVariantDefinition
    ) -> String {
        switch relationship.expectedEffect {
        case .negative:
            return "\(relationship.driverText) has been lining up with lower \(timingAdjustedOutcomeTitle(for: relationship, variant: variant))"
        case .positive:
            return "\(relationship.driverText) has been lining up with better \(timingAdjustedOutcomeTitle(for: relationship, variant: variant))"
        case .neutral:
            return "\(relationship.driverText) has been lining up with shifts in \(timingAdjustedOutcomeTitle(for: relationship, variant: variant))"
        }
    }

    private func timingAdjustedOutcomeTitle(
        for relationship: SQInsightRelationshipDefinition,
        variant: SQInsightRelationshipVariantDefinition
    ) -> String {
        switch variant.timing {
        case .sameDay:
            return relationship.outputTitle.lowercased()
        case .nextDay(_, _, .absent):
            return "next-day \(relationship.outputTitle.lowercased())"
        case .nextDay(_, _, .present):
            return "next-day \(relationship.outputTitle.lowercased()) when \(controlDisplayTitle(for: relationship, variant: variant).lowercased()) continues"
        case .nextDay:
            return "next-day \(relationship.outputTitle.lowercased())"
        }
    }

    private func outcomeDeltaSummary(
        for relationship: SQInsightRelationshipDefinition,
        variant: SQInsightRelationshipVariantDefinition
    ) -> String {
        switch relationship.expectedEffect {
        case .negative:
            return "\(timingAdjustedOutcomeTitle(for: relationship, variant: variant)) drop"
        case .positive:
            return "\(timingAdjustedOutcomeTitle(for: relationship, variant: variant)) lift"
        case .neutral:
            return "\(timingAdjustedOutcomeTitle(for: relationship, variant: variant)) shift"
        }
    }

    private func summaryText(
        effectMagnitude: Double,
        relationship: SQInsightRelationshipDefinition,
        variant: SQInsightRelationshipVariantDefinition
    ) -> String {
        switch (relationship.expectedEffect, variant.timing) {
        case (.negative, .sameDay):
            return "\(relationship.driverText) is associated with a \(format(effectMagnitude)) point lower \(relationship.outputTitle.lowercased()) on the same day."
        case (.positive, .sameDay):
            return "\(relationship.driverText) is associated with a \(format(effectMagnitude)) point higher \(relationship.outputTitle.lowercased()) on the same day."
        case (.neutral, .sameDay):
            return "\(relationship.driverText) is associated with a \(format(effectMagnitude)) point shift in \(relationship.outputTitle.lowercased()) on the same day."
        case (.negative, .nextDay(_, _, .absent)):
            return "\(relationship.driverText) is associated with a \(format(effectMagnitude)) point lower next-day \(relationship.outputTitle.lowercased()), even when \(noNextDayControlPhrase(for: relationship, variant: variant))."
        case (.positive, .nextDay(_, _, .absent)):
            return "\(relationship.driverText) is associated with a \(format(effectMagnitude)) point higher next-day \(relationship.outputTitle.lowercased()), even when \(noNextDayControlPhrase(for: relationship, variant: variant))."
        case (.neutral, .nextDay(_, _, .absent)):
            return "\(relationship.driverText) is associated with a \(format(effectMagnitude)) point shift in next-day \(relationship.outputTitle.lowercased()), even when \(noNextDayControlPhrase(for: relationship, variant: variant))."
        case (.negative, .nextDay(_, _, .present)):
            return "\(relationship.driverText) is associated with a \(format(effectMagnitude)) point lower next-day \(relationship.outputTitle.lowercased()) when \(controlDisplayTitle(for: relationship, variant: variant).lowercased()) continues."
        case (.positive, .nextDay(_, _, .present)):
            return "\(relationship.driverText) is associated with a \(format(effectMagnitude)) point higher next-day \(relationship.outputTitle.lowercased()) when \(controlDisplayTitle(for: relationship, variant: variant).lowercased()) continues."
        case (.neutral, .nextDay(_, _, .present)):
            return "\(relationship.driverText) is associated with a \(format(effectMagnitude)) point shift in next-day \(relationship.outputTitle.lowercased()) when \(controlDisplayTitle(for: relationship, variant: variant).lowercased()) continues."
        case (.negative, .nextDay):
            return "\(relationship.driverText) is associated with a \(format(effectMagnitude)) point lower next-day \(relationship.outputTitle.lowercased())."
        case (.positive, .nextDay):
            return "\(relationship.driverText) is associated with a \(format(effectMagnitude)) point higher next-day \(relationship.outputTitle.lowercased())."
        case (.neutral, .nextDay):
            return "\(relationship.driverText) is associated with a \(format(effectMagnitude)) point shift in next-day \(relationship.outputTitle.lowercased())."
        }
    }

    private func deltaText(effectMagnitude: Double, expectedEffect: SQInsightEffect) -> String {
        switch expectedEffect {
        case .negative:
            return "-\(format(effectMagnitude)) pts"
        case .positive:
            return "+\(format(effectMagnitude)) pts"
        case .neutral:
            return "\(format(effectMagnitude)) pts"
        }
    }

    private func passesExpectedDirection(_ difference: Double, expectedEffect: SQInsightEffect) -> Bool {
        switch expectedEffect {
        case .negative:
            return difference < 0
        case .positive:
            return difference > 0
        case .neutral:
            return difference != 0
        }
    }

    private func bucketRangeLabel(for bucket: [MatchedObservation]) -> String {
        guard let minSource = bucket.map(\.sourceValue).min(),
              let maxSource = bucket.map(\.sourceValue).max() else {
            return "mixed"
        }

        return "\(formattedBound(minSource))-\(formattedBound(maxSource))"
    }

    private func roundedSourceKey(for value: Double) -> Int {
        Int((value * 10).rounded())
    }

    private func average(of values: [Double]) -> Double? {
        guard !values.isEmpty else { return nil }
        return values.reduce(0, +) / Double(values.count)
    }

    private func format(_ value: Double, decimals: Int = 1) -> String {
        String(format: "%.\(decimals)f", value)
    }

    private func formattedBound(_ value: Double) -> String {
        let roundedValue = value.rounded(.towardZero)
        if abs(value - roundedValue) < 0.01 {
            return String(Int(roundedValue))
        }

        return format(value)
    }
}

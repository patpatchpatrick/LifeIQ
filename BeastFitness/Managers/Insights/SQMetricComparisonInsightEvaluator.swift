//
//  SQMetricComparisonInsightEvaluator.swift
//  BeastFitness
//
//  Created by Codex on 4/8/26.
//

import Foundation

enum SQMetricComparisonTiming {
    case sameDay
    case nextDay
}

enum SQMetricComparisonOutcomeDayControlRequirement {
    case absent
    case present
}

struct SQMetricComparisonInsightConfig {
    let id: String
    let familyKey: String
    let variantPriority: Int
    let sourceMetricId: String
    let sourceTitle: String
    let outcomeMetricId: String
    let outcomeTitle: String
    let category: SQInsightCategory
    let timing: SQMetricComparisonTiming
    let outcomeDayControlMetricId: String?
    let outcomeDayControlTitle: String?
    let outcomeDayControlRequirement: SQMetricComparisonOutcomeDayControlRequirement?
    let lowBucketUpperBound: Double
    let highBucketLowerBound: Double
    let bucketUnitName: String
    let minimumBucketSampleCount: Int
    let minimumEffectMagnitude: Double
    let expectedEffect: SQInsightEffect
    let driverText: String
    let outcomeText: String
    let strongActionText: String
    let subtleActionText: String

    init(
        id: String,
        familyKey: String? = nil,
        variantPriority: Int = 0,
        sourceMetricId: String,
        sourceTitle: String,
        outcomeMetricId: String,
        outcomeTitle: String,
        category: SQInsightCategory,
        timing: SQMetricComparisonTiming = .nextDay,
        outcomeDayControlMetricId: String? = nil,
        outcomeDayControlTitle: String? = nil,
        outcomeDayControlRequirement: SQMetricComparisonOutcomeDayControlRequirement? = nil,
        lowBucketUpperBound: Double,
        highBucketLowerBound: Double,
        bucketUnitName: String = "days",
        minimumBucketSampleCount: Int = 2,
        minimumEffectMagnitude: Double = 0.15,
        expectedEffect: SQInsightEffect = .negative,
        driverText: String,
        outcomeText: String,
        strongActionText: String,
        subtleActionText: String? = nil
    ) {
        self.id = id
        self.familyKey = familyKey ?? id
        self.variantPriority = variantPriority
        self.sourceMetricId = sourceMetricId
        self.sourceTitle = sourceTitle
        self.outcomeMetricId = outcomeMetricId
        self.outcomeTitle = outcomeTitle
        self.category = category
        self.timing = timing
        self.outcomeDayControlMetricId = outcomeDayControlMetricId
        self.outcomeDayControlTitle = outcomeDayControlTitle
        self.outcomeDayControlRequirement = outcomeDayControlRequirement
        self.lowBucketUpperBound = lowBucketUpperBound
        self.highBucketLowerBound = highBucketLowerBound
        self.bucketUnitName = bucketUnitName
        self.minimumBucketSampleCount = minimumBucketSampleCount
        self.minimumEffectMagnitude = minimumEffectMagnitude
        self.expectedEffect = expectedEffect
        self.driverText = driverText
        self.outcomeText = outcomeText
        self.strongActionText = strongActionText
        self.subtleActionText = subtleActionText ?? strongActionText
    }

    var title: String {
        "\(sourceTitle) -> \(outcomeTitle)\(variantTitleSuffix)"
    }

    private var variantTitleSuffix: String {
        switch (timing, outcomeDayControlRequirement) {
        case (.sameDay, _):
            return " (same day)"
        case (.nextDay, .some(.absent)):
            return " (next day, no \(controlDisplayTitle.lowercased()))"
        case (.nextDay, .some(.present)):
            return " (next day, with \(controlDisplayTitle.lowercased()))"
        case (.nextDay, .none):
            return " (next day)"
        }
    }

    var controlDisplayTitle: String {
        outcomeDayControlTitle ?? sourceTitle
    }
}

struct SQMetricComparisonInsightEvaluator: SQInsightEvaluating {
    let config: SQMetricComparisonInsightConfig

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

    var id: String { config.id }
    var title: String { config.title }

    func evaluate(snapshots: [SQInsightDailySnapshot]) -> SQInsightEvaluationResult {
        let observations = matchedObservations(from: snapshots)

        guard !observations.isEmpty else {
            return needsMoreData(summary: noObservationSummary)
        }

        guard let comparisons = selectedComparisonBuckets(from: observations) else {
            return needsMoreData(summary: readinessSummary(for: observations))
        }

        guard let lowAverage = average(of: comparisons.lowValues),
              let highAverage = average(of: comparisons.highValues) else {
            return needsMoreData(summary: "Need more matched \(displayOutcomeTitle.lowercased()) entries across \(comparisons.lowLabel) and \(comparisons.highLabel).")
        }

        let difference = highAverage - lowAverage
        let effectMagnitude = abs(difference)

        guard passesExpectedDirection(difference) else {
            return weakSignal(
                summary: "Enough matched days were found, but \(config.sourceTitle.lowercased()) is trending the opposite direction for \(displayOutcomeTitle.lowercased()) so far."
            )
        }

        guard effectMagnitude >= config.minimumEffectMagnitude else {
            return weakSignal(
                summary: "Enough matched days were found, but \(config.driverText.lowercased()) is only linked to a \(format(effectMagnitude)) point \(outcomeDeltaSummary) so far."
            )
        }

        let sampleCount = comparisons.lowValues.count + comparisons.highValues.count
        let confidence = insightConfidence(sampleCount: sampleCount, effectMagnitude: effectMagnitude)
        let isSubtle = effectMagnitude < 0.8

        return .insight(SQInsight(
            id: id,
            familyKey: config.familyKey,
            variantPriority: config.variantPriority,
            title: isSubtle ? subtleInsightTitle : strongInsightTitle,
            summary: summaryText(effectMagnitude: effectMagnitude),
            evidenceText: "\(displayOutcomeTitle) averaged \(format(highAverage)) after \(comparisons.highLabel) vs \(format(lowAverage)) after \(comparisons.lowLabel) across \(sampleCount) matched days\(evidenceContextSuffix).",
            actionText: isSubtle ? config.subtleActionText : config.strongActionText,
            driverText: config.driverText,
            outcomeText: config.outcomeText,
            deltaText: deltaText(effectMagnitude: effectMagnitude),
            category: config.category,
            confidence: confidence,
            effect: config.expectedEffect,
            sampleCount: sampleCount,
            rankingScore: insightRankingScore(
                sampleCount: sampleCount,
                effectMagnitude: effectMagnitude,
                confidence: confidence
            )
        ))
    }

    private var noObservationSummary: String {
        switch (config.timing, config.outcomeDayControlRequirement) {
        case (.sameDay, _):
            return "Need more logged \(config.bucketUnitName) with both \(config.sourceTitle.lowercased()) and \(config.outcomeTitle.lowercased()) data."
        case (.nextDay, .some(.absent)):
            return "Need more logged \(config.bucketUnitName) with \(config.sourceTitle.lowercased()) data and next-day \(config.outcomeTitle.lowercased()) data where \(config.controlDisplayTitle.lowercased()) stays at zero."
        case (.nextDay, .some(.present)):
            return "Need more logged \(config.bucketUnitName) with \(config.sourceTitle.lowercased()) data and next-day \(config.outcomeTitle.lowercased()) data where \(config.controlDisplayTitle.lowercased()) continues."
        case (.nextDay, .none):
            return "Need more logged \(config.bucketUnitName) with both \(config.sourceTitle.lowercased()) and next-day \(config.outcomeTitle.lowercased()) data."
        }
    }

    private func matchedObservations(from snapshots: [SQInsightDailySnapshot]) -> [MatchedObservation] {
        var observations = [MatchedObservation]()
        let calendar = Calendar.current

        switch config.timing {
        case .sameDay:
            for snapshot in snapshots {
                guard let sourceValue = snapshot.rawMetricValue(for: config.sourceMetricId),
                      let outcomeValue = snapshot.normalizedMetricValue(for: config.outcomeMetricId) else {
                    continue
                }

                observations.append(.init(sourceValue: sourceValue, outcomeValue: outcomeValue))
            }

        case .nextDay:
            guard snapshots.count >= 2 else {
                return []
            }

            for index in 0..<(snapshots.count - 1) {
                let current = snapshots[index]
                let next = snapshots[index + 1]
                let dayDelta = calendar.dateComponents([.day], from: current.date, to: next.date).day

                guard dayDelta == 1,
                      let sourceValue = current.rawMetricValue(for: config.sourceMetricId),
                      let outcomeValue = next.normalizedMetricValue(for: config.outcomeMetricId),
                      matchesOutcomeDayControl(nextSnapshot: next) else {
                    continue
                }

                observations.append(.init(sourceValue: sourceValue, outcomeValue: outcomeValue))
            }
        }

        return observations
    }

    private func matchesOutcomeDayControl(nextSnapshot: SQInsightDailySnapshot) -> Bool {
        guard let controlRequirement = config.outcomeDayControlRequirement else {
            return true
        }

        let controlMetricId = config.outcomeDayControlMetricId ?? config.sourceMetricId
        guard let controlValue = nextSnapshot.rawMetricValue(for: controlMetricId) else {
            return false
        }

        switch controlRequirement {
        case .absent:
            return controlValue <= 0
        case .present:
            return controlValue > 0
        }
    }

    private var displayOutcomeTitle: String {
        switch (config.timing, config.outcomeDayControlRequirement) {
        case (.sameDay, _):
            return config.outcomeTitle
        case (.nextDay, .some(.absent)):
            return "Next-day \(config.outcomeTitle.lowercased()) without \(config.controlDisplayTitle.lowercased())"
        case (.nextDay, .some(.present)):
            return "Next-day \(config.outcomeTitle.lowercased()) with \(config.controlDisplayTitle.lowercased())"
        case (.nextDay, .none):
            return "Next-day \(config.outcomeTitle.lowercased())"
        }
    }

    private var evidenceContextSuffix: String {
        switch (config.timing, config.outcomeDayControlRequirement) {
        case (.sameDay, _):
            return " on the same day"
        case (.nextDay, .some(.absent)):
            return " when \(config.controlDisplayTitle.lowercased()) stayed at zero the next day"
        case (.nextDay, .some(.present)):
            return " when \(config.controlDisplayTitle.lowercased()) continued the next day"
        case (.nextDay, .none):
            return ""
        }
    }

    private func selectedComparisonBuckets(from observations: [MatchedObservation]) -> ComparisonBuckets? {
        let strategies: [ComparisonBuckets?] = [
            zeroVsNonZeroBuckets(from: observations),
            configuredThresholdBuckets(from: observations),
            dynamicSplitBuckets(from: observations)
        ]

        return strategies
            .compactMap { $0 }
            .first(where: hasRequiredSamples(_:))
    }

    private func readinessSummary(for observations: [MatchedObservation]) -> String {
        if let zeroVsNonZero = zeroVsNonZeroBuckets(from: observations),
           zeroVsNonZero.lowValues.count > 0 || zeroVsNonZero.highValues.count > 0 {
            return bucketShortageSummary(for: zeroVsNonZero)
        }

        if let configuredThresholds = configuredThresholdBuckets(from: observations),
           configuredThresholds.lowValues.count > 0 || configuredThresholds.highValues.count > 0 {
            return bucketShortageSummary(for: configuredThresholds)
        }

        if let dynamicBuckets = dynamicSplitBuckets(from: observations),
           dynamicBuckets.lowValues.count > 0 || dynamicBuckets.highValues.count > 0 {
            return bucketShortageSummary(for: dynamicBuckets)
        }

        let uniqueValues = Set(observations.map { roundedSourceKey(for: $0.sourceValue) })
        if uniqueValues.count < 2 {
            return "Need more variation in \(config.sourceTitle.lowercased()) values to compare lower vs higher \(config.sourceTitle.lowercased()) \(config.bucketUnitName)\(readinessContextSuffix)."
        }

        let remainingDays = max(0, (config.minimumBucketSampleCount * 2) - observations.count)
        if remainingDays > 0 {
            return "Need about \(remainingDays) more matched \(config.bucketUnitName) with both \(config.sourceTitle.lowercased()) and \(displayOutcomeTitle.lowercased()) data."
        }

        return "Need a wider range of logged \(config.sourceTitle.lowercased()) values before LifeIQ can compare lower vs higher \(config.sourceTitle.lowercased()) \(config.bucketUnitName)\(readinessContextSuffix)."
    }

    private var readinessContextSuffix: String {
        switch (config.timing, config.outcomeDayControlRequirement) {
        case (.sameDay, _), (.nextDay, .none):
            return ""
        case (.nextDay, .some(.absent)):
            return " when \(config.controlDisplayTitle.lowercased()) stays at zero the next day"
        case (.nextDay, .some(.present)):
            return " when \(config.controlDisplayTitle.lowercased()) continues the next day"
        }
    }

    private func bucketShortageSummary(for comparison: ComparisonBuckets) -> String {
        let neededLowBucket = max(0, config.minimumBucketSampleCount - comparison.lowValues.count)
        let neededHighBucket = max(0, config.minimumBucketSampleCount - comparison.highValues.count)
        return "Need \(neededLowBucket) more \(comparison.lowLabel) and \(neededHighBucket) more \(comparison.highLabel)."
    }

    private func hasRequiredSamples(_ comparison: ComparisonBuckets) -> Bool {
        comparison.lowValues.count >= config.minimumBucketSampleCount &&
        comparison.highValues.count >= config.minimumBucketSampleCount
    }

    private func zeroVsNonZeroBuckets(from observations: [MatchedObservation]) -> ComparisonBuckets? {
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
            lowLabel: "zero \(config.sourceTitle.lowercased()) \(config.bucketUnitName)",
            highLabel: "non-zero \(config.sourceTitle.lowercased()) \(config.bucketUnitName)"
        )
    }

    private func configuredThresholdBuckets(from observations: [MatchedObservation]) -> ComparisonBuckets? {
        var lowValues = [Double]()
        var highValues = [Double]()

        for observation in observations {
            if observation.sourceValue <= config.lowBucketUpperBound {
                lowValues.append(observation.outcomeValue)
            } else if observation.sourceValue >= config.highBucketLowerBound {
                highValues.append(observation.outcomeValue)
            }
        }

        guard !lowValues.isEmpty || !highValues.isEmpty else { return nil }

        return .init(
            lowValues: lowValues,
            highValues: highValues,
            lowLabel: "lower \(config.sourceTitle.lowercased()) \(config.bucketUnitName) (0-\(formattedBound(config.lowBucketUpperBound)))",
            highLabel: "higher \(config.sourceTitle.lowercased()) \(config.bucketUnitName) (\(formattedBound(config.highBucketLowerBound))+)"
        )
    }

    private func dynamicSplitBuckets(from observations: [MatchedObservation]) -> ComparisonBuckets? {
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
            lowLabel: "lower \(config.sourceTitle.lowercased()) \(config.bucketUnitName) (\(bucketRangeLabel(for: lowBucket)))",
            highLabel: "higher \(config.sourceTitle.lowercased()) \(config.bucketUnitName) (\(bucketRangeLabel(for: highBucket)))"
        )
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

    private var strongInsightTitle: String {
        switch config.expectedEffect {
        case .negative:
            return "\(config.driverText) tends to hurt \(timingAdjustedOutcomeTitle)"
        case .positive:
            return "\(config.driverText) tends to help \(timingAdjustedOutcomeTitle)"
        case .neutral:
            return "\(config.driverText) tends to shift \(timingAdjustedOutcomeTitle)"
        }
    }

    private var subtleInsightTitle: String {
        switch config.expectedEffect {
        case .negative:
            return "\(config.driverText) may be slightly lowering \(timingAdjustedOutcomeTitle)"
        case .positive:
            return "\(config.driverText) may be slightly improving \(timingAdjustedOutcomeTitle)"
        case .neutral:
            return "\(config.driverText) may be slightly shifting \(timingAdjustedOutcomeTitle)"
        }
    }

    private var timingAdjustedOutcomeTitle: String {
        switch (config.timing, config.outcomeDayControlRequirement) {
        case (.sameDay, _):
            return config.outcomeTitle.lowercased()
        case (.nextDay, .some(.absent)):
            return "next-day \(config.outcomeTitle.lowercased()) when \(config.controlDisplayTitle.lowercased()) stays at zero"
        case (.nextDay, .some(.present)):
            return "next-day \(config.outcomeTitle.lowercased()) when \(config.controlDisplayTitle.lowercased()) continues"
        case (.nextDay, .none):
            return "next-day \(config.outcomeTitle.lowercased())"
        }
    }

    private var outcomeDeltaSummary: String {
        switch config.expectedEffect {
        case .negative:
            return "\(timingAdjustedOutcomeTitle) drop"
        case .positive:
            return "\(timingAdjustedOutcomeTitle) lift"
        case .neutral:
            return "\(timingAdjustedOutcomeTitle) shift"
        }
    }

    private func summaryText(effectMagnitude: Double) -> String {
        switch (config.expectedEffect, config.timing, config.outcomeDayControlRequirement) {
        case (.negative, .sameDay, _):
            return "\(config.driverText) is associated with a \(format(effectMagnitude)) point lower \(config.outcomeTitle.lowercased()) on the same day."
        case (.positive, .sameDay, _):
            return "\(config.driverText) is associated with a \(format(effectMagnitude)) point higher \(config.outcomeTitle.lowercased()) on the same day."
        case (.negative, .nextDay, .some(.absent)):
            return "\(config.driverText) is associated with a \(format(effectMagnitude)) point lower next-day \(config.outcomeTitle.lowercased()) when \(config.controlDisplayTitle.lowercased()) stays at zero."
        case (.positive, .nextDay, .some(.absent)):
            return "\(config.driverText) is associated with a \(format(effectMagnitude)) point higher next-day \(config.outcomeTitle.lowercased()) when \(config.controlDisplayTitle.lowercased()) stays at zero."
        case (.negative, .nextDay, .some(.present)):
            return "\(config.driverText) is associated with a \(format(effectMagnitude)) point lower next-day \(config.outcomeTitle.lowercased()) when \(config.controlDisplayTitle.lowercased()) continues."
        case (.positive, .nextDay, .some(.present)):
            return "\(config.driverText) is associated with a \(format(effectMagnitude)) point higher next-day \(config.outcomeTitle.lowercased()) when \(config.controlDisplayTitle.lowercased()) continues."
        case (.negative, .nextDay, .none):
            return "\(config.driverText) is associated with a \(format(effectMagnitude)) point lower next-day \(config.outcomeTitle.lowercased())."
        case (.positive, .nextDay, .none):
            return "\(config.driverText) is associated with a \(format(effectMagnitude)) point higher next-day \(config.outcomeTitle.lowercased())."
        case (.neutral, .sameDay, _):
            return "\(config.driverText) is associated with a \(format(effectMagnitude)) point shift in \(config.outcomeTitle.lowercased()) on the same day."
        case (.neutral, .nextDay, .some(.absent)):
            return "\(config.driverText) is associated with a \(format(effectMagnitude)) point shift in next-day \(config.outcomeTitle.lowercased()) when \(config.controlDisplayTitle.lowercased()) stays at zero."
        case (.neutral, .nextDay, .some(.present)):
            return "\(config.driverText) is associated with a \(format(effectMagnitude)) point shift in next-day \(config.outcomeTitle.lowercased()) when \(config.controlDisplayTitle.lowercased()) continues."
        case (.neutral, .nextDay, .none):
            return "\(config.driverText) is associated with a \(format(effectMagnitude)) point shift in next-day \(config.outcomeTitle.lowercased())."
        }
    }

    private func deltaText(effectMagnitude: Double) -> String {
        switch config.expectedEffect {
        case .negative:
            return "-\(format(effectMagnitude)) pts"
        case .positive:
            return "+\(format(effectMagnitude)) pts"
        case .neutral:
            return "\(format(effectMagnitude)) pts"
        }
    }

    private func passesExpectedDirection(_ difference: Double) -> Bool {
        switch config.expectedEffect {
        case .negative:
            return difference < 0
        case .positive:
            return difference > 0
        case .neutral:
            return difference != 0
        }
    }

    private func formattedBound(_ value: Double) -> String {
        let roundedValue = value.rounded(.towardZero)
        if abs(value - roundedValue) < 0.01 {
            return String(Int(roundedValue))
        }

        return format(value)
    }
}

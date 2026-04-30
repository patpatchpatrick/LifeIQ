//
//  SQInsightCurrentStateAnalyzer.swift
//  BeastFitness
//
//  Created by Codex on 4/23/26.
//

import Foundation

struct SQInsightCurrentStateAnalyzer {
    private struct SignalObservation {
        let primaryValue: Double
        let secondaryValue: Double?
    }

    func analyze(
        snapshots: [SQInsightFeatureSnapshot],
        relationship: SQInsightRelationshipDefinition,
        variant: SQInsightRelationshipVariantDefinition,
        surfaceIntent: SQInsightSurfaceIntent,
        surfacingPolicy: SQInsightSurfacingPolicy
    ) -> SQInsightAnalysisResult {
        let observations = signalObservations(
            from: snapshots,
            relationship: relationship
        )

        let recentCount = relationship.recentWindowDayCount
        let baselineCount = relationship.baselineWindowDayCount
        let minimumRequired = max(relationship.minimumBucketSampleCount, 2)

        guard observations.count >= max(recentCount + baselineCount, minimumRequired + recentCount) else {
            return .readiness(.init(
                id: variant.id,
                title: "\(relationship.inputTitle) Today",
                status: .needsMoreData,
                summary: "Need more logged \(relationship.bucketUnitName) with \(relationship.inputTitle.lowercased()) data before surfacing a current-state read."
            ))
        }

        let recentValues = Array(observations.suffix(recentCount))
        let baselineValues = Array(observations.dropLast(recentCount).suffix(baselineCount))

        guard recentValues.count >= recentCount,
              baselineValues.count >= minimumRequired,
              let recentAverage = average(of: recentValues.map(\.primaryValue)),
              let baselineAverage = average(of: baselineValues.map(\.primaryValue)) else {
            return .readiness(.init(
                id: variant.id,
                title: "\(relationship.inputTitle) Today",
                status: .needsMoreData,
                summary: "Need a recent \(relationship.inputTitle.lowercased()) read plus at least \(minimumRequired) baseline \(relationship.bucketUnitName) to assess today."
            ))
        }

        let delta = recentAverage - baselineAverage
        let effectMagnitude = abs(delta)
        let usesSecondarySignal = relationship.outputSignalId != relationship.inputSignalId

        let secondaryRecentAverage: Double?
        let secondaryBaselineAverage: Double?
        let secondaryDelta: Double?
        let secondaryEffect: SQInsightEffect?
        let combinedMagnitude: Double

        if usesSecondarySignal {
            guard let recentSecondary = average(of: recentValues.compactMap(\.secondaryValue)),
                  let baselineSecondary = average(of: baselineValues.compactMap(\.secondaryValue)) else {
                return .readiness(.init(
                    id: variant.id,
                    title: "\(relationship.inputTitle) Today",
                    status: .needsMoreData,
                    summary: "Need both \(relationship.inputTitle.lowercased()) and \(relationship.outputTitle.lowercased()) data to surface this current-state read."
                ))
            }

            let candidateSecondaryDelta = recentSecondary - baselineSecondary
            let candidateSecondaryMagnitude = abs(candidateSecondaryDelta)

            guard candidateSecondaryMagnitude >= relationship.minimumEffectMagnitude else {
                return .readiness(.init(
                    id: variant.id,
                    title: "\(relationship.inputTitle) Today",
                    status: .weakSignal,
                    summary: "\(relationship.outputTitle) is still close to baseline, so the stacked current-state signal is not strong enough yet."
                ))
            }

            secondaryRecentAverage = recentSecondary
            secondaryBaselineAverage = baselineSecondary
            secondaryDelta = candidateSecondaryDelta
            secondaryEffect = directionalEffect(
                delta: candidateSecondaryDelta,
                expectedEffect: relationship.expectedEffect
            )
            combinedMagnitude = effectMagnitude + candidateSecondaryMagnitude
        } else {
            secondaryRecentAverage = nil
            secondaryBaselineAverage = nil
            secondaryDelta = nil
            secondaryEffect = nil
            combinedMagnitude = effectMagnitude
        }

        guard effectMagnitude >= relationship.minimumEffectMagnitude else {
            return .readiness(.init(
                id: variant.id,
                title: "\(relationship.inputTitle) Today",
                status: .weakSignal,
                summary: "\(relationship.inputTitle) is still close to baseline, so there is not a strong current-state signal to surface yet."
            ))
        }

        let effect = directionalEffect(
            delta: delta,
            expectedEffect: relationship.expectedEffect
        )

        guard shouldSurface(
            primaryEffect: effect,
            secondaryEffect: secondaryEffect,
            for: relationship.insightClass
        ) else {
            return .readiness(.init(
                id: variant.id,
                title: "\(relationship.inputTitle) Today",
                status: .weakSignal,
                summary: "\(relationship.inputTitle) moved, but not in the direction needed for a \(relationship.insightClass == .opportunity ? "today opportunity" : "today risk") insight."
            ))
        }

        guard shouldSurfaceCurrentStateInsight(
            relationship: relationship,
            primaryEffect: effect,
            primaryRecentAverage: recentAverage,
            secondaryEffect: secondaryEffect,
            secondaryRecentAverage: secondaryRecentAverage
        ) else {
            return .readiness(.init(
                id: variant.id,
                title: "\(relationship.inputTitle) Today",
                status: .weakSignal,
                summary: "\(relationship.inputTitle) improved versus baseline, but the current value is not strong enough to call it supportive."
            ))
        }

        let sampleCount = recentValues.count + baselineValues.count
        let confidence = SQInsightScoring.confidence(
            sampleCount: sampleCount,
            effectMagnitude: combinedMagnitude
        )
        let baseRankingScore = SQInsightScoring.rankingScore(
            sampleCount: sampleCount,
            effectMagnitude: combinedMagnitude,
            confidence: confidence
        )
        let rankingScore = surfacingPolicy.adjustedRankingScore(
            baseScore: baseRankingScore,
            relationship: relationship,
            variant: variant,
            surfaceIntent: surfaceIntent
        )

        return .insight(
            SQInsight(
                id: variant.id,
                familyKey: relationship.familyKey,
                insightClass: relationship.insightClass,
                variantPriority: variant.priority,
                inputSignalId: relationship.inputSignalId,
                outputSignalId: relationship.outputSignalId,
                recommendationFamily: relationship.recommendationFamily,
                title: currentStateTitle(
                    relationship: relationship
                ),
                summary: currentStateSummary(
                    relationship: relationship,
                    delta: delta,
                    effectMagnitude: effectMagnitude,
                    secondaryDelta: secondaryDelta
                ),
                evidenceText: evidenceText(
                    relationship: relationship,
                    recentAverage: recentAverage,
                    baselineAverage: baselineAverage,
                    secondaryRecentAverage: secondaryRecentAverage,
                    secondaryBaselineAverage: secondaryBaselineAverage,
                    baselineCount: baselineValues.count
                ),
                actionText: currentStateActionText(for: relationship),
                driverText: relationship.driverText,
                outcomeText: relationship.outcomeText,
                deltaText: currentStateDeltaText(
                    primaryDelta: delta,
                    secondaryDelta: secondaryDelta
                ),
                category: relationship.category,
                confidence: confidence,
                effect: effect,
                sampleCount: sampleCount,
                rankingScore: rankingScore
            )
        )
    }

    private func shouldSurfaceCurrentStateInsight(
        relationship: SQInsightRelationshipDefinition,
        primaryEffect: SQInsightEffect,
        primaryRecentAverage: Double,
        secondaryEffect: SQInsightEffect?,
        secondaryRecentAverage: Double?
    ) -> Bool {
        guard relationship.insightClass == .opportunity else { return true }

        guard meetsSupportiveAbsoluteThreshold(
            signalId: relationship.inputSignalId,
            effect: primaryEffect,
            recentAverage: primaryRecentAverage
        ) else {
            return false
        }

        if relationship.outputSignalId != relationship.inputSignalId,
           let secondaryEffect,
           let secondaryRecentAverage {
            return meetsSupportiveAbsoluteThreshold(
                signalId: relationship.outputSignalId,
                effect: secondaryEffect,
                recentAverage: secondaryRecentAverage
            )
        }

        return true
    }

    private func meetsSupportiveAbsoluteThreshold(
        signalId: String,
        effect: SQInsightEffect,
        recentAverage: Double
    ) -> Bool {
        guard effect == .positive else {
            return true
        }

        return SQInsightSupportiveReadinessGate.allowsSupportiveSignal(
            signalId: signalId,
            recentAverage: recentAverage
        )
    }

    private func directionalEffect(
        delta: Double,
        expectedEffect: SQInsightEffect
    ) -> SQInsightEffect {
        switch expectedEffect {
        case .positive:
            return delta >= 0 ? .positive : .negative
        case .negative:
            return delta >= 0 ? .negative : .positive
        case .neutral:
            return .neutral
        }
    }

    private func shouldSurface(
        primaryEffect: SQInsightEffect,
        secondaryEffect: SQInsightEffect?,
        for insightClass: SQInsightClass
    ) -> Bool {
        switch insightClass {
        case .opportunity:
            return primaryEffect == .positive && (secondaryEffect == nil || secondaryEffect == .positive)
        case .risk:
            return primaryEffect == .negative && (secondaryEffect == nil || secondaryEffect == .negative)
        default:
            return false
        }
    }

    private func currentStateTitle(
        relationship: SQInsightRelationshipDefinition
    ) -> String {
        let usesSecondarySignal = relationship.outputSignalId != relationship.inputSignalId
        let inputTitle = displayTitle(for: relationship.inputTitle)
        let outputTitle = displayTitle(for: relationship.outputTitle)

        switch relationship.insightClass {
        case .opportunity:
            return usesSecondarySignal
                ? "\(inputTitle) and \(outputTitle) are lining up today"
                : "\(inputTitle) is helping today"
        case .risk:
            return usesSecondarySignal
                ? "\(inputTitle) and \(outputTitle) are both under pressure today"
                : "\(inputTitle) is under pressure today"
        default:
            return "\(inputTitle) stands out today"
        }
    }

    private func displayTitle(for rawTitle: String) -> String {
        rawTitle
            .replacingOccurrences(of: "Sleep Quality", with: "Sleep")
            .replacingOccurrences(of: "Sleep Hours", with: "Sleep")
            .replacingOccurrences(of: "Workout Performance", with: "Performance")
    }

    private func currentStateSummary(
        relationship: SQInsightRelationshipDefinition,
        delta: Double,
        effectMagnitude: Double,
        secondaryDelta: Double?
    ) -> String {
        let directionText = delta >= 0 ? "above" : "below"
        let usesSecondarySignal = relationship.outputSignalId != relationship.inputSignalId

        if usesSecondarySignal, let secondaryDelta {
            let secondaryDirectionText = secondaryDelta >= 0 ? "above" : "below"

            switch relationship.insightClass {
            case .opportunity:
                return "\(relationship.inputTitle) is \(directionText) baseline and \(relationship.outputTitle.lowercased()) is \(secondaryDirectionText) baseline, which looks supportive right now."
            case .risk:
                return "\(relationship.inputTitle) is \(directionText) baseline and \(relationship.outputTitle.lowercased()) is \(secondaryDirectionText) baseline, which looks like a stacked drag today."
            default:
                break
            }
        }

        switch relationship.insightClass {
        case .opportunity:
            return "\(relationship.inputTitle) is \(directionText) baseline by \(format(effectMagnitude)), which looks supportive right now."
        case .risk:
            return "\(relationship.inputTitle) is \(directionText) baseline by \(format(effectMagnitude)), which looks like a current drag."
        default:
            return "\(relationship.inputTitle) is \(directionText) baseline by \(format(effectMagnitude))."
        }
    }

    private func currentStateActionText(
        for relationship: SQInsightRelationshipDefinition
    ) -> String {
        switch relationship.insightClass {
        case .opportunity:
            return relationship.strongActionText
        case .risk:
            return relationship.strongActionText
        default:
            return relationship.subtleActionText
        }
    }

    private func signalObservations(
        from snapshots: [SQInsightFeatureSnapshot],
        relationship: SQInsightRelationshipDefinition
    ) -> [SignalObservation] {
        snapshots.compactMap { snapshot in
            guard let primaryValue = snapshot.rawSignalValue(for: relationship.inputSignalId) else {
                return nil
            }

            let secondaryValue: Double?
            if relationship.outputSignalId != relationship.inputSignalId {
                secondaryValue = snapshot.rawSignalValue(for: relationship.outputSignalId)
                guard secondaryValue != nil else { return nil }
            } else {
                secondaryValue = nil
            }

            return .init(
                primaryValue: primaryValue,
                secondaryValue: secondaryValue
            )
        }
    }

    private func evidenceText(
        relationship: SQInsightRelationshipDefinition,
        recentAverage: Double,
        baselineAverage: Double,
        secondaryRecentAverage: Double?,
        secondaryBaselineAverage: Double?,
        baselineCount: Int
    ) -> String {
        if relationship.outputSignalId != relationship.inputSignalId,
           let secondaryRecentAverage,
           let secondaryBaselineAverage {
            return "Recent \(relationship.inputTitle.lowercased()) averaged \(format(recentAverage)) vs \(format(baselineAverage)) at baseline, while \(relationship.outputTitle.lowercased()) averaged \(format(secondaryRecentAverage)) vs \(format(secondaryBaselineAverage)) across the prior \(baselineCount) logged \(relationship.bucketUnitName)."
        }

        return "Recent \(relationship.inputTitle.lowercased()) averaged \(format(recentAverage)) vs a baseline average of \(format(baselineAverage)) across the prior \(baselineCount) logged \(relationship.bucketUnitName)."
    }

    private func currentStateDeltaText(
        primaryDelta: Double,
        secondaryDelta: Double?
    ) -> String {
        let primaryText = signedDeltaText(primaryDelta)

        guard let secondaryDelta else { return primaryText }
        return "\(primaryText) / \(signedDeltaText(secondaryDelta))"
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
}

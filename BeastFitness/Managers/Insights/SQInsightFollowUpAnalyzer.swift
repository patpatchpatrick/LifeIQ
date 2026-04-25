//
//  SQInsightFollowUpAnalyzer.swift
//  BeastFitness
//
//  Created by Codex on 4/23/26.
//

import Foundation

struct SQInsightFollowUpAnalyzer {
    private struct PairedObservation {
        let inputValue: Double
        let outputValue: Double
    }

    func analyze(
        snapshots: [SQInsightFeatureSnapshot],
        relationship: SQInsightRelationshipDefinition,
        variant: SQInsightRelationshipVariantDefinition,
        surfaceIntent: SQInsightSurfaceIntent,
        surfacingPolicy: SQInsightSurfacingPolicy
    ) -> SQInsightAnalysisResult {
        let observations = pairedObservations(
            from: snapshots,
            relationship: relationship,
            variant: variant
        )
        let recentCount = relationship.recentWindowDayCount
        let priorCount = relationship.comparisonWindowDayCount
        let minimumRequired = max(relationship.minimumBucketSampleCount, 2)

        guard observations.count >= max(recentCount + priorCount, minimumRequired * 2) else {
            return .readiness(.init(
                id: variant.id,
                title: "\(relationship.inputTitle) Follow-Up",
                status: .needsMoreData,
                summary: "Need more logged \(relationship.bucketUnitName) with both \(relationship.inputTitle.lowercased()) and \(relationship.outputTitle.lowercased()) data to measure a follow-up outcome."
            ))
        }

        let recentValues = Array(observations.suffix(recentCount))
        let priorValues = Array(observations.dropLast(recentCount).suffix(priorCount))

        guard recentValues.count >= minimumRequired,
              priorValues.count >= minimumRequired,
              let recentInput = average(of: recentValues.map(\.inputValue)),
              let priorInput = average(of: priorValues.map(\.inputValue)),
              let recentOutput = average(of: recentValues.map(\.outputValue)),
              let priorOutput = average(of: priorValues.map(\.outputValue)) else {
            return .readiness(.init(
                id: variant.id,
                title: "\(relationship.inputTitle) Follow-Up",
                status: .needsMoreData,
                summary: "Need at least \(minimumRequired) logged \(relationship.bucketUnitName) in both the recent and prior windows for a follow-up read on \(relationship.inputTitle.lowercased())."
            ))
        }

        let inputDelta = recentInput - priorInput
        let outputDelta = recentOutput - priorOutput
        let inputMagnitude = abs(inputDelta)
        let outputMagnitude = abs(outputDelta)

        guard inputMagnitude >= relationship.minimumEffectMagnitude else {
            return .readiness(.init(
                id: variant.id,
                title: "\(relationship.inputTitle) Follow-Up",
                status: .weakSignal,
                summary: "\(relationship.inputTitle) has not changed enough recently to measure a follow-up outcome yet."
            ))
        }

        let inputMovedInHelpfulDirection = helpfulInputDirection(
            delta: inputDelta,
            expectedEffect: relationship.expectedEffect
        )
        let outputImproved = outputDelta >= relationship.minimumEffectMagnitude

        guard inputMovedInHelpfulDirection, outputImproved else {
            return .readiness(.init(
                id: variant.id,
                title: "\(relationship.inputTitle) Follow-Up",
                status: .weakSignal,
                summary: "There was a recent shift in \(relationship.inputTitle.lowercased()), but \(relationship.outputTitle.lowercased()) has not improved enough yet to confirm a follow-up effect."
            ))
        }

        let sampleCount = recentValues.count + priorValues.count
        let combinedMagnitude = inputMagnitude + outputMagnitude
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

        let inputDirectionText = helpfulInputText(
            title: relationship.inputTitle,
            delta: inputDelta,
            expectedEffect: relationship.expectedEffect
        )

        return .insight(
            SQInsight(
                id: variant.id,
                familyKey: relationship.familyKey,
                insightClass: .followUp,
                variantPriority: variant.priority,
                title: "\(inputDirectionText) looks like it's paying off",
                summary: "\(inputDirectionText) recently coincided with a \(format(outputMagnitude)) point lift in \(timingAdjustedOutputTitle(for: relationship, variant: variant)).",
                evidenceText: "\(relationship.inputTitle) shifted from \(format(priorInput)) to \(format(recentInput)) while \(timingAdjustedOutputTitle(for: relationship, variant: variant)) moved from \(format(priorOutput)) to \(format(recentOutput)) across \(sampleCount) matched \(relationship.bucketUnitName).",
                actionText: followUpActionText(for: relationship),
                driverText: inputDirectionText,
                outcomeText: "Better \(relationship.outputTitle)",
                deltaText: "+\(format(outputMagnitude))",
                category: relationship.category,
                confidence: confidence,
                effect: .positive,
                sampleCount: sampleCount,
                rankingScore: rankingScore
            )
        )
    }

    private func pairedObservations(
        from snapshots: [SQInsightFeatureSnapshot],
        relationship: SQInsightRelationshipDefinition,
        variant: SQInsightRelationshipVariantDefinition
    ) -> [PairedObservation] {
        let calendar = Calendar.current

        switch variant.timing {
        case .sameDay:
            return snapshots.compactMap { snapshot in
                guard let inputValue = snapshot.rawSignalValue(for: relationship.inputSignalId),
                      let outputValue = snapshot.normalizedSignalValue(for: relationship.outputSignalId) else {
                    return nil
                }

                return .init(inputValue: inputValue, outputValue: outputValue)
            }

        case .nextDay:
            guard snapshots.count >= 2 else { return [] }
            var results = [PairedObservation]()

            for index in 0..<(snapshots.count - 1) {
                let current = snapshots[index]
                let next = snapshots[index + 1]
                let dayDelta = calendar.dateComponents([.day], from: current.date, to: next.date).day

                guard dayDelta == 1,
                      let inputValue = current.rawSignalValue(for: relationship.inputSignalId),
                      let outputValue = next.normalizedSignalValue(for: relationship.outputSignalId) else {
                    continue
                }

                results.append(.init(inputValue: inputValue, outputValue: outputValue))
            }

            return results
        }
    }

    private func helpfulInputDirection(
        delta: Double,
        expectedEffect: SQInsightEffect
    ) -> Bool {
        switch expectedEffect {
        case .negative:
            return delta < 0
        case .positive:
            return delta > 0
        case .neutral:
            return false
        }
    }

    private func helpfulInputText(
        title: String,
        delta: Double,
        expectedEffect: SQInsightEffect
    ) -> String {
        switch expectedEffect {
        case .negative:
            return delta < 0 ? "Less \(title)" : "More \(title)"
        case .positive:
            return delta > 0 ? "More \(title)" : "Less \(title)"
        case .neutral:
            return title
        }
    }

    private func timingAdjustedOutputTitle(
        for relationship: SQInsightRelationshipDefinition,
        variant: SQInsightRelationshipVariantDefinition
    ) -> String {
        switch variant.timing {
        case .sameDay:
            return relationship.outputTitle.lowercased()
        case .nextDay:
            return "next-day \(relationship.outputTitle.lowercased())"
        }
    }

    private func followUpActionText(
        for relationship: SQInsightRelationshipDefinition
    ) -> String {
        "This recent change looks promising. Keep it steady for a few more \(relationship.bucketUnitName) and see if the improvement holds."
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
}

//
//  SQInsightActionBuilder.swift
//  BeastFitness
//
//  Created by Codex on 4/23/26.
//

import Foundation

protocol SQInsightActionBuilding {
    func buildActions(
        insights: [SQInsight],
        drivers: [SQInsightDriver],
        changes: [SQInsightChange],
        surfaceIntent: SQInsightSurfaceIntent
    ) -> [SQInsightAction]
}

struct SQInsightActionBuilder: SQInsightActionBuilding {
    func buildActions(
        insights: [SQInsight],
        drivers: [SQInsightDriver],
        changes: [SQInsightChange],
        surfaceIntent: SQInsightSurfaceIntent
    ) -> [SQInsightAction] {
        let maximumCount: Int
        switch surfaceIntent {
        case .today:
            maximumCount = 1
        case .pastWeek, .pastYear:
            maximumCount = 2
        }

        var actions = [SQInsightAction]()
        var usedSummaries = Set<String>()

        for insight in insights {
            let summary = refinedActionSummary(
                for: insight,
                drivers: drivers,
                changes: changes
            )
            guard !summary.isEmpty else { continue }
            guard !usedSummaries.contains(summary) else { continue }

            let tone = actionTone(for: insight)
            let action = SQInsightAction(
                id: "action-\(insight.id)",
                title: actionTitle(for: tone, surfaceIntent: surfaceIntent),
                summary: summary,
                context: actionContext(for: insight, drivers: drivers, changes: changes),
                tone: tone,
                rankingScore: insight.rankingScore
            )

            actions.append(action)
            usedSummaries.insert(summary)

            if actions.count >= maximumCount {
                break
            }
        }

        return actions
    }

    private func refinedActionSummary(
        for insight: SQInsight,
        drivers: [SQInsightDriver],
        changes: [SQInsightChange]
    ) -> String {
        if let metadataDrivenSummary = metadataDrivenActionSummary(
            for: insight,
            drivers: drivers,
            changes: changes
        ) {
            return metadataDrivenSummary
        }

        let title = insight.title.lowercased()
        let driver = insight.driverText.lowercased()
        let outcome = insight.outcomeText.lowercased()

        if title.contains("stress") || driver.contains("stress") || title.contains("anxiety") || driver.contains("anxiety") {
            return "Keep the day lighter and protect recovery."
        }

        if title.contains("resting hr") || driver.contains("resting hr") || title.contains("resting heart") || driver.contains("resting heart") {
            return insight.effect == .positive
                ? positiveTrainingAction(for: insight)
                : "Keep strain moderate today."
        }

        if title.contains("soreness") || driver.contains("soreness") {
            return insight.effect == .positive
                ? positiveTrainingAction(for: insight)
                : "Favor recovery over intensity today."
        }

        if title.contains("mental clarity") || driver.contains("mental clarity") || title.contains("clarity") {
            return insight.effect == .positive ? "Use the focus while it holds." : "Reduce noise and protect recovery."
        }

        if title.contains("motivation") || driver.contains("motivation") {
            return insight.effect == .positive
                ? "Use the motivation for something that matters."
                : "Keep the day simple and lower friction."
        }

        if title.contains("strain") || driver.contains("strain") {
            return "Keep strain moderate."
        }

        if title.contains("sleep") || driver.contains("sleep") {
            return insight.effect == .positive
                ? positiveTrainingAction(for: insight)
                : "Protect sleep tonight."
        }

        if title.contains("alcohol") || driver.contains("alcohol") {
            return "Keep alcohol low tonight."
        }

        if title.contains("caffeine") || driver.contains("caffeine") {
            return "Keep caffeine earlier today."
        }

        if title.contains("weed") || driver.contains("weed") {
            return "Keep weed light tonight."
        }

        if title.contains("difficulty") || driver.contains("difficulty") {
            return insight.effect == .positive
                ? positiveTrainingAction(for: insight)
                : "Favor an easier session today."
        }

        if title.contains("workout") || title.contains("performance") || outcome.contains("performance") {
            return insight.effect == .positive
                ? positiveTrainingAction(for: insight)
                : "Watch strain today."
        }

        if title.contains("recovery") || title.contains("energy") || driver.contains("recovery") {
            return insight.effect == .positive
                ? positiveTrainingAction(for: insight)
                : "Keep strain moderate."
        }

        let cleaned = insight.actionText
            .replacingOccurrences(of: "This recent shift looks favorable. ", with: "")
            .replacingOccurrences(of: "Keep the pattern steady and see if it holds.", with: "Keep it steady.")
            .replacingOccurrences(of: " while it holds and see if the rest of the day follows.", with: ".")
            .replacingOccurrences(of: " while it holds.", with: ".")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let normalized = cleaned.lowercased()
        if normalized == "keep it steady." || normalized == "keep going." || normalized == "keep this going." {
            switch insight.effect {
            case .positive:
                return positiveTrainingAction(for: insight)
            case .negative:
                return "Keep strain moderate."
            case .neutral:
                return "Watch the trend today."
            }
        }

        return cleaned
    }

    private func metadataDrivenActionSummary(
        for insight: SQInsight,
        drivers: [SQInsightDriver],
        changes: [SQInsightChange]
    ) -> String? {
        guard let recommendationFamily = insight.recommendationFamily else {
            return nil
        }

        let inputSignalId = insight.inputSignalId ?? ""
        let outputSignalId = insight.outputSignalId ?? ""

        if outputSignalId == SQInsightAnalysisMetricId.workoutPerformance {
            return insight.effect == .positive
                ? positiveTrainingAction(for: insight)
                : "Keep workouts lighter today and focus on recovery tonight."
        }

        switch recommendationFamily {
        case .reduce:
            switch inputSignalId {
            case SQMetricId.alcohol:
                return "Keep alcohol low tonight."
            case SQMetricId.caffeine:
                return "Keep caffeine earlier today."
            case SQMetricId.weed:
                return "Keep weed light tonight."
            case SQMetricId.nicotine:
                return "Keep nicotine low today."
            case SQMetricId.porn:
                return "Keep the habit lighter today."
            default:
                return insight.effect == .positive
                    ? "Keep the recent change steady."
                    : "Lower the drag today."
            }

        case .increase:
            switch inputSignalId {
            case SQMetricId.sleepHours, SQMetricId.sleepQuality:
                return insight.effect == .positive
                    ? trainingReadinessAction(
                        fallbackPositive: positiveTrainingAction(for: insight),
                        fallbackCaution: moderateTrainingAction(for: insight),
                        drivers: drivers,
                        changes: changes
                    )
                    : "Protect sleep tonight."
            case SQMetricId.energy, SQMetricId.motivation:
                return insight.effect == .positive
                    ? trainingReadinessAction(
                        fallbackPositive: positiveTrainingAction(for: insight),
                        fallbackCaution: moderateTrainingAction(for: insight),
                        drivers: drivers,
                        changes: changes
                    )
                    : "Keep the day lighter today."
            case SQMetricId.mentalClarity:
                return insight.effect == .positive
                    ? "Use the focus while it holds."
                    : "Reduce noise and protect recovery."
            case SQMetricId.mood:
                return insight.effect == .positive
                    ? "Keep the day steady and simple."
                    : "Lower extra drains today."
            default:
                return insight.effect == .positive
                    ? positiveTrainingAction(for: insight)
                    : "Protect recovery today."
            }

        case .shiftEarlier:
            return inputSignalId == SQMetricId.caffeine
                ? "Keep caffeine earlier today."
                : "Shift the pattern earlier today."

        case .shiftLater:
            return "Push the pattern later and compare how the day feels."

        case .keepConsistent:
            switch inputSignalId {
            case SQMetricId.stress, SQMetricId.anxiety:
                return insight.effect == .positive
                    ? "Keep the calmer routine steady today."
                    : "Lower friction and keep the day simple."
            case SQMetricId.mood:
                return insight.effect == .positive
                    ? "Keep the routine steady today."
                    : "Protect the basics and keep the day lighter."
            case SQMetricId.mentalClarity:
                return insight.effect == .positive
                    ? "Use the focus while it lasts."
                    : "Reduce noise and keep the day simple."
            case SQMetricId.motivation:
                return insight.effect == .positive
                    ? "Use the motivation for something that matters."
                    : "Lower friction and keep the routine simple."
            default:
                return insight.effect == .positive
                    ? "Keep the routine steady today."
                    : "Keep the day simple and steady."
            }

        case .protectRecovery:
            switch inputSignalId {
            case SQMetricId.sleepHours, SQMetricId.sleepQuality, SQMetricId.energy:
                return insight.effect == .positive
                    ? trainingReadinessAction(
                        fallbackPositive: positiveTrainingAction(for: insight),
                        fallbackCaution: moderateTrainingAction(for: insight),
                        drivers: drivers,
                        changes: changes
                    )
                    : "Protect sleep tonight."
            case SQInsightAnalysisMetricId.restingHeartRate:
                return insight.effect == .positive
                    ? trainingReadinessAction(
                        fallbackPositive: positiveTrainingAction(for: insight),
                        fallbackCaution: moderateTrainingAction(for: insight),
                        drivers: drivers,
                        changes: changes
                    )
                    : "Keep strain moderate today."
            case SQMetricId.stress, SQMetricId.anxiety:
                return "Keep the day lighter and protect recovery."
            case SQMetricId.soreness, SQInsightAnalysisMetricId.workoutDifficulty:
                return "Favor recovery over intensity today."
            default:
                return insight.effect == .positive
                    ? "Use the recovery window for something that matters."
                    : "Protect recovery today."
            }

        case .moderateStrain:
            switch inputSignalId {
            case SQMetricId.energy, SQMetricId.motivation, SQMetricId.sleepHours, SQMetricId.sleepQuality:
                return insight.effect == .positive
                    ? trainingReadinessAction(
                        fallbackPositive: positiveTrainingAction(for: insight),
                        fallbackCaution: moderateTrainingAction(for: insight),
                        drivers: drivers,
                        changes: changes
                    )
                    : "Keep strain moderate today."
            case SQInsightAnalysisMetricId.restingHeartRate:
                return insight.effect == .positive
                    ? trainingReadinessAction(
                        fallbackPositive: positiveTrainingAction(for: insight),
                        fallbackCaution: moderateTrainingAction(for: insight),
                        drivers: drivers,
                        changes: changes
                    )
                    : "Keep workouts lighter today while recovery settles."
            case SQMetricId.soreness, SQInsightAnalysisMetricId.workoutDifficulty:
                return insight.effect == .positive
                    ? positiveTrainingAction(for: insight)
                    : "Favor recovery or easier work over intensity today."
            default:
                return insight.effect == .positive
                    ? positiveTrainingAction(for: insight)
                    : "Keep strain moderate today."
            }

        case .observeAndCompare:
            switch inputSignalId {
            case SQMetricId.alcohol:
                return "Keep alcohol lower and compare the next few days."
            case SQMetricId.caffeine:
                return "Keep caffeine earlier and compare the next few days."
            case SQMetricId.weed:
                return "Keep weed lighter and compare the next few days."
            case SQMetricId.nicotine:
                return "Keep nicotine lower and compare the next few days."
            case SQMetricId.sleepHours, SQMetricId.sleepQuality:
                return "Keep the sleep pattern steady and compare the next few days."
            default:
                return "Keep the change steady and compare the next few days."
            }
        }
    }

    private func positiveTrainingAction(for insight: SQInsight) -> String {
        stableOption(
            from: [
                "Push training today if you want.",
                "Go for a harder session if it fits your plan.",
                "Use this window for a strong workout.",
                "Take advantage of the momentum today.",
                "Lean into intensity while it is there."
            ],
            key: insight.id
        )
    }

    private func moderateTrainingAction(for insight: SQInsight) -> String {
        stableOption(
            from: [
                "Stick to moderate effort today.",
                "Keep the session controlled today.",
                "Stay consistent without overreaching.",
                "Do the work, but leave some margin.",
                "Keep intensity in check today."
            ],
            key: insight.id
        )
    }

    private func stableOption(from options: [String], key: String) -> String {
        guard !options.isEmpty else { return "" }

        let hash = key.unicodeScalars.reduce(UInt64(5_381)) { partialResult, scalar in
            ((partialResult << 5) &+ partialResult) &+ UInt64(scalar.value)
        }
        return options[Int(hash % UInt64(options.count))]
    }

    private func trainingReadinessAction(
        fallbackPositive: String,
        fallbackCaution: String,
        drivers: [SQInsightDriver],
        changes: [SQInsightChange]
    ) -> String {
        if hasRecentTrainingCaution(drivers: drivers, changes: changes) {
            return fallbackCaution
        }

        return fallbackPositive
    }

    private func hasRecentTrainingCaution(
        drivers: [SQInsightDriver],
        changes: [SQInsightChange]
    ) -> Bool {
        let cautionSignalIds: Set<String> = [
            SQInsightAnalysisMetricId.workoutDifficulty,
            SQInsightAnalysisMetricId.restingHeartRate,
            SQMetricId.soreness,
            SQMetricId.energy,
            SQMetricId.mood,
            SQMetricId.mentalClarity,
            SQMetricId.motivation,
            SQMetricId.stress,
            SQMetricId.anxiety
        ]

        let hasDriverCaution = drivers.contains { driver in
            cautionSignalIds.contains(driver.signalId) && driver.direction == .drag
        }

        if hasDriverCaution {
            return true
        }

        return changes.contains { change in
            cautionSignalIds.contains(change.signalId) && change.direction == .worsened
        }
    }

    private func actionTone(for insight: SQInsight) -> SQInsightActionTone {
        switch insight.insightClass {
        case .opportunity:
            return .maintain
        case .risk:
            return .caution
        case .followUp:
            return insight.effect == .positive ? .maintain : .improve
        case .trend, .baselineChange, .relationship:
            switch insight.effect {
            case .positive:
                return .maintain
            case .negative:
                return .improve
            case .neutral:
                return .caution
            }
        case .populationBenchmark, .cohort:
            return .caution
        }
    }

    private func actionTitle(
        for tone: SQInsightActionTone,
        surfaceIntent: SQInsightSurfaceIntent
    ) -> String {
        switch surfaceIntent {
        case .today:
            switch tone {
            case .maintain:
                return "Keep This Going"
            case .improve:
                return "Best Move Today"
            case .caution:
                return "Watch Today"
            }
        case .pastWeek:
            switch tone {
            case .maintain:
                return "Worth Repeating"
            case .improve:
                return "Try This Next"
            case .caution:
                return "Keep In Mind"
            }
        case .pastYear:
            switch tone {
            case .maintain:
                return "Long-Term Lever"
            case .improve:
                return "Best Lever To Improve"
            case .caution:
                return "Watch This Pattern"
            }
        }
    }

    private func actionContext(
        for insight: SQInsight,
        drivers: [SQInsightDriver],
        changes: [SQInsightChange]
    ) -> String? {
        if let driver = drivers.first(where: { driver in
            insight.driverText.localizedCaseInsensitiveContains(driver.title)
            || insight.title.localizedCaseInsensitiveContains(driver.title)
        }) {
            return driver.summary
        }

        if let change = changes.first(where: { change in
            insight.driverText.localizedCaseInsensitiveContains(change.title)
            || insight.title.localizedCaseInsensitiveContains(change.title)
        }) {
            return change.summary
        }

        return insight.summary
    }
}

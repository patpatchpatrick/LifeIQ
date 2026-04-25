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
            let summary = refinedActionSummary(for: insight)
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

    private func refinedActionSummary(for insight: SQInsight) -> String {
        let title = insight.title.lowercased()
        let driver = insight.driverText.lowercased()
        let outcome = insight.outcomeText.lowercased()

        if title.contains("strain") || driver.contains("strain") {
            return "Keep strain moderate."
        }

        if title.contains("sleep") || driver.contains("sleep") {
            return "Protect sleep tonight."
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

        if title.contains("workout") || title.contains("performance") || outcome.contains("performance") {
            return insight.effect == .positive ? "Good day to push training." : "Watch strain today."
        }

        if title.contains("recovery") || title.contains("energy") || driver.contains("recovery") {
            return insight.effect == .positive ? "Good day to push training." : "Keep strain moderate."
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
                return "Good day to push training."
            case .negative:
                return "Keep strain moderate."
            case .neutral:
                return "Watch the trend today."
            }
        }

        return cleaned
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

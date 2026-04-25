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
            let summary = insight.actionText.trimmingCharacters(in: .whitespacesAndNewlines)
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

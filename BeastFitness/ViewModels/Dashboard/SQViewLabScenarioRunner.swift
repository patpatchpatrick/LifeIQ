//
//  SQViewLabScenarioRunner.swift
//  BeastFitness
//
//  Created by Codex on 4/24/26.
//

import Foundation

struct SQViewLabScenarioRuntime {
    enum Content {
        case lifeScoreInsights(SQViewLabLifeScoreInsightsRuntime)
    }

    let scenarioId: String
    let content: Content
}

struct SQViewLabLifeScoreInsightsRuntime {
    let input: SQHealthIntelligenceInput
    let timeRange: AppTimeRange
    let insightsResult: SQInsightsResult
    let lifeScoreViewModel: SQLifeScoreViewModel
}

@MainActor
protocol SQViewLabScenarioRunning {
    func runtime(for scenario: SQViewLabController.Scenario) -> SQViewLabScenarioRuntime
}

@MainActor
struct SQViewLabScenarioRunner: SQViewLabScenarioRunning {
    private let insightsService: SQInsightsServicing
    private let lifeScoreBuilder: SQLifeScoreBuilding

    init(
        insightsService: SQInsightsServicing? = nil,
        lifeScoreBuilder: SQLifeScoreBuilding? = nil
    ) {
        self.insightsService = insightsService ?? SQInsightsService(
            surfacingMemoryStore: SQNoOpInsightSurfacingMemoryStore()
        )
        self.lifeScoreBuilder = lifeScoreBuilder ?? SQLifeScoreBuilder(
            sleepAggregationService: .init()
        )
    }

    func runtime(for scenario: SQViewLabController.Scenario) -> SQViewLabScenarioRuntime {
        switch scenario.content {
        case .lifeScoreInsights(let input):
            let insightsResult = insightsService.dashboardInsights(input: input)

            let lifeScoreViewModel = lifeScoreBuilder.buildViewModel(
                input: .init(
                    intelligenceInput: input,
                    insightsResult: insightsResult
                )
            )

            return .init(
                scenarioId: scenario.id,
                content: .lifeScoreInsights(
                    .init(
                        input: input,
                        timeRange: input.timeRange,
                        insightsResult: insightsResult,
                        lifeScoreViewModel: lifeScoreViewModel
                    )
                )
            )
        }
    }
}

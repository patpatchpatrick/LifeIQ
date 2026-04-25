//
//  SQInsightSurfacingPolicy.swift
//  BeastFitness
//
//  Created by Codex on 4/22/26.
//

import Foundation

struct SQInsightSurfacingPolicy {
    func adjustedRankingScore(
        baseScore: Double,
        relationship: SQInsightRelationshipDefinition,
        variant: SQInsightRelationshipVariantDefinition,
        surfaceIntent: SQInsightSurfaceIntent
    ) -> Double {
        baseScore + bonus(
            relationship: relationship,
            variant: variant,
            surfaceIntent: surfaceIntent
        )
    }

    private func bonus(
        relationship: SQInsightRelationshipDefinition,
        variant: SQInsightRelationshipVariantDefinition,
        surfaceIntent: SQInsightSurfaceIntent
    ) -> Double {
        switch surfaceIntent {
        case .today:
            var value = 0.0

            if relationship.category == .sleep || relationship.category == .recovery {
                value += 6
            }

            // Today should behave like a briefing, so recent/dynamic insight classes
            // outrank durable long-term relationships when both are available.
            switch relationship.insightClass {
            case .trend, .baselineChange, .opportunity, .risk:
                value += 9
            case .followUp:
                value += 7
            case .relationship:
                value += 1
            case .populationBenchmark, .cohort:
                value += 0
            }

            switch variant.timing {
            case .nextDay:
                value += 5
            case .sameDay:
                value += 2
            }

            if variant.priority == 0 {
                value += 3
            }

            return value

        case .pastWeek:
            var value = 0.0

            if relationship.category == .habits || relationship.category == .recovery {
                value += 2
            }

            // Weekly surfacing should tell a recent story, so trend/baseline-style
            // cards get favored over static relationship cards.
            switch relationship.insightClass {
            case .trend, .baselineChange, .risk, .opportunity:
                value += 7
            case .followUp:
                value += 5
            case .relationship:
                value += 2
            case .populationBenchmark, .cohort:
                value += 0
            }

            switch variant.timing {
            case .nextDay:
                value += 3
            case .sameDay:
                value += 2
            }

            return value

        case .pastYear:
            var value = 0.0

            // Yearly surfacing acts more like a personal playbook, so durable
            // relationship insights stay favored here.
            if relationship.insightClass == .relationship {
                value += 5
            }

            if relationship.insightClass == .baselineChange {
                value += 2
            }

            if variant.priority == 0 {
                value += 2
            }

            return value
        }
    }
}

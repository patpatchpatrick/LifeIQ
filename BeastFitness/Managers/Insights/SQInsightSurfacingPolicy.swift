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

            switch variant.timing {
            case .nextDay:
                value += 3
            case .sameDay:
                value += 2
            }

            return value

        case .pastYear:
            var value = 0.0

            if relationship.insightClass == .relationship {
                value += 2
            }

            if variant.priority == 0 {
                value += 2
            }

            return value
        }
    }
}

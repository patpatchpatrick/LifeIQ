//
//  SQInsightAnalysisEngine.swift
//  BeastFitness
//
//  Created by Codex on 4/22/26.
//

import Foundation

struct SQInsightAnalysisEngineOutput {
    let generatedInsights: [SQInsight]
    let readinessItems: [SQInsightReadinessItem]
}

protocol SQInsightAnalyzing {
    func analyze(
        snapshots: [SQInsightFeatureSnapshot],
        relationships: [SQInsightRelationshipDefinition],
        surfaceIntent: SQInsightSurfaceIntent
    ) -> SQInsightAnalysisEngineOutput
}

struct SQInsightAnalysisEngine: SQInsightAnalyzing {
    private let relationshipAnalyzer: SQInsightRelationshipAnalyzer
    private let surfacingPolicy: SQInsightSurfacingPolicy

    init(
        relationshipAnalyzer: SQInsightRelationshipAnalyzer = .init(),
        surfacingPolicy: SQInsightSurfacingPolicy = .init()
    ) {
        self.relationshipAnalyzer = relationshipAnalyzer
        self.surfacingPolicy = surfacingPolicy
    }

    func analyze(
        snapshots: [SQInsightFeatureSnapshot],
        relationships: [SQInsightRelationshipDefinition],
        surfaceIntent: SQInsightSurfaceIntent
    ) -> SQInsightAnalysisEngineOutput {
        let results = relationships.flatMap { relationship in
            relationship.variants.map { variant in
                relationshipAnalyzer.analyze(
                    snapshots: snapshots,
                    relationship: relationship,
                    variant: variant,
                    surfaceIntent: surfaceIntent,
                    surfacingPolicy: surfacingPolicy
                )
            }
        }

        return .init(
            generatedInsights: results.compactMap { result in
                guard case .insight(let insight) = result else { return nil }
                return insight
            },
            readinessItems: results.compactMap { result in
                guard case .readiness(let readiness) = result else { return nil }
                return readiness
            }
        )
    }
}

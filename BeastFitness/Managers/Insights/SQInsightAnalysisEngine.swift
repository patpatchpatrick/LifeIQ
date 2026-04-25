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
    private let trendAnalyzer: SQInsightTrendAnalyzer
    private let baselineAnalyzer: SQInsightBaselineAnalyzer
    private let followUpAnalyzer: SQInsightFollowUpAnalyzer
    private let currentStateAnalyzer: SQInsightCurrentStateAnalyzer
    private let surfacingPolicy: SQInsightSurfacingPolicy

    init(
        relationshipAnalyzer: SQInsightRelationshipAnalyzer = .init(),
        trendAnalyzer: SQInsightTrendAnalyzer = .init(),
        baselineAnalyzer: SQInsightBaselineAnalyzer = .init(),
        followUpAnalyzer: SQInsightFollowUpAnalyzer = .init(),
        currentStateAnalyzer: SQInsightCurrentStateAnalyzer = .init(),
        surfacingPolicy: SQInsightSurfacingPolicy = .init()
    ) {
        self.relationshipAnalyzer = relationshipAnalyzer
        self.trendAnalyzer = trendAnalyzer
        self.baselineAnalyzer = baselineAnalyzer
        self.followUpAnalyzer = followUpAnalyzer
        self.currentStateAnalyzer = currentStateAnalyzer
        self.surfacingPolicy = surfacingPolicy
    }

    func analyze(
        snapshots: [SQInsightFeatureSnapshot],
        relationships: [SQInsightRelationshipDefinition],
        surfaceIntent: SQInsightSurfaceIntent
    ) -> SQInsightAnalysisEngineOutput {
        let results = relationships
            .filter { $0.eligibleSurfaceIntents.contains(surfaceIntent) }
            .flatMap { relationship in
            relationship.variants.map { variant in
                switch relationship.analyzerFamily {
                case .metricBucketComparison:
                    relationshipAnalyzer.analyze(
                        snapshots: snapshots,
                        relationship: relationship,
                        variant: variant,
                        surfaceIntent: surfaceIntent,
                        surfacingPolicy: surfacingPolicy
                    )
                case .recentTrend:
                    trendAnalyzer.analyze(
                        snapshots: snapshots,
                        relationship: relationship,
                        variant: variant,
                        surfaceIntent: surfaceIntent,
                        surfacingPolicy: surfacingPolicy
                    )
                case .baselineDeviation:
                    baselineAnalyzer.analyze(
                        snapshots: snapshots,
                        relationship: relationship,
                        variant: variant,
                        surfaceIntent: surfaceIntent,
                        surfacingPolicy: surfacingPolicy
                    )
                case .followUpOutcome:
                    followUpAnalyzer.analyze(
                        snapshots: snapshots,
                        relationship: relationship,
                        variant: variant,
                        surfaceIntent: surfaceIntent,
                        surfacingPolicy: surfacingPolicy
                    )
                case .currentStateAssessment:
                    currentStateAnalyzer.analyze(
                        snapshots: snapshots,
                        relationship: relationship,
                        variant: variant,
                        surfaceIntent: surfaceIntent,
                        surfacingPolicy: surfacingPolicy
                    )
                }
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

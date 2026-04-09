//
//  SQInsight.swift
//  BeastFitness
//
//  Created by Codex on 4/8/26.
//

import Foundation

enum SQInsightReadinessStatus: Hashable {
    case ready
    case needsMoreData
    case weakSignal
}

struct SQInsightReadinessItem: Identifiable, Hashable {
    let id: String
    let title: String
    let status: SQInsightReadinessStatus
    let summary: String
}

struct SQInsight: Identifiable, Hashable {
    let id: String
    let familyKey: String
    let variantPriority: Int
    let title: String
    let summary: String
    let evidenceText: String
    let actionText: String
    let driverText: String
    let outcomeText: String
    let deltaText: String
    let category: SQInsightCategory
    let confidence: SQInsightConfidence
    let effect: SQInsightEffect
    let sampleCount: Int
    let rankingScore: Double

    init(
        id: String,
        familyKey: String? = nil,
        variantPriority: Int = 0,
        title: String,
        summary: String,
        evidenceText: String,
        actionText: String,
        driverText: String,
        outcomeText: String,
        deltaText: String,
        category: SQInsightCategory,
        confidence: SQInsightConfidence,
        effect: SQInsightEffect,
        sampleCount: Int,
        rankingScore: Double
    ) {
        self.id = id
        self.familyKey = familyKey ?? id
        self.variantPriority = variantPriority
        self.title = title
        self.summary = summary
        self.evidenceText = evidenceText
        self.actionText = actionText
        self.driverText = driverText
        self.outcomeText = outcomeText
        self.deltaText = deltaText
        self.category = category
        self.confidence = confidence
        self.effect = effect
        self.sampleCount = sampleCount
        self.rankingScore = rankingScore
    }
}

struct SQInsightsResult {
    let state: SQInsightDataState
    let insights: [SQInsight]
    let readinessItems: [SQInsightReadinessItem]
    let analyzedDayCount: Int
    let requiredMinimumDayCount: Int
}

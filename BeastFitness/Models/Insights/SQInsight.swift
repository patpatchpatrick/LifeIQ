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
    let insightClass: SQInsightClass
    let variantPriority: Int
    let inputSignalId: String?
    let outputSignalId: String?
    let recommendationFamily: SQInsightRecommendationFamily?
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
    let isNew: Bool

    init(
        id: String,
        familyKey: String? = nil,
        insightClass: SQInsightClass = .relationship,
        variantPriority: Int = 0,
        inputSignalId: String? = nil,
        outputSignalId: String? = nil,
        recommendationFamily: SQInsightRecommendationFamily? = nil,
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
        rankingScore: Double,
        isNew: Bool = false
    ) {
        self.id = id
        self.familyKey = familyKey ?? id
        self.insightClass = insightClass
        self.variantPriority = variantPriority
        self.inputSignalId = inputSignalId
        self.outputSignalId = outputSignalId
        self.recommendationFamily = recommendationFamily
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
        self.isNew = isNew
    }

    func withRankingScore(_ updatedRankingScore: Double) -> SQInsight {
        .init(
            id: id,
            familyKey: familyKey,
            insightClass: insightClass,
            variantPriority: variantPriority,
            inputSignalId: inputSignalId,
            outputSignalId: outputSignalId,
            recommendationFamily: recommendationFamily,
            title: title,
            summary: summary,
            evidenceText: evidenceText,
            actionText: actionText,
            driverText: driverText,
            outcomeText: outcomeText,
            deltaText: deltaText,
            category: category,
            confidence: confidence,
            effect: effect,
            sampleCount: sampleCount,
            rankingScore: updatedRankingScore,
            isNew: isNew
        )
    }

    func withIsNew(_ updatedIsNew: Bool) -> SQInsight {
        .init(
            id: id,
            familyKey: familyKey,
            insightClass: insightClass,
            variantPriority: variantPriority,
            inputSignalId: inputSignalId,
            outputSignalId: outputSignalId,
            recommendationFamily: recommendationFamily,
            title: title,
            summary: summary,
            evidenceText: evidenceText,
            actionText: actionText,
            driverText: driverText,
            outcomeText: outcomeText,
            deltaText: deltaText,
            category: category,
            confidence: confidence,
            effect: effect,
            sampleCount: sampleCount,
            rankingScore: rankingScore,
            isNew: updatedIsNew
        )
    }
}

struct SQInsightsResult {
    let state: SQInsightDataState
    let insights: [SQInsight]
    let drivers: [SQInsightDriver]
    let changes: [SQInsightChange]
    let actions: [SQInsightAction]
    let readinessItems: [SQInsightReadinessItem]
    let analyzedDayCount: Int
    let requiredMinimumDayCount: Int
}

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
}

struct SQInsightsResult {
    let state: SQInsightDataState
    let insights: [SQInsight]
    let readinessItems: [SQInsightReadinessItem]
    let analyzedDayCount: Int
    let requiredMinimumDayCount: Int
}

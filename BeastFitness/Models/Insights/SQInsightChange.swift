//
//  SQInsightChange.swift
//  BeastFitness
//
//  Created by Codex on 4/23/26.
//

import Foundation

enum SQInsightChangeDirection: Hashable {
    case improved
    case worsened
}

struct SQInsightChange: Identifiable, Hashable {
    let id: String
    let signalId: String
    let title: String
    let summary: String
    let category: SQInsightCategory
    let direction: SQInsightChangeDirection
    let recentAverage: Double
    let priorAverage: Double
    let deltaText: String
    let effectMagnitude: Double
    let rankingScore: Double
}

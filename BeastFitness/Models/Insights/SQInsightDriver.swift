//
//  SQInsightDriver.swift
//  BeastFitness
//
//  Created by Codex on 4/23/26.
//

import Foundation

enum SQInsightDriverDirection: Hashable {
    case supportive
    case drag
}

struct SQInsightDriver: Identifiable, Hashable {
    let id: String
    let signalId: String
    let title: String
    let summary: String
    let category: SQInsightCategory
    let direction: SQInsightDriverDirection
    let recentAverage: Double
    let baselineAverage: Double
    let deltaText: String
    let effectMagnitude: Double
    let rankingScore: Double
}

//
//  SQInsightAction.swift
//  BeastFitness
//
//  Created by Codex on 4/23/26.
//

import Foundation

enum SQInsightActionTone: Hashable {
    case maintain
    case improve
    case caution
}

struct SQInsightAction: Identifiable, Hashable {
    let id: String
    let title: String
    let summary: String
    let context: String?
    let tone: SQInsightActionTone
    let rankingScore: Double
}

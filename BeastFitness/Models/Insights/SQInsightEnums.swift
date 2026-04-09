//
//  SQInsightEnums.swift
//  BeastFitness
//
//  Created by Codex on 4/8/26.
//

import Foundation

enum SQInsightCategory: String, Hashable {
    case recovery = "Recovery"
    case sleep = "Sleep"
    case training = "Training"
    case habits = "Habits"

    var badgeTitle: String { rawValue }
}

enum SQInsightConfidence: String, Hashable {
    case low
    case medium
    case high

    var badgeTitle: String {
        switch self {
        case .low:
            return "Low Confidence"
        case .medium:
            return "Medium Confidence"
        case .high:
            return "High Confidence"
        }
    }
}

enum SQInsightEffect: Hashable {
    case positive
    case negative
    case neutral
}

enum SQInsightDataState: Hashable {
    case ready
    case notEnoughData
    case noPatterns
}

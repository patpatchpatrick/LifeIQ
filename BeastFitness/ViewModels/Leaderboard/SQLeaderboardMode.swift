//
//  SQLeaderboardMode.swift
//  BeastFitness
//

import HealthKit

enum SQLeaderboardMode {
    case workoutQuantity(SQQuantityType, HKWorkoutActivityType)
    case workoutScore(SQWorkoutScoreKind, HKWorkoutActivityType)
    case vo2Max

    /// Navigation/sheet title for this leaderboard.
    var title: String {
        switch self {
        case .workoutQuantity(let quantityType, _):
            return "\(quantityType.displayTitle) Leaderboard"
        case .workoutScore(let kind, let activityType):
            return "\(activityType.name) \(kind.title) Leaderboard"
        case .vo2Max:
            return "VO₂ Max Leaderboard"
        }
    }

    /// True when lower values rank higher (e.g. pace in seconds/mile).
    var isLowerBetter: Bool {
        switch self {
        case .workoutQuantity(let quantityType, _):
            return quantityType.dashboardAggregationType == .minimum
        case .workoutScore:
            return false
        case .vo2Max:
            return false
        }
    }

    /// Label shown as the chart line title.
    var chartLineTitle: String {
        switch self {
        case .workoutQuantity(let quantityType, _):
            return quantityType.displayTitle
        case .workoutScore(let kind, let activityType):
            return "\(activityType.name) \(kind.title)"
        case .vo2Max:
            return "VO₂ Max"
        }
    }

    var requiresPremium: Bool {
        switch self {
        case .workoutScore:
            return true
        case .workoutQuantity, .vo2Max:
            return false
        }
    }
}

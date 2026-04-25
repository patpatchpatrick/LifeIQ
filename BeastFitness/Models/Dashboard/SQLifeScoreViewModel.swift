//
//  SQLifeScoreViewModel.swift
//  BeastFitness
//

import Foundation

enum SQLifeScoreSignalEffect {
    case positive
    case negative
    case neutral

    var color: SQColor {
        switch self {
        case .positive:
            return .dashboardGlowMint
        case .negative:
            return .colorErrorRed
        case .neutral:
            return .dashboardTrendWarm
        }
    }
}

struct SQLifeScoreDetailItem: Identifiable {
    let id: String
    let title: String
    let valueText: String
    let summary: String
    let effect: SQLifeScoreSignalEffect
}

struct SQLifeScoreComponent: Identifiable {
    let id: String
    let title: String
    let score: Int
    let summary: String
    let weight: Double
    let detailItems: [SQLifeScoreDetailItem]
}

enum SQLifeScoreState {
    case aligned
    case steady
    case mixed
    case strained
    case calibrating

    var title: String {
        switch self {
        case .aligned:
            return "Aligned"
        case .steady:
            return "Steady"
        case .mixed:
            return "Mixed"
        case .strained:
            return "Off Track"
        case .calibrating:
            return "Calibrating"
        }
    }

    var primaryColor: SQColor {
        switch self {
        case .aligned:
            return .dashboardGlowMint
        case .steady:
            return .dashboardGlowBlue
        case .mixed:
            return .dashboardTrendWarm
        case .strained:
            return .colorErrorRed
        case .calibrating:
            return .accentNeutral4
        }
    }

    var secondaryColor: SQColor {
        switch self {
        case .aligned:
            return .dashboardGlowBlue
        case .steady:
            return .accentNeutral4
        case .mixed:
            return .accentNeutral2
        case .strained:
            return .dashboardTrendWarm
        case .calibrating:
            return .textSecondary
        }
    }

    var summary: String {
        switch self {
        case .aligned:
            return "Your recent sleep, habits, and training signals are working together."
        case .steady:
            return "You look broadly on track, with a few areas that could tighten up."
        case .mixed:
            return "Some signals are supportive, but the overall picture is uneven right now."
        case .strained:
            return "Recovery or consistency signals are slipping enough that the overall picture looks off."
        case .calibrating:
            return "There isn't enough signal yet to make this feel fully personalized."
        }
    }
}

struct SQLifeScoreViewModel {
    let score: Int?
    let state: SQLifeScoreState
    let subtitle: String
    let components: [SQLifeScoreComponent]
    let drivers: [SQInsightDriver]
    let availableWeight: Double

    static let mock = SQLifeScoreViewModel(
        score: 76,
        state: .steady,
        subtitle: "A lightweight read on how aligned your recovery, habits, and training look right now.",
        components: [],
        drivers: [],
        availableWeight: 100
    )

    var scoreText: String {
        if let score {
            return "\(score)"
        }

        return "?"
    }

    var titleText: String {
        if let score {
            return "Life Score \(score)"
        }

        return "Life Score"
    }

    var accessibilityLabel: String {
        if let score {
            return "Life Score \(score), \(state.title)"
        }

        return "Life Score, \(state.title)"
    }

    var supportiveDrivers: [SQInsightDriver] {
        drivers.filter { $0.direction == .supportive }
    }

    var dragDrivers: [SQInsightDriver] {
        drivers.filter { $0.direction == .drag }
    }
}

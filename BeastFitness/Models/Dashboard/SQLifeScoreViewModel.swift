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
    case strong
    case primed
    case balanced
    case rebounding
    case slightlyOff
    case dipping
    case underPressure
    case calibrating

    var title: String {
        switch self {
        case .strong:
            return "Strong"
        case .primed:
            return "Primed"
        case .balanced:
            return "Balanced"
        case .rebounding:
            return "Rebounding"
        case .slightlyOff:
            return "Slightly Off"
        case .dipping:
            return "Dipping"
        case .underPressure:
            return "Under Pressure"
        case .calibrating:
            return "Calibrating"
        }
    }

    var primaryColor: SQColor {
        switch self {
        case .strong:
            return .dashboardGlowMint
        case .primed, .balanced, .rebounding:
            return .dashboardGlowBlue
        case .slightlyOff, .dipping:
            return .dashboardTrendWarm
        case .underPressure:
            return .colorErrorRed
        case .calibrating:
            return .accentNeutral4
        }
    }

    var secondaryColor: SQColor {
        switch self {
        case .strong, .primed, .rebounding:
            return .dashboardGlowBlue
        case .balanced:
            return .dashboardGlowMint
        case .slightlyOff:
            return .accentNeutral2
        case .dipping:
            return .colorErrorRed
        case .underPressure:
            return .dashboardTrendWarm
        case .calibrating:
            return .textSecondary
        }
    }

    var summary: String {
        switch self {
        case .strong:
            return "Your recent sleep, recovery, and habit signals are lining up cleanly."
        case .primed:
            return "A solid recovery base is setting the day up well."
        case .balanced:
            return "The overall picture looks steady, without a strong lift or drag."
        case .rebounding:
            return "The score is recovering after a softer stretch and looks to be moving the right way."
        case .slightlyOff:
            return "The day still has enough support, but one or two signals are slipping."
        case .dipping:
            return "Recent drag is pulling the day down more than usual."
        case .underPressure:
            return "Recovery or stress signals are weighing on the day enough to show up clearly."
        case .calibrating:
            return "There isn't enough signal yet to make this feel fully personalized."
        }
    }
}

struct SQLifeScoreViewModel {
    let score: Int?
    let scoreDeltaFromPreviousDay: Int?
    let state: SQLifeScoreState
    let subtitle: String
    let refinementPromptText: String?
    let components: [SQLifeScoreComponent]
    let primaryInsight: SQInsight?
    let drivers: [SQInsightDriver]
    let changes: [SQInsightChange]
    let actions: [SQInsightAction]
    let availableWeight: Double

    static let mock = SQLifeScoreViewModel(
        score: 76,
        scoreDeltaFromPreviousDay: 2,
        state: .balanced,
        subtitle: "A lightweight read on how aligned your recovery, habits, and training look right now.",
        refinementPromptText: "Complete your morning check-in to refine today's score.",
        components: [],
        primaryInsight: .init(
            id: "mock-primary-insight",
            title: "Sleep is helping, but strain is starting to build",
            summary: "Sleep is helping, but strain is starting to build.",
            evidenceText: "",
            actionText: "Keep training moderate today.",
            driverText: "Sleep",
            outcomeText: "Recovery",
            deltaText: "+0.8",
            category: .recovery,
            confidence: .medium,
            effect: .positive,
            sampleCount: 12,
            rankingScore: 12
        ),
        drivers: [],
        changes: [],
        actions: [],
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

    var scoreDeltaText: String? {
        guard let scoreDeltaFromPreviousDay, scoreDeltaFromPreviousDay != 0 else { return nil }
        let direction = scoreDeltaFromPreviousDay > 0 ? "↑" : "↓"
        let signedValue = scoreDeltaFromPreviousDay > 0 ? "+\(scoreDeltaFromPreviousDay)" : "\(scoreDeltaFromPreviousDay)"
        return "\(direction) \(signedValue) vs yesterday"
    }
}

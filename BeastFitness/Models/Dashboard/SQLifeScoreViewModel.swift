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
            return "You're in a strong position today."
        case .primed:
            return "You're primed for a solid day."
        case .balanced:
            return "Things look steady today."
        case .rebounding:
            return "You're trending in the right direction."
        case .slightlyOff:
            return "One or two things are slightly off today."
        case .dipping:
            return "Things are slipping compared to yesterday."
        case .underPressure:
            return "The day is working against you a bit."
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
    let headlineText: String?
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
        headlineText: nil,
        primaryInsight: .init(
            id: "mock-primary-insight",
            title: "Sleep is helping, but strain is starting to build",
            summary: "Sleep is helping, but strain is starting to build.",
            evidenceText: "",
            actionText: "Keep effort moderate today.",
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

//
//  SQLeaderboardRowViewModel.swift
//  BeastFitness

import SwiftUI
import BeastFitnessCore

@Observable @MainActor
final class SQLeaderboardRowViewModel: Identifiable {
    let id: String
    let rank: Int
    let title: String
    let date: Date
    let value: Double
    let formattedScore: String
    let unitString: String
    let warningText: String?
    let state: LeaderboardStating

    var hasWarning: Bool {
        warningText != nil
    }

    var dateString: String {
        date.formattedString(with: .medium)
    }

    var scoreAttributedString: AttributedString {
        var result = AttributedString()

        var scoreText = AttributedString(formattedScore)
        scoreText.font = SQFont(type: .bodySmallSemiBold).font
        scoreText.foregroundColor = SQColor.textPrimary.color
        result.append(scoreText)

        if !unitString.isEmpty {
            var unitText = AttributedString(" " + unitString)
            unitText.font = SQFont(type: .bodyExtraSmall).font
            unitText.foregroundColor = SQColor.textSecondary.color
            result.append(unitText)
        }

        return result
    }

    init(
        id: String,
        rank: Int,
        title: String,
        date: Date,
        value: Double,
        formattedScore: String,
        unitString: String,
        warningText: String? = nil,
        state: LeaderboardStating
    ) {
        self.id = id
        self.rank = rank
        self.title = title
        self.date = date
        self.value = value
        self.formattedScore = formattedScore
        self.unitString = unitString
        self.warningText = warningText
        self.state = state
    }

    func warningTapped() {
        guard let warningText else { return }
        state.hub.alertEvents.send(
            .present(.init(
                title: "Data Accuracy Notice",
                subtitle: warningText,
                primary: .ok))
        )
    }
}

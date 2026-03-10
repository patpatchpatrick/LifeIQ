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
    let workout: (any SQWorkoutSessionable)?

    var isNavigable: Bool { workout != nil }

    /// Percentile rank (0.0 = worst, 1.0 = best) relative to all-time entries.
    /// Nil if insufficient historical data.
    let percentileRank: Double?

    var hasWarning: Bool {
        warningText != nil
    }

    var dateString: String {
        let formatted = date.formattedString(with: .medium)
        let relative = relativeTimeString(from: date)
        return "\(formatted) - \(relative)"
    }

    private func relativeTimeString(from date: Date) -> String {
        let calendar = Calendar.current
        let now = Date()
        let components = calendar.dateComponents([.year, .month, .day], from: date, to: now)

        let years = components.year ?? 0
        let months = components.month ?? 0
        let days = components.day ?? 0

        if years > 0 {
            return years == 1 ? "1 year ago" : "\(years) years ago"
        } else if months > 0 {
            return months == 1 ? "1 month ago" : "\(months) months ago"
        } else if days > 0 {
            return days == 1 ? "1 day ago" : "\(days) days ago"
        } else {
            return "Today"
        }
    }

    /// "Top X%" string based on percentile rank. Nil if insufficient data.
    var percentileString: String? {
        guard let rank = percentileRank else { return nil }
        let topPercent = Int((1.0 - rank) * 100)
        return "Top \(topPercent)%"
    }

    /// Color interpolated from green (top) through neutral (middle) to red (bottom).
    var percentileColor: SQColor {
        guard let rank = percentileRank else { return .textSecondary }
        let percent = (rank - 0.5) * 2.0
        return .colorGreenRed(percent: percent)
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
        percentileRank: Double?,
        workout: (any SQWorkoutSessionable)? = nil
    ) {
        self.id = id
        self.rank = rank
        self.title = title
        self.date = date
        self.value = value
        self.formattedScore = formattedScore
        self.unitString = unitString
        self.warningText = warningText
        self.percentileRank = percentileRank
        self.workout = workout
    }

    func warningTapped() {
        guard let warningText else { return }
        SQAppState.shared.hub.alertEvents.send(
            .present(.init(
                title: "Data Accuracy Notice",
                subtitle: warningText,
                primary: .ok))
        )
    }
}

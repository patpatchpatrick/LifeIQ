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

    /// The rank of this entry among all-time entries for the same metric/activity type.
    let allTimeRank: Int
    /// Total number of all-time entries for the same metric/activity type.
    let allTimeTotal: Int

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

    /// "Top X%" string based on all-time rank. Nil if there is only one all-time entry.
    var percentileString: String? {
        guard allTimeTotal > 1 else { return nil }
        let pct = Int(ceil(Double(allTimeRank) / Double(allTimeTotal) * 100))
        return "Top \(max(1, min(100, pct)))%"
    }

    /// Color interpolated from green (rank 1) through neutral (middle) to red (last rank).
    /// Uses colorGreenRed on a -1…+1 scale: +1 = full green, 0 = neutral, -1 = full red.
    var percentileColor: SQColor {
        guard allTimeTotal > 1 else { return .textSecondary }
        let percent = 1.0 - 2.0 * Double(allTimeRank) / Double(allTimeTotal)
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
        allTimeRank: Int,
        allTimeTotal: Int,
    ) {
        self.id = id
        self.rank = rank
        self.title = title
        self.date = date
        self.value = value
        self.formattedScore = formattedScore
        self.unitString = unitString
        self.warningText = warningText
        self.allTimeRank = allTimeRank
        self.allTimeTotal = allTimeTotal
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

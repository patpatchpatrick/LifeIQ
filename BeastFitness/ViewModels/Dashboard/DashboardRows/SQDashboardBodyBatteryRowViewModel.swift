//
//  SQDashboardBodyBatteryRowViewModel.swift
//  BeastFitness
//

import Foundation

@Observable @MainActor
final class SQDashboardBodyBatteryRowViewModel: SQDashboardRowViewModel {
    struct Driver: Identifiable {
        let id = UUID()
        let title: String
        let valueText: String
        let detailText: String
        let tone: SQDashboardTrendTone
        let symbol: SQImageSymbol?
    }

    let score: Int
    let statusTitle: String
    let statusTone: SQDashboardTrendTone
    let headline: String
    let summary: String
    let drivers: [Driver]
    let footer: String

    init(
        score: Int,
        statusTitle: String,
        statusTone: SQDashboardTrendTone,
        headline: String,
        summary: String,
        drivers: [Driver],
        footer: String
    ) {
        self.score = score
        self.statusTitle = statusTitle
        self.statusTone = statusTone
        self.headline = headline
        self.summary = summary
        self.drivers = drivers
        self.footer = footer

        super.init(rowId: .bodyBattery, rowType: .bodyBattery)
    }
}

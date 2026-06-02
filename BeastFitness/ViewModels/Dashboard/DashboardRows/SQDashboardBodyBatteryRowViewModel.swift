//
//  SQDashboardBodyBatteryRowViewModel.swift
//  BeastFitness
//

import Foundation

@Observable @MainActor
final class SQDashboardBodyBatteryRowViewModel: SQDashboardRowViewModel {
    struct DefinitionLine: Identifiable, Hashable {
        let id: String
        let valueText: String
        let summaryText: String
        let weightText: String?
    }

    struct Driver: Identifiable {
        let id = UUID()
        let title: String
        let valueText: String
        let detailText: String
        let attributedDetailText: AttributedString?
        let definitionLines: [DefinitionLine]
        let tone: SQDashboardTrendTone
        let symbol: SQImageSymbol?
        let alert: SQAlertViewModel?

        init(
            title: String,
            valueText: String,
            detailText: String,
            attributedDetailText: AttributedString?,
            definitionLines: [DefinitionLine] = [],
            tone: SQDashboardTrendTone,
            symbol: SQImageSymbol?,
            alert: SQAlertViewModel?
        ) {
            self.title = title
            self.valueText = valueText
            self.detailText = detailText
            self.attributedDetailText = attributedDetailText
            self.definitionLines = definitionLines
            self.tone = tone
            self.symbol = symbol
            self.alert = alert
        }
    }

    let score: Int?
    let statusTitle: String
    let statusTone: SQDashboardTrendTone
    let headline: String
    let summary: String
    let drivers: [Driver]
    let trendDelta: SQDashboardTrendDeltaViewModel?
    let formulaAlert: SQAlertViewModel
    let dataQualityWarning: String?
    let footer: String

    init(
        score: Int?,
        statusTitle: String,
        statusTone: SQDashboardTrendTone,
        headline: String,
        summary: String,
        drivers: [Driver],
        trendDelta: SQDashboardTrendDeltaViewModel? = nil,
        formulaAlert: SQAlertViewModel,
        dataQualityWarning: String? = nil,
        footer: String
    ) {
        self.score = score
        self.statusTitle = statusTitle
        self.statusTone = statusTone
        self.headline = headline
        self.summary = summary
        self.drivers = drivers
        self.trendDelta = trendDelta
        self.formulaAlert = formulaAlert
        self.dataQualityWarning = dataQualityWarning
        self.footer = footer

        super.init(rowId: .bodyBattery, rowType: .bodyBattery)
    }
}

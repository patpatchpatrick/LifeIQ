//
//  SQDashboardRowViewModel.swift
//  BeastFitness
//
//  Created by Patrick Doyle on 11/12/25.
//

import Foundation

enum SQDashboardRowType {
    case bodyBattery
    case metricStats
    case metricPerformance
    case workoutTotals
    case activityList
    case sleepScore
    case sleepPhaseTimeline
    case sleepSummary
}

enum SQDashboardRowIdentifier {
    case bodyBattery
    case metricStats
    case metricPerformance
    case workoutTotals
    case activityList
    case sleepScore
    case sleepPhaseTimeline
    case sleepSummary
}

class SQDashboardRowViewModel: Identifiable {
    var id = UUID()
    let rowId: SQDashboardRowIdentifier
    let rowType: SQDashboardRowType
    
    init(rowId: SQDashboardRowIdentifier, rowType: SQDashboardRowType) {
        self.rowId = rowId
        self.rowType = rowType
    }
}

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

@Observable @MainActor
final class SQDashboardSectionViewModel: Identifiable {
    let id = UUID()
    let title: String?
    let rows: [SQDashboardRowViewModel]
    
    var isExpanded: Bool = true
    func toggleExpanded() {
        isExpanded.toggle()
    }
    
    init(title: String? = nil, rows: [SQDashboardRowViewModel]) {
        self.title = title
        self.rows = rows
    }
}

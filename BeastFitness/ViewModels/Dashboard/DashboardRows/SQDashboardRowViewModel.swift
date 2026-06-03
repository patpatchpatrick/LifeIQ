//
//  SQDashboardRowViewModel.swift
//  BeastFitness
//
//  Created by Patrick Doyle on 11/12/25.
//

import Foundation

enum SQDashboardRowType {
    case helperNote
    case bodyBattery
    case heartSummary
    case insight
    case insightExplorer
    case insightChange
    case insightAction
    case metricStats
    case metricPerformance
    case workoutPremiumInsights
    case workoutTotals
    case activityList
    case sleepScore
    case sleepDuration
    case sleepPhaseTimeline
    case sleepSummary
}

enum SQDashboardRowIdentifier {
    case helperNote
    case bodyBattery
    case heartSummary
    case insight
    case insightExplorer
    case insightChange
    case insightAction
    case metricStats
    case metricPerformance
    case workoutPremiumInsights
    case workoutTotals
    case activityList
    case sleepScore
    case sleepDuration
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

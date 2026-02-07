//
//  SQDashboardRowViewModel.swift
//  BeastFitness
//
//  Created by Patrick Doyle on 11/12/25.
//

import Foundation

enum SQDashboardRowType {
    case metricStats
    case performanceStats
    case workoutTotals
    case activityList
    
    case totalsStats
    case activityStats
    case workoutSummary
    case checkInSummary
    case dailyCheckInStats
}

enum SQDashboardRowIdentifier {
    case metricStats
    case workoutTotals
    case activityList
    
    case motiviationalQuote
    case dailyCheckInStats
    case dailyPerformance
    case dailySummary
    case weeklySummary
    case yearlySummary
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

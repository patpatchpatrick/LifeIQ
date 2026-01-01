//
//  SQDashboardRowViewModel.swift
//  BeastFitness
//
//  Created by Patrick Doyle on 11/12/25.
//

import Foundation

enum SQDashboardRowType {
    case text
    case workoutSummary
}

enum SQDashboardRowIdentifier {
    case motiviationalQuote
    case dailySummary
    case weeklySummary
    case yearlySummary
}

class SQDashboardRowViewModel: Identifiable {
    let id = UUID()
    let rowId: SQDashboardRowIdentifier
    let rowType: SQDashboardRowType
    
    init(rowId: SQDashboardRowIdentifier, rowType: SQDashboardRowType) {
        self.rowId = rowId
        self.rowType = rowType
    }
}

//
//  SQDashboardRowViewModel.swift
//  BeastFitness
//
//  Created by Patrick Doyle on 11/12/25.
//

import Foundation

enum SQDashboardRowType {
    case text
}

class SQDashboardRowViewModel: Identifiable {
    let id = UUID()
    let rowType: SQDashboardRowType
    
    init(rowType: SQDashboardRowType) {
        self.rowType = rowType
    }
}

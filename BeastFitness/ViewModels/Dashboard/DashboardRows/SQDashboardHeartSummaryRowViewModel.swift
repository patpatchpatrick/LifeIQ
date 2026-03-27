//
//  SQDashboardHeartSummaryRowViewModel.swift
//  BeastFitness
//

import Foundation

@Observable @MainActor
final class SQDashboardHeartSummaryRowViewModel: SQDashboardRowViewModel {
    struct Item: Identifiable {
        let id: String
        let title: String
        let value: String
        let unit: String
        let detail: String
    }

    let items: [Item]

    init(items: [Item]) {
        self.items = items
        super.init(rowId: .heartSummary, rowType: .heartSummary)
    }
}

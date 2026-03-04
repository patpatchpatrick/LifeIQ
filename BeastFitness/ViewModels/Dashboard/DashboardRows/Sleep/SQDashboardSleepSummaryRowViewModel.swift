//
//  SQDashboardSleepSummaryRowViewModel.swift
//  BeastFitness
//

import Foundation

@Observable @MainActor
final class SQDashboardSleepSummaryRowViewModel: SQDashboardRowViewModel {
    struct Item: Identifiable {
        let id: String
        let title: String
        let value: String
    }

    let items: [Item]

    init(items: [Item]) {
        self.items = items
        super.init(rowId: .sleepSummary, rowType: .sleepSummary)
    }
}

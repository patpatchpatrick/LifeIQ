//
//  SQDashboardSleepSummaryRowViewModel.swift
//  BeastFitness
//

import Foundation
import SwiftUI

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

@Observable @MainActor
final class SQDashboardSleepDurationRowViewModel: SQDashboardRowViewModel {
    struct Bar: Identifiable {
        let id: String
        let label: String
        let focusTitle: String
        let valueHours: Double
        let color: Color
    }

    let bars: [Bar]
    let averageDurationHours: Double
    let averageLabel: String
    let barSpacing: CGFloat
    let minimumBarWidth: CGFloat
    let maximumBarWidth: CGFloat?

    init(
        bars: [Bar],
        averageDurationHours: Double,
        averageLabel: String,
        barSpacing: CGFloat,
        minimumBarWidth: CGFloat,
        maximumBarWidth: CGFloat?
    ) {
        self.bars = bars
        self.averageDurationHours = averageDurationHours
        self.averageLabel = averageLabel
        self.barSpacing = barSpacing
        self.minimumBarWidth = minimumBarWidth
        self.maximumBarWidth = maximumBarWidth
        super.init(rowId: .sleepDuration, rowType: .sleepDuration)
    }
}

//
//  SQDashboardDailyCheckInRowViewModel.swift
//  BeastFitness
//
//  Created by Patrick Doyle on 12/4/25.
//

import SwiftUI
import SwiftData

@Observable @MainActor
final class SQDashboardDailyCheckInRowViewModel: SQDashboardRowViewModel {
    let callToAction: SQCallToActionViewModel?
    let context: ModelContext
    let canEditDailyStats: Bool
    let metricChips: [SQMetricChip.Model]?

    init(dailyCheckInStats: SQDailyCheckInStats?, context: ModelContext) {
        self.context = context

        if let dailyCheckInStats {
            canEditDailyStats = true
            callToAction = nil
            metricChips = SQMetricChip.Model.chips(from: dailyCheckInStats)
        } else {
            canEditDailyStats = false
            metricChips = nil
            callToAction = .init(
                title: "Complete daily check-in",
                /// Don't use weak self here; controller can be temporary.
                onTap: {
                    Task { await SQDashboardController.default.displayDailyCheckInSheet(for: context) }
                }
            )
        }

        super.init(rowId: .dailyCheckInStats, rowType: .dailyCheckInStats)
    }

    func editDailyCheckInStats() async {
        await SQDashboardController.default.displayDailyCheckInSheet(for: context)
    }
}

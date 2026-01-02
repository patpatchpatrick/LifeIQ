//
//  SQDashboardPerformanceRowViewModel.swift
//  BeastFitness
//
//  Created by Patrick Doyle on 1/2/26.
//

import SwiftUI

@Observable @MainActor
final class SQDashboardDailyPerformanceRowViewModel: SQDashboardRowViewModel {
    let metricChipModel: SQMetricChip.Model

    init(latestVO2Max: SQVO2MaxSample) {
        self.metricChipModel = .vo2MaxChip(value: latestVO2Max.value, lastUpdatedText: nil)

        super.init(rowId: .dailyPerformance, rowType: .performance)
    }
}

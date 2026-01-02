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
            callToAction = .init(
                title: "Complete daily check-in",
                /// It's important to not use weak self here.  because the dashboard controller could be deallocated if it's being initialize temporarily to trigger an action
                onTap: {
                    Task { await SQDashboardController.default.displayDailyCheckInSheet(for: context) }
                })
            metricChips = nil
        }
        
        super.init(rowId: .dailySummary, rowType: .dailyCheckInStats)
    }
    
    func editDailyCheckInStats() async {
        await SQDashboardController.default.displayDailyCheckInSheet(for: context)
    }
}

fileprivate extension SQMetricChip.Model {
    
    static func chips(
        from stats: SQDailyCheckInStats
    ) -> [SQMetricChip.Model] {
        
        [
            .init(
                id: "mood",
                title: "Mood",
                systemImage: "face.smiling",
                value: stats.moodScore.map(Double.init),
                maxValue: 10
            ),
            
            .init(
                id: "energy",
                title: "Energy",
                systemImage: "bolt.fill",
                value: stats.energyScore.map(Double.init),
                maxValue: 10
            ),
            
            .init(
                id: "clarity",
                title: "Clarity",
                systemImage: "brain.head.profile",
                value: stats.mentalClarityScore.map(Double.init),
                maxValue: 10
            ),
            
            .init(
                id: "soreness",
                title: "Soreness",
                systemImage: "figure.strengthtraining.traditional",
                value: stats.sorenessScore.map(Double.init),
                maxValue: 10
            ),
            
            .init(
                id: "sleep",
                title: "Sleep",
                systemImage: "moon.stars.fill",
                value: stats.sleepHours.map {
                    SQDailyCheckInStats.normalizedSleepScore(hours: $0)
                },
                maxValue: 10
            )
        ]
    }
}

fileprivate extension SQDailyCheckInStats {
    /// Converts sleep hours into a 0–10 visual score.
    /// 0–4h → 0–3
    /// 6–8h → 7–10
    /// 9h+ caps at 10
    static func normalizedSleepScore(hours: Float) -> Double {
        let clamped = max(0, min(hours, 10))
        
        switch clamped {
        case 0..<4:
            return Double(clamped / 4 * 3)       // poor sleep
        case 4..<6:
            return Double(3 + (clamped - 4) * 2) // 3–7
        case 6..<8:
            return Double(7 + (clamped - 6) * 1.5) // 7–10
        default:
            return 10
        }
    }
}

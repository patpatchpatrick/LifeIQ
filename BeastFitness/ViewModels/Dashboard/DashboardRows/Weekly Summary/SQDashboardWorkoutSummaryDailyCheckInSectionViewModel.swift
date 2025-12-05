//
//  SQDashboardWorkoutSummaryDailyCheckInSectionViewModel.swift
//  BeastFitness
//
//  Created by Patrick Doyle on 12/4/25.
//

import SwiftUI

@Observable @MainActor
final class SQDashboardWorkoutSummaryDailyCheckInSectionViewModel {
    let callToAction: SQCallToActionViewModel?
    let dailyCheckInSummaryConfig: DailyCheckInStatsSummaryConfig?
    
    init(callToAction: SQCallToActionViewModel? = nil, dailyCheckInSummaryConfig: DailyCheckInStatsSummaryConfig? = nil) {
        self.callToAction = callToAction
        self.dailyCheckInSummaryConfig = dailyCheckInSummaryConfig
    }
    
    struct DailyCheckInStatsSummaryConfig {
        let title: String
        let subtitle: String
        let icon: SQImageSymbol?
        let onTap: (() -> Void)?
        
        init(title: String, subtitle: String, icon: SQImageSymbol? = nil, onTap: (() -> Void)? = nil) {
            self.title = title
            self.subtitle = subtitle
            self.icon = icon
            self.onTap = onTap
        }
    }
}

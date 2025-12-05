//
//  SQDashboardWorkoutSummaryRowTotalsSection.swift
//  BeastFitness
//
//  Created by Patrick Doyle on 11/13/25.
//

import SwiftUI

struct SQDashboardWorkoutSummaryTotalsSection: View {
    @Bindable var viewModel: SQDashboardWorkoutSummaryTotalsSectionViewModel
    
    var totalValuesAndTrendsStack: some View {
        VStack(alignment: .leading, spacing: .SQSpace.l) {
            ForEach(viewModel.totalValuesAndTrends) { valueAndTrend in
                HStack(alignment: .center, spacing: .SQSpace.m) {
                    SQDashboardWorkoutStatView(attributedTitle: valueAndTrend.value)
                    Text(valueAndTrend.trend)
                }
            }
        }
    }
    
    @ViewBuilder
    func checkInStatsSummaryView(for checkInStatsSummaryConfig:  SQDashboardWorkoutSummaryRowConfig.DailyCheckInStatsSummaryConfig) -> some View {
        VStack(alignment: .leading, spacing: .SQSpace.m) {
            HStack(alignment: .center, spacing: .SQSpace.m) {
                Text("\(checkInStatsSummaryConfig.title)")
                    .sqFont(.bodyBold)
                    .foregroundColor(SQColor.textPrimary.color)
                
                if let icon = checkInStatsSummaryConfig.icon {
                    SQImageView(image: .init(symbol: icon, symbolStyle: .colorWithFont(.accent(1), font: .body)))
                        .frame(width: 20)
                }
            }
            
            Text(checkInStatsSummaryConfig.subtitle)
               .sqFont(.body)
               .foregroundColor(SQColor.textSecondary.color)
               .multilineTextAlignment(.leading)
        }
    }
    
    var mainStack: some View {
        VStack(alignment: .leading, spacing: 0) {
            
            SQDashboardView.cardTitle(title: viewModel.sectionTitle)
                .padding(.bottom, SQDashboardView.uiConfig.cardInnerTitleBottomPadding)
            
            if let callToActionViewModel = viewModel.callToActionViewModel {
                SQCallToAction(viewModel: callToActionViewModel)
                    .padding(.bottom, SQDashboardView.uiConfig.cardInnerTitleBottomPadding)
            }
            
            if let checkInStatsSummaryConfig = viewModel.checkInStatsSummaryConfig {
                if let onTap = checkInStatsSummaryConfig.onTap {
                    Button(
                        action: {
                            print("PTD On Tap")
                            onTap()
                        },
                        label: { checkInStatsSummaryView(for: checkInStatsSummaryConfig) })
                        .padding(.bottom, SQDashboardView.uiConfig.cardInnerTitleBottomPadding)
                } else {
                    checkInStatsSummaryView(for: checkInStatsSummaryConfig)
                        .padding(.bottom, SQDashboardView.uiConfig.cardInnerTitleBottomPadding)
                }
            }

            
            totalValuesAndTrendsStack
        }
    }
    
    var body: some View {
        mainStack
    }
}

#Preview {
    SQDashboardWorkoutSummaryTotalsSection(viewModel: .init(config: .mock, workouts: .mock, priorWorkouts: .mock))
        .preferredColorScheme(.dark)
}

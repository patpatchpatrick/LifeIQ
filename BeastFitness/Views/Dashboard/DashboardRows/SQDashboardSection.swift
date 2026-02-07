//
//  SQDashboardSection.swift
//  BeastFitness
//
//  Created by Patrick Doyle on 1/1/26.
//

import SwiftUI

struct SQDashboardSection: View {
    @Bindable var viewModel: SQDashboardSectionViewModel
    
    var sectionContent: some View {
        ForEach(viewModel.rows) { rowViewModel in
            switch rowViewModel.rowType {
            case .metricStats, .workoutTotals, .activityList:
                // TODO: Implement metric stats row view
                EmptyView()

            case .performanceStats:
                EmptyView()

            case .totalsStats:
                // TODO: Implement totals stats row view
                EmptyView()

            case .activityStats, .dailyCheckInStats:
                // TODO: Implement activity stats row view
                EmptyView()

            case .workoutSummary:
                if let weekSummaryViewModel = rowViewModel as? SQDashboardWorkoutSummaryRowViewModel, !weekSummaryViewModel.isEmpty {
                    SQDashboardWorkoutSummaryRow(
                        viewModel: weekSummaryViewModel)
                }

            case .checkInSummary:
                if let dailyCheckInRowViewModel = rowViewModel as? SQDashboardDailyCheckInRowViewModel {
                    SQDashboardWorkoutSummaryDailyCheckInRow(viewModel: dailyCheckInRowViewModel)
                }
            }
        }
    }
    
    var collapsibleSectionContent: some View {
        sectionContent
            .padding(.horizontal, SQDashboardView.uiConfig.sectionHorizPadding)
            .frame(maxHeight: viewModel.isExpanded ? .infinity : 0, alignment: .top)
            .opacity(viewModel.isExpanded ? 1 : 0)
            .clipped()
            .padding(.bottom, viewModel.isExpanded ? .SQSpace.xxl : 0)
            .animation(.spring(response: 0.28, dampingFraction: 0.92), value: viewModel.isExpanded)
    }
    
    var body: some View {
        if let title = viewModel.title {
            Section(header: header(for: title)) {
                collapsibleSectionContent
            }
        } else {
            collapsibleSectionContent
        }
    }
    
    private func header(for title: String) -> some View {
        Button {
            withAnimation(.spring(response: 0.28, dampingFraction: 0.92)) {
                viewModel.toggleExpanded()
            }
        } label: {
            HStack(spacing: .SQSpace.m) {
                SQDashboardView.sectionTitle(title: title)
                Spacer()
                Image(systemName: SQImageSymbol.chevronDown.rawValue)
                    .rotationEffect(.degrees(viewModel.isExpanded ? 0 : -90))
                    .animation(.spring(response: 0.28, dampingFraction: 0.92), value: viewModel.isExpanded)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.horizontal, SQDashboardView.uiConfig.sectionHorizPadding)
    }
}

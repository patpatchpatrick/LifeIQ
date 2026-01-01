//
//  SQDashboardWorkoutSummaryRow.swift
//  BeastFitness
//
//  Created by Patrick Doyle on 11/13/25.
//

import SwiftUI

struct SQDashboardWorkoutSummaryRow: View {
    @Bindable var viewModel: SQDashboardWorkoutSummaryRowViewModel

    private var cardBody: some View {
        LazyVStack(alignment: .leading, spacing: 0) {

            if let dailyCheckInSummarySectionViewModel = viewModel.dailyCheckInSummarySectionViewModel {
                SQDashboardWorkoutSummaryDailyCheckInSection(viewModel: dailyCheckInSummarySectionViewModel)
            }

            if let totalsSection = viewModel.totalsSection {
                SQDashboardWorkoutSummaryTotalsSection(viewModel: totalsSection)
                    .padding(.bottom, SQDashboardView.uiConfig.cardSectionSpacing)
            }

            if let workoutsSection = viewModel.workoutsSection {
                SQDashboardWorkoutSummaryWorkoutsSection(viewModel: workoutsSection)
            }
        }
    }

    private var header: some View {
        Button {
            withAnimation(.spring(response: 0.28, dampingFraction: 0.92)) {
                viewModel.toggleExpanded()
            }
        } label: {
            HStack(spacing: .SQSpace.m) {
                SQDashboardView.sectionTitle(title: viewModel.sectionTitle)

                Spacer()

                Image(systemName: "chevron.down")
                    .rotationEffect(.degrees(viewModel.isExpanded ? 0 : -90))
                    .animation(.spring(response: 0.28, dampingFraction: 0.92), value: viewModel.isExpanded)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(viewModel.isExpanded ? "Collapse section" : "Expand section")
    }

    var body: some View {
        Section(header: header) {
            if viewModel.isExpanded {
                SQDashboardView.card { cardBody }
                    .padding(.bottom, .SQSpace.xxl)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(.horizontal, SQDashboardView.uiConfig.sectionHorizPadding)
    }
}

#Preview {
    SQDashboardWorkoutSummaryRow(viewModel: .init(rowId: .daily, config: .mock, workouts: .mock, priorWorkouts: .mock))
        .preferredColorScheme(.dark)
}

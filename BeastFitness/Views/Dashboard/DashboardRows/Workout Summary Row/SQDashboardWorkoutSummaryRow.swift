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
            if let vm = viewModel.dailyCheckInSummarySectionViewModel {
                SQDashboardWorkoutSummaryDailyCheckInSection(viewModel: vm)
            }
            if let totals = viewModel.totalsSection {
                SQDashboardWorkoutSummaryTotalsSection(viewModel: totals)
                    .padding(.bottom, SQDashboardView.uiConfig.cardSectionSpacing)
            }
            if let workouts = viewModel.workoutsSection {
                SQDashboardWorkoutSummaryWorkoutsSection(viewModel: workouts)
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
    }

    var body: some View {
        Section(header: header) {
            SQDashboardView.card { cardBody }
                // This is the key: we always keep the view in the tree,
                // but “clip” it when collapsed so it collapses from the header edge.
                .frame(maxHeight: viewModel.isExpanded ? .infinity : 0, alignment: .top)
                .opacity(viewModel.isExpanded ? 1 : 0)
                .clipped()
                .padding(.bottom, viewModel.isExpanded ? .SQSpace.xxl : 0)
                .animation(.spring(response: 0.28, dampingFraction: 0.92), value: viewModel.isExpanded)
        }
        .padding(.horizontal, SQDashboardView.uiConfig.sectionHorizPadding)
    }
}


#Preview {
    SQDashboardWorkoutSummaryRow(viewModel: .init(rowId: .daily, config: .mock, workouts: .mock, priorWorkouts: .mock))
        .preferredColorScheme(.dark)
}

//
//  SQDashboardWorkoutSummaryDailyCheckInSection.swift
//  BeastFitness
//
//  Created by Patrick Doyle on 12/4/25.
//

import SwiftUI

struct SQDashboardWorkoutSummaryDailyCheckInRow: View {
    @Bindable var viewModel: SQDashboardDailyCheckInRowViewModel

    var editButton: some View {
        Button(action: {
            Task { await viewModel.editDailyCheckInStats() }
        }) {
            SQImageView(image: .init(symbol: .edit, symbolStyle: .colorWithFont(.textPrimary, font: .bodyExtraSmall)))
                .frame(width: 14)
        }
        .buttonStyle(.plain)
    }

    var stateSection: some View {
        LazyVStack(alignment: .leading, spacing: 0) {
            SQCollapsibleSectionHeader(
                title: "State",
                isExpanded: viewModel.isStateExpanded,
                action: { viewModel.toggleStateExpanded() }
            ) {
                if viewModel.canEditDailyStats {
                    editButton
                }
            }

            if viewModel.isStateExpanded {
                if let callToActionViewModel = viewModel.callToAction {
                    SQCallToAction(viewModel: callToActionViewModel)
                }

                // State vital rows
                if let stateRows = viewModel.stateRows {
                    LazyVStack(alignment: .leading, spacing: .SQSpace.s) {
                        ForEach(stateRows) { row in
                            SQDailyCheckInVitalRow(model: row) {
                                print("PTD State Row Tapped:", row.title)
                            }

                            // Divider between rows
                            if row.id != stateRows.last?.id {
                                Divider()
                                    .sqBackgroundColor(SQColor.border)
                                    .padding(.vertical, .SQSpace.xs)
                            }
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity)
    }

    var habitsSection: some View {
        LazyVStack(alignment: .leading, spacing: 0) {
            SQCollapsibleSectionHeader(
                title: "Habits",
                isExpanded: viewModel.isHabitsExpanded,
                action: { viewModel.toggleHabitsExpanded() }
            ) {
                if viewModel.canEditDailyStats {
                    editButton
                }
            }

            if viewModel.isHabitsExpanded {
                // Habit vital rows
                if let habitRows = viewModel.habitRows {
                    LazyVStack(alignment: .leading, spacing: .SQSpace.s) {
                        ForEach(habitRows) { row in
                            SQDailyCheckInVitalRow(model: row) {
                                print("PTD Habit Row Tapped:", row.title)
                            }

                            // Divider between rows
                            if row.id != habitRows.last?.id {
                                Divider()
                                    .sqBackgroundColor(SQColor.border)
                                    .padding(.vertical, .SQSpace.xs)
                            }
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity)
    }

    var mainStack: some View {
        VStack(spacing: .SQSpace.l) {
            stateSection

            if viewModel.habitRows?.isEmpty == false {
                habitsSection
            }
        }
    }

    var body: some View {
        SQDashboardView.card { mainStack }
    }
}

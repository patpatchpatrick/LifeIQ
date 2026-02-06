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

    @ViewBuilder
    func groupSection(_ group: SQDashboardDailyCheckInRowViewModel.VitalGroup) -> some View {
        LazyVStack(alignment: .leading, spacing: 0) {
            SQCollapsibleSectionHeader(
                title: group.name,
                isExpanded: viewModel.isExpanded(group.id),
                action: { viewModel.toggleGroup(group.id) }
            ) {
                if viewModel.canEditDailyStats {
                    editButton
                }
            }

            if viewModel.isExpanded(group.id) {
                LazyVStack(alignment: .leading, spacing: .SQSpace.s) {
                    ForEach(group.rows) { row in
                        SQDailyCheckInVitalRow(model: row) {
                            print("PTD Row Tapped:", row.title)
                        }

                        if row.id != group.rows.last?.id {
                            Divider()
                                .sqBackgroundColor(SQColor.border(1))
                                .padding(.vertical, .SQSpace.xs)
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity)
    }

    var mainStack: some View {
        VStack(spacing: .SQSpace.l) {
            ForEach(viewModel.groups) { group in
                groupSection(group)
            }
        }
    }

    var body: some View {
        SQDashboardView.card { mainStack }
    }
}

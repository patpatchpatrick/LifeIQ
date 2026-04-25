//
//  SQWorkoutSplitsView.swift
//  BeastFitness
//

import SwiftUI
import BeastFitnessCore

struct SQWorkoutSplitsView: View {
    private static let maxCollapsedRows = 8

    let viewModel: SQWorkoutSplitsViewModel
    @State private var isShowingAllRows = false

    private var visibleItems: [SQWorkoutSplitsViewModel.SplitItem] {
        guard !isShowingAllRows, viewModel.splitItems.count > Self.maxCollapsedRows else {
            return viewModel.splitItems
        }

        return Array(viewModel.splitItems.prefix(Self.maxCollapsedRows))
    }

    private var canToggleVisibleRows: Bool {
        viewModel.splitItems.count > Self.maxCollapsedRows
    }

    private var rowToggleTitle: String {
        isShowingAllRows ? "See less" : "See more"
    }

    var body: some View {
        VStack(spacing: SQDashboardView.uiConfig.sectionRowSpacing) {
            SQColumnHeaderRow(columns: [
                .leading(viewModel.splitColumnTitle),
                .trailing(viewModel.timeColumnTitle),
                .trailing(viewModel.paceColumnTitle),
                .trailing(viewModel.heartRateColumnTitle)
            ])

            ForEach(visibleItems) { item in
                SQWorkoutSplitRow(item: item)
            }

            if canToggleVisibleRows {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isShowingAllRows.toggle()
                    }
                } label: {
                    HStack(spacing: .SQSpace.s) {
                        Text(rowToggleTitle)
                            .sqFont(.bodySmallSemiBold)
                            .sqForegroundColor(.textPrimary)

                        SQImageView(
                            image: .init(
                                symbol: isShowingAllRows ? .chevronUp : .chevronDown,
                                symbolStyle: .colorWithFont(.textSecondary, font: .bodyExtraSmall)
                            )
                        )
                        .frame(width: 10, height: 10)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, .SQSpace.xl)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

private struct SQWorkoutSplitRow: View {
    let item: SQWorkoutSplitsViewModel.SplitItem

    var body: some View {
        HStack(spacing: 12) {
            Text(item.label)
                .sqFont(.body)
                .sqForegroundColor(.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)

            splitValueText(item.timeText)
                .frame(maxWidth: .infinity * 0.75, alignment: .trailing)

            splitValueText(item.paceText)
                .frame(maxWidth: .infinity * 0.75, alignment: .trailing)

            splitValueText(item.heartRateText)
                .frame(maxWidth: .infinity * 0.75, alignment: .trailing)
        }
        .padding(.vertical, .SQSpace.s)
    }

    private func splitValueText(_ text: String) -> some View {
        Text(text)
            .sqFont(.bodySmallSemiBold)
            .sqForegroundColor(.textPrimary)
            .monospacedDigit()
    }
}

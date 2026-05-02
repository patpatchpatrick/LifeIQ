//
//  SQLeaderboardView.swift
//  BeastFitness
//
//  Created by Claude on 2/12/26.
//

import SwiftUI
import CoolCharts

struct SQLeaderboardView: View {
    @State var controller: SQLeaderboardController
    @Environment(\.modelContext) private var modelContext

    var navTitleView: some View {
        Text(controller.title)
            .sqFont(.title2)
            .sqForegroundColor(.textPrimary)
            .lineLimit(1)
            .minimumScaleFactor(0.68)
            .allowsTightening(true)
    }

    // MARK: - Empty State

    var emptyStateView: some View {
        VStack(spacing: .SQSpace.xl) {
            SQSubsectionEmptyState(message: "No data available")
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Row

    @ViewBuilder
    private func rowView(_ row: SQLeaderboardRowViewModel, index: Int) -> some View {
        let isLast = index == controller.rows.count - 1
        let isFocused = controller.focusedEntryId == row.id

        ZStack(alignment: .bottom) {
            // Row content
            SQLeaderboardRowView(viewModel: row, onTitleTapped: row.isNavigable ? {
                controller.navigateToWorkout(row)
            } : nil)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, .SQSpace.l)
                .overlay(
                    (isFocused ?
                        SQColor.dashboardGlowBlue.color.opacity(0.08) : Color.clear)
                        .allowsHitTesting(false)
                )
                .contentShape(Rectangle())
                .onTapGesture {
                    controller.rowTapped(row: row)
                }

            if !isLast {
                Divider()
                    .sqTintColor(.glassStroke)
                    .padding(.leading, .SQSpace.l)
            }
        }
        .listRowInsets(EdgeInsets())
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
    }

    // MARK: - Chart Section

    @ViewBuilder
    private func chartSection(_ chartModel: LineChartModel) -> some View {
        VStack(alignment: .leading, spacing: .SQSpace.m) {
            if let title = controller.chartTitle, let subtitle = controller.chartSubtitle {
                VStack(alignment: .leading, spacing: .SQSpace.xs) {
                    Text(title)
                        .sqFont(.title3)
                        .sqForegroundColor(.textPrimary)
                        .redacted(controller.isLoading, reason: .placeholder)

                    Text(subtitle)
                        .sqFont(.bodyExtraSmall)
                        .sqForegroundColor(.textSecondary)
                        .redacted(controller.isLoading, reason: .placeholder)
                }
                .padding(.horizontal, .SQSpace.l)
            }

            if controller.isLoading {
                RoundedRectangle(cornerRadius: .SQCornerRadius.l, style: .continuous)
                    .fill(SQColor.glassCardTint.color.opacity(SQColor.isDarkMode ? 0.5 : 0.9))
                    .frame(width: controller.chartWidth, height: controller.chartHeight)
            } else {
                LineChartView(model: chartModel)
                    .frame(width: controller.chartWidth, height: controller.chartHeight)

                SQChartLegend(model: chartModel, primaryTitle: "Scores", trendTitle: "Trend")
                .padding(.horizontal, .SQSpace.l)
                .padding(.top, .SQSpace.m)
            }
        }
        .padding(.horizontal, .SQSpace.l)
        .padding(.vertical, .SQSpace.xl)
        .frame(maxWidth: .infinity, alignment: .leading)
        .sqGlassSurface(level: .card, cornerRadius: .SQCornerRadius.xl)
    }
    

    // MARK: - Column Header

    /// Mirrors the HStack structure of SQLeaderboardRowView for aligned column labels.
    var columnHeader: some View {
        HStack(spacing: .SQSpace.m) {
            Text("RANK")
                .sqFont(.headerSmall)
                .sqForegroundColor(.textSecondary)
                .frame(width: 50, alignment: .leading)

            Text("WORKOUT")
                .sqFont(.headerSmall)
                .sqForegroundColor(.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text("SCORE")
                .sqFont(.headerSmall)
                .sqForegroundColor(.textSecondary)
                .frame(width: 88, alignment: .trailing)

            Text("ALL TIME")
                .sqFont(.headerSmall)
                .sqForegroundColor(.textSecondary)
                .frame(width: 84, alignment: .trailing)
        }
        .padding(.horizontal, .SQSpace.l)
        .padding(.top, .SQSpace.l)
        .padding(.bottom, .SQSpace.m)
        .frame(maxWidth: .infinity)
    }

    // MARK: - List

    var leaderboardList: some View {
        // Column header lives outside the List so it stays pinned without
        // fighting SwiftUI's built-in section header insets and top padding.
        VStack(spacing: 0) {
            columnHeader
            List {
                ForEach(Array(controller.rows.enumerated()), id: \.1.id) { index, row in
                    rowView(row, index: index)
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
        }
        .clipShape(RoundedRectangle(cornerRadius: .SQCornerRadius.xl, style: .continuous))
        .sqGlassSurface(level: .card, cornerRadius: .SQCornerRadius.xl)
    }
    
    var shouldShowEmptyView: Bool {
        controller.rows.isEmpty && !controller.isLoading
    }
    
    @ViewBuilder
    var mainView: some View {
        if shouldShowEmptyView {
            emptyStateView
        } else {
            ZStack {
                VStack(spacing: .SQSpace.l) {
                    if let chartModel = controller.chartModel {
                        chartSection(chartModel)
                    }

                    leaderboardList
                }
                .blur(radius: controller.isPremiumLocked ? 8 : 0)
                .allowsHitTesting(!controller.isPremiumLocked)

                if controller.isPremiumLocked {
                    Button(action: controller.premiumOverlayTapped) {
                        VStack(spacing: .SQSpace.s) {
                            Text("Premium workout scores")
                                .sqFont(.bodySemiBold)
                                .sqForegroundColor(.textPrimary)

                            Text(controller.premiumLockedSubtitle)
                                .sqFont(.bodyExtraSmall)
                                .sqForegroundColor(.textSecondary)
                                .multilineTextAlignment(.center)
                        }
                        .padding(.horizontal, .SQSpace.xl)
                        .padding(.vertical, .SQSpace.l)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: .SQCornerRadius.xl, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, .SQSpace.l)
            .padding(.top, .SQSpace.l)
            .padding(.bottom, .SQSpace.xl)
        }
    }

    var navView: some View {
        mainView
            .redacted(controller.isLoading, reason: .placeholder)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .navigationTitle(controller.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    navTitleView
                }
                ToolbarItem(placement: .topBarTrailing) {
                    SQDropDownMenu(
                        menuViewModel: controller.timeRangeMenuViewModel,
                        isDisabled: controller.isLoading,
                        showBackground: false
                    )
                }
            }
            .background {
                SQSheetBackground()
            }
            .task {
                await controller.loadUI(for: modelContext)
            }
    }

    var body: some View {
        GeometryReader { geo in
            navView
                .onAppear {
                    controller.updateLayout(containerWidth: geo.size.width)
                }
                .onChange(of: geo.size.width) { _, newWidth in
                    controller.updateLayout(containerWidth: newWidth)
                }
        }
    }
}

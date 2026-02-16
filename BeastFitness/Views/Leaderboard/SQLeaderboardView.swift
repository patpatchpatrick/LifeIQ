//
//  SQLeaderboardView.swift
//  BeastFitness
//
//  Created by Claude on 2/12/26.
//

import SwiftUI
import CoolCharts

struct SQLeaderboardView: View {
    @Bindable var controller: SQLeaderboardController
    @Environment(\.modelContext) private var modelContext

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
        let isFocused = controller.focusedWorkoutId == row.workout.id

        ZStack(alignment: .bottom) {
            // Row content
            SQLeaderboardRowView(viewModel: row)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, .SQSpace.l) // ✅ consistent padding for every row
                .background(SQColor.backgroundSecondary.color)
                .overlay(
                    // Highlight overlay for focused row (non-interactive)
                    (isFocused ?
                        SQColor.textPrimary.color.opacity(0.08) : Color.clear)
                        .allowsHitTesting(false) // Let taps pass through to content below
                )
                .contentShape(Rectangle()) // Makes entire area tappable
                .onTapGesture {
                    controller.rowTapped(row: row)
                }

            // Bottom divider (all but last row)
            if !isLast {
                Divider()
                    .sqTintColor(.divider(1))
                    .padding(.horizontal, 0) // full width
                    .background(SQColor.backgroundSecondary.color)
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
            // Header
            if let title = controller.chartTitle, let subtitle = controller.chartSubtitle {
                VStack(alignment: .leading, spacing: .SQSpace.xs) {
                    Text(title)
                        .sqFont(.body)
                        .sqForegroundColor(.textPrimary)
                        .redacted(controller.isLoading, reason: .placeholder)

                    Text(subtitle)
                        .sqFont(.bodyExtraSmall)
                        .sqForegroundColor(.textSecondary)
                        .redacted(controller.isLoading, reason: .placeholder)
                }
                .padding(.horizontal, .SQSpace.l)
            }

            // Chart or placeholder
            if controller.isLoading {
                // Show placeholder rectangle during loading
                Rectangle()
                    .fill(SQColor.background.color)
                    .frame(width: controller.chartWidth, height: controller.chartHeight)
            } else {
                // Show actual chart when loaded
                LineChartView(model: chartModel)
                    .frame(width: controller.chartWidth, height: controller.chartHeight)
            }
        }
        .padding(.horizontal, .SQSpace.l)
        .padding(.vertical, .SQSpace.xl)
        .background(SQColor.background.color)
    }
    

    // MARK: - List

    var leaderboardList: some View {
        List {
            ForEach(Array(controller.rows.enumerated()), id: \.1.id) { index, row in
                rowView(row, index: index)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(SQColor.background.color)
    }
    
    var shouldShowEmptyView: Bool {
        controller.rows.isEmpty && !controller.isLoading
    }
    
    @ViewBuilder
    var mainView: some View {
        if shouldShowEmptyView {
            emptyStateView
        } else {
            VStack(spacing: 0) {
                // Chart Section (shows placeholder during loading, actual chart when loaded)
                if let chartModel = controller.chartModel {
                    chartSection(chartModel)
                }

                // Content (list or empty state)
                leaderboardList
            }
        }
    }

    var navView: some View {
        mainView
            .redacted(controller.isLoading, reason: .placeholder)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .navigationTitle(controller.title)
            .navigationBarTitleDisplayMode(.inline)
            .background(SQColor.background.color)
            .task {
                await controller.loadUI(for: modelContext)
            }
    }

    var navStack: some View {
        NavigationStack(path: $controller.navigationPath) {
            navView
        }
    }

    var body: some View {
        GeometryReader { geo in
            navStack
                .onAppear {
                    controller.updateLayout(containerWidth: geo.size.width)
                }
                .onChange(of: geo.size.width) { _, newWidth in
                    controller.updateLayout(containerWidth: newWidth)
                }
        }
    }
}

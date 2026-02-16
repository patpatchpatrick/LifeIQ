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
            Text("No workouts found")
                .sqFont(.bodySmall)
                .sqForegroundColor(.textSecondary)

            Text("Complete some \(controller.activityType.name.lowercased()) workouts to see your leaderboard")
                .sqFont(.bodyExtraSmall)
                .sqForegroundColor(.textTertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, .SQSpace.xxl)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.top, 100)
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
                    // Highlight overlay for focused row
                    isFocused ?
                        SQColor.textPrimary.color.opacity(0.08) : Color.clear
                )

            // Bottom divider (all but last row)
            if !isLast {
                Divider()
                    .sqTintColor(.divider(1))
                    .padding(.horizontal, 0) // full width
                    .background(SQColor.backgroundSecondary.color)
            }
        }
        .listRowInsets(EdgeInsets())              // ✅ no extra system padding
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

                    Text(subtitle)
                        .sqFont(.bodyExtraSmall)
                        .sqForegroundColor(.textSecondary)
                }
            }

            // Chart
            LineChartView(model: chartModel)
                .frame(width: controller.chartWidth, height: controller.chartHeight)
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

    // MARK: - Content

    var contentView: some View {
        Group {
            if controller.rows.isEmpty && !controller.isLoading {
                emptyStateView
            } else {
                leaderboardList
                    .redacted(controller.isLoading, reason: .placeholder)
            }
        }
    }

    var navView: some View {
        VStack(spacing: 0) {
            // Chart Section (only if chartModel exists)
            if let chartModel = controller.chartModel {
                chartSection(chartModel)
            }

            // Content (list or empty state)
            contentView
        }
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
        navStack
    }
}

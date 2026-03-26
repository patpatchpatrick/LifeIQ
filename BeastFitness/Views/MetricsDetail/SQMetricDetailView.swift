//
//  SQMetricDetailView.swift
//  BeastFitness
//

import SwiftUI
import CoolCharts

struct SQMetricDetailView: View {
    @State var controller: SQMetricDetailController
    @Environment(\.modelContext) private var modelContext

    private var shouldShowEmptyState: Bool {
        controller.sections.isEmpty && !controller.isLoading
    }

    @ViewBuilder
    private func chartSection(_ chartModel: LineChartModel) -> some View {
        VStack(alignment: .leading, spacing: .SQSpace.m) {
            if let title = controller.chartTitle, let subtitle = controller.chartSubtitle {
                VStack(alignment: .leading, spacing: .SQSpace.xs) {
                    Text(title)
                        .sqFont(.body)
                        .sqForegroundColor(.textPrimary)

                    Text(subtitle)
                        .sqFont(.bodyExtraSmall)
                        .sqForegroundColor(.textSecondary)
                }
                .padding(.horizontal, .SQSpace.l)
            }

            LineChartView(model: chartModel)
                .frame(width: controller.chartWidth, height: controller.chartHeight)
        }
        .padding(.horizontal, .SQSpace.l)
        .padding(.vertical, .SQSpace.xl)
        .background(SQColor.backgroundSheet.color)
    }

    @ViewBuilder
    private var chartPlaceholderSection: some View {
        VStack(alignment: .leading, spacing: .SQSpace.m) {
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

            Text("Log at least 2 days to see a chart.")
                .sqFont(.bodySmall)
                .sqForegroundColor(.textSecondary)
                .frame(maxWidth: .infinity, minHeight: 120, alignment: .center)
                .sqBackgroundColor(.backgroundSecondary)
                .cornerRadius(.SQCornerRadius.m)
        }
        .padding(.horizontal, .SQSpace.l)
        .padding(.vertical, .SQSpace.xl)
        .background(SQColor.backgroundSheet.color)
    }

    private var emptyStateView: some View {
        VStack(spacing: .SQSpace.xl) {
            SQSubsectionEmptyState(message: "No data available")
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var bodyContent: some View {
        Group {
            if shouldShowEmptyState {
                emptyStateView
            } else {
                ScrollView {
                    VStack(spacing: .SQSpace.l) {
                        if let chartModel = controller.chartModel {
                            chartSection(chartModel)
                        } else {
                            chartPlaceholderSection
                        }

                        VStack(spacing: .SQSpace.l) {
                            ForEach(controller.sections) { section in
                                SQMetricDetailCardView(section: section)
                            }
                        }
                        .padding(.horizontal, .SQSpace.l)
                        .padding(.bottom, .SQSpace.xl)
                    }
                }
            }
        }
        .redacted(controller.isLoading, reason: .placeholder)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .navigationTitle(controller.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                SQDropDownMenu(
                    menuViewModel: controller.timeRangeMenuViewModel,
                    isDisabled: controller.isLoading,
                    showBackground: false
                )
            }
        }
        .background(SQColor.backgroundSheet.color)
        .task {
            await controller.loadUI(for: modelContext)
        }
    }

    var body: some View {
        GeometryReader { geo in
            bodyContent
                .onAppear {
                    controller.updateLayout(containerWidth: geo.size.width)
                }
                .onChange(of: geo.size.width) { _, newWidth in
                    controller.updateLayout(containerWidth: newWidth)
                }
        }
    }
}

private struct SQMetricDetailCardView: View {
    let section: SQMetricDetailController.Section

    private let columns = [
        GridItem(.flexible(), spacing: .SQSpace.s),
        GridItem(.flexible(), spacing: .SQSpace.s)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: .SQSpace.m) {
            Text(section.title)
                .sqFont(.bodySmallSemiBold)
                .sqForegroundColor(.textPrimary)

            LazyVGrid(columns: columns, spacing: .SQSpace.s) {
                ForEach(section.items) { item in
                    VStack(alignment: .leading, spacing: .SQSpace.xs) {
                        Text(item.title)
                            .sqFont(.bodyExtraSmall)
                            .sqForegroundColor(.textSecondary)

                        Text(item.value)
                            .sqFont(.bodySmallSemiBold)
                            .sqForegroundColor(.textPrimary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(maxWidth: .infinity, minHeight: 64, alignment: .leading)
                    .padding(.SQSpace.m)
                    .sqBackgroundColor(.backgroundTertiaryLight)
                    .cornerRadius(.SQCornerRadius.s)
                }
            }
        }
        .padding(.SQSpace.l)
        .sqBackgroundColor(.backgroundSecondary)
        .cornerRadius(.SQCornerRadius.m)
    }
}

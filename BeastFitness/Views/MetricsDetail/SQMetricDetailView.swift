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
                        .sqFont(.title3)
                        .sqForegroundColor(.textPrimary)

                    Text(subtitle)
                        .sqFont(.bodyExtraSmall)
                        .sqForegroundColor(.textSecondary)
                }
                .padding(.horizontal, .SQSpace.l)
            }

            LineChartView(model: chartModel)
                .frame(width: controller.chartWidth, height: controller.chartHeight)

            SQChartLegend(model: chartModel, primaryTitle: "Values", trendTitle: "Trend")
            .padding(.horizontal, .SQSpace.l)
            .padding(.top, .SQSpace.m)
        }
        .padding(.horizontal, .SQSpace.l)
        .padding(.vertical, .SQSpace.xl)
        .frame(maxWidth: .infinity, alignment: .leading)
        .sqGlassSurface(level: .card, cornerRadius: .SQCornerRadius.xl)
    }

    @ViewBuilder
    private var chartPlaceholderSection: some View {
        VStack(alignment: .leading, spacing: .SQSpace.m) {
            if let title = controller.chartTitle, let subtitle = controller.chartSubtitle {
                VStack(alignment: .leading, spacing: .SQSpace.xs) {
                    Text(title)
                        .sqFont(.title3)
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
                .sqGlassSurface(level: .card, cornerRadius: .SQCornerRadius.l)
        }
        .padding(.vertical, .SQSpace.xl)
        .padding(.horizontal, .SQSpace.l)
        .frame(maxWidth: .infinity, alignment: .leading)
        .sqGlassSurface(level: .card, cornerRadius: .SQCornerRadius.xl)
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
                        if controller.selectedTimeRange != .today {
                            if let chartModel = controller.chartModel {
                                chartSection(chartModel)
                            } else {
                                chartPlaceholderSection
                            }
                        }

                        VStack(spacing: .SQSpace.l) {
                            ForEach(controller.sections) { section in
                                SQMetricDetailCardView(section: section)
                            }
                        }
                        .padding(.bottom, .SQSpace.xl)
                    }
                    .padding(.horizontal, .SQSpace.l)
                    .padding(.top, .SQSpace.l)
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
        .background {
            SQSheetBackground()
        }
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
                .sqFont(.title3)
                .sqForegroundColor(.textPrimary)

            LazyVGrid(columns: columns, spacing: .SQSpace.s) {
                ForEach(section.items) { item in
                    VStack(alignment: .leading, spacing: .SQSpace.xs) {
                        Text(item.title.uppercased())
                            .sqFont(.headerSmall)
                            .sqForegroundColor(.textSecondary)

                        Text(item.value)
                            .sqFont(.bodySmallSemiBold)
                            .sqForegroundColor(item.valueColor)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        if let detail = item.detail {
                            Text(detail)
                                .sqFont(.bodyExtraSmall)
                                .sqForegroundColor(.textSecondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .frame(maxWidth: .infinity, minHeight: 64, alignment: .leading)
                    .padding(.SQSpace.m)
                    .sqGlassSurface(level: .card, cornerRadius: .SQCornerRadius.l)
                }
            }
        }
        .padding(.SQSpace.l)
        .sqGlassSurface(level: .card, cornerRadius: .SQCornerRadius.xl)
    }
}

struct SQChartLegend: View {
    @ObservedObject var model: LineChartModel
    let primaryTitle: String
    let trendTitle: String

    var body: some View {
        HStack(spacing: .SQSpace.s) {
            SQChartLegendToggle(
                title: primaryTitle,
                color: model.primaryLegendColor,
                isSelected: model.showPrimaryLine,
                action: { model.togglePrimaryLineVisibility() }
            )

            if model.hasTrendLine {
                SQChartLegendToggle(
                    title: trendTitle,
                    color: model.trendLegendColor,
                    isSelected: model.showTrendLine,
                    action: { model.toggleTrendLineVisibility() }
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct SQChartLegendToggle: View {
    let title: String
    let color: Color
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: .SQSpace.s) {
                ZStack {
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(
                            isSelected
                                ? color.opacity(0.22)
                                : SQColor.glassCardTint.color.opacity(SQColor.isDarkMode ? 0.72 : 0.96)
                        )

                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .stroke(
                            isSelected
                                ? color.opacity(0.9)
                                : SQColor.glassStroke.color,
                            lineWidth: 1
                        )

                    if isSelected {
                        SQImageView(
                            image: .init(
                                symbol: .checkmark,
                                symbolStyle: .colorWithFont(.textPrimary, font: .bodyExtraSmall)
                            )
                        )
                    }
                }
                .frame(width: 16, height: 16)

                Capsule(style: .continuous)
                    .fill(color)
                    .frame(width: 16, height: 4)

                Text(title)
                    .sqFont(.bodyExtraSmall)
                    .sqForegroundColor(isSelected ? .textPrimary : .textSecondary)
            }
            .padding(.vertical, .SQSpace.s)
            .padding(.horizontal, .SQSpace.m)
            .background(
                Capsule(style: .continuous)
                    .fill(SQColor.glassCardTint.color.opacity(SQColor.isDarkMode ? 0.76 : 0.96))
            )
            .overlay(
                Capsule(style: .continuous)
                    .stroke(SQColor.glassStroke.color, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

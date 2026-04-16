//
//  SQSleepPhaseTrendsView.swift
//  BeastFitness
//

import SwiftUI
import CoolCharts

struct SQSleepPhaseTrendsView: View {
    @State var controller: SQSleepPhaseTrendsController

    private var navTitleView: some View {
        Text(controller.title)
            .sqFont(.title2)
            .sqForegroundColor(.textPrimary)
            .lineLimit(1)
            .minimumScaleFactor(0.72)
    }

    private var emptyStateView: some View {
        VStack(spacing: .SQSpace.xl) {
            SQSubsectionEmptyState(message: controller.emptyMessage ?? "No sleep phase trends available")
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.SQSpace.xl)
    }

    @ViewBuilder
    private func chartSection(_ chartModel: MultiLineChartModel) -> some View {
        VStack(alignment: .leading, spacing: .SQSpace.m) {
            VStack(alignment: .leading, spacing: .SQSpace.xs) {
                Text(controller.chartTitle)
                    .sqFont(.title3)
                    .sqForegroundColor(.textPrimary)

                Text(controller.chartSubtitle)
                    .sqFont(.bodyExtraSmall)
                    .sqForegroundColor(.textSecondary)
            }
            .padding(.horizontal, .SQSpace.l)

            MultiLineChartView(model: chartModel)
                .frame(width: controller.chartWidth, height: controller.chartHeight)

            sleepPhaseLegend(chartModel)
                .padding(.horizontal, .SQSpace.l)
                .padding(.top, .SQSpace.m)
        }
        .padding(.horizontal, .SQSpace.l)
        .padding(.vertical, .SQSpace.xl)
        .frame(maxWidth: .infinity, alignment: .leading)
        .sqGlassSurface(level: .card, cornerRadius: .SQCornerRadius.xl)
    }

    private func sleepPhaseLegend(_ chartModel: MultiLineChartModel) -> some View {
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: 118), spacing: .SQSpace.s)],
            alignment: .leading,
            spacing: .SQSpace.s
        ) {
            ForEach(chartModel.series) { series in
                SQChartLegendToggle(
                    title: series.title,
                    color: series.color,
                    isSelected: chartModel.isSeriesVisible(series.id),
                    action: { chartModel.toggleSeriesVisibility(series.id) }
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var trendSection: some View {
        VStack(alignment: .leading, spacing: .SQSpace.l) {
            VStack(alignment: .leading, spacing: .SQSpace.xs) {
                Text("Phase trends")
                    .sqFont(.title3)
                    .sqForegroundColor(.textPrimary)

                Text("Average duration compared with the prior matching window.")
                    .sqFont(.bodyExtraSmall)
                    .sqForegroundColor(.textSecondary)
            }

            VStack(spacing: .SQSpace.m) {
                ForEach(controller.trendRows) { row in
                    trendRow(row)
                }
            }
        }
        .padding(.SQSpace.l)
        .sqGlassSurface(level: .card, cornerRadius: .SQCornerRadius.xl)
    }

    private func trendRow(_ row: SQSleepPhaseTrendRowViewModel) -> some View {
        let isFocused = controller.focusedPhase == row.phase

        return HStack(spacing: .SQSpace.m) {
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(row.color)
                .frame(width: 5)

            VStack(alignment: .leading, spacing: .SQSpace.xs) {
                Text(row.title)
                    .sqFont(.bodySmallSemiBold)
                    .sqForegroundColor(.textPrimary)

                Text(row.detailText)
                    .sqFont(.bodyExtraSmall)
                    .sqForegroundColor(.textSecondary)
            }

            Spacer(minLength: .SQSpace.m)

            VStack(alignment: .trailing, spacing: .SQSpace.xs) {
                Text(row.averageText)
                    .sqFont(.bodySmallSemiBold)
                    .sqForegroundColor(.textPrimary)

                Text(row.deltaText)
                    .sqFont(.bodyExtraSmall)
                    .foregroundStyle(row.deltaColor)
            }
        }
        .padding(.SQSpace.m)
        .background(
            RoundedRectangle(cornerRadius: .SQCornerRadius.l, style: .continuous)
                .fill(SQColor.glassCardTint.color.opacity(SQColor.isDarkMode ? 0.58 : 0.82))
        )
        .overlay(
            RoundedRectangle(cornerRadius: .SQCornerRadius.l, style: .continuous)
                .stroke(isFocused ? row.color.opacity(0.82) : SQColor.glassStroke.color, lineWidth: isFocused ? 1.4 : 1)
        )
    }

    @ViewBuilder
    private var mainView: some View {
        if controller.chartModel == nil && !controller.isLoading {
            emptyStateView
        } else {
            ScrollView {
                VStack(spacing: .SQSpace.l) {
                    if controller.isLoading {
                        RoundedRectangle(cornerRadius: .SQCornerRadius.xl, style: .continuous)
                            .fill(SQColor.glassCardTint.color.opacity(SQColor.isDarkMode ? 0.5 : 0.9))
                            .frame(height: controller.chartHeight + 120)
                    } else if let chartModel = controller.chartModel {
                        chartSection(chartModel)
                    }

                    if !controller.trendRows.isEmpty {
                        trendSection
                    }
                }
                .padding(.horizontal, .SQSpace.l)
                .padding(.top, .SQSpace.l)
                .padding(.bottom, .SQSpace.xl)
            }
            .redacted(controller.isLoading, reason: .placeholder)
        }
    }

    private var navView: some View {
        mainView
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
                await controller.loadUI()
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

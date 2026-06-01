//
//  SQSleepPhaseTrendsView.swift
//  BeastFitness
//

import SwiftUI
import CoolCharts

struct SQSleepPhaseTrendsView: View {
    @State var controller: SQSleepPhaseTrendsController
    private let phaseColumnWidth: CGFloat = 88
    private let bucketColumnWidth: CGFloat = 72

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

    private var averageSummarySection: some View {
        VStack(alignment: .leading, spacing: .SQSpace.l) {
            VStack(alignment: .leading, spacing: .SQSpace.xs) {
                HStack(spacing: .SQSpace.s) {
                    Text("Average phases")
                        .sqFont(.title3)
                        .sqForegroundColor(.textPrimary)

                    Text("Avg")
                        .sqFont(.headerSmall)
                        .sqForegroundColor(.textTertiary)
                        .padding(.horizontal, .SQSpace.s)
                        .padding(.vertical, .SQSpace.xs)
                        .background(
                            Capsule(style: .continuous)
                                .fill(SQColor.glassCardTint.color.opacity(SQColor.isDarkMode ? 0.48 : 0.62))
                        )
                        .overlay(
                            Capsule(style: .continuous)
                                .stroke(SQColor.glassStroke.color.opacity(SQColor.isDarkMode ? 0.48 : 0.58), lineWidth: 1)
                        )
                }

                Text("Average nightly duration for \(controller.selectedTimeRange.rawValue.lowercased()).")
                    .sqFont(.bodyExtraSmall)
                    .sqForegroundColor(.textSecondary)
            }

            VStack(spacing: .SQSpace.s) {
                ForEach(controller.trendRows) { row in
                    averageSummaryRow(row)
                }
            }
        }
        .padding(.SQSpace.l)
        .sqGlassSurface(level: .card, cornerRadius: .SQCornerRadius.xl)
    }

    private func averageSummaryRow(_ row: SQSleepPhaseTrendRowViewModel) -> some View {
        HStack(spacing: .SQSpace.m) {
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .fill(row.color)
                .frame(width: 4, height: 22)

            Text(row.title)
                .sqFont(.bodySmallSemiBold)
                .sqForegroundColor(.textSecondary)
                .lineLimit(1)

            Spacer(minLength: .SQSpace.m)

            Text(row.averageText)
                .sqFont(.bodySmallBold)
                .sqForegroundColor(.textPrimary)
                .monospacedDigit()
                .lineLimit(1)

            Text(row.deltaText)
                .sqFont(.bodyExtraSmall)
                .foregroundStyle(row.deltaColor)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.82)
        }
        .padding(.vertical, .SQSpace.xs)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(SQColor.glassStroke.color.opacity(0.42))
                .frame(height: 1)
        }
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

    private var phaseBucketSection: some View {
        VStack(alignment: .leading, spacing: .SQSpace.l) {
            VStack(alignment: .leading, spacing: .SQSpace.xs) {
                Text("Sleep phase trends")
                    .sqFont(.title3)
                    .sqForegroundColor(.textPrimary)

                Text("Average nightly duration by \(controller.selectedTimeRange.rawValue.lowercased()) period.")
                    .sqFont(.bodyExtraSmall)
                    .sqForegroundColor(.textSecondary)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    HStack(spacing: 0) {
                        tableHeaderCell("Phase", width: phaseColumnWidth, alignment: .leading)

                        ForEach(controller.trendBuckets) { bucket in
                            tableHeaderCell(
                                bucket.title,
                                width: bucketColumnWidth,
                                alignment: .trailing
                            )
                            .accessibilityLabel(bucket.detailTitle)
                        }
                    }
                    .padding(.bottom, .SQSpace.s)

                    ForEach(controller.trendRows) { row in
                        phaseBucketRow(row)
                    }
                }
                .padding(.vertical, .SQSpace.s)
            }
        }
        .padding(.SQSpace.l)
        .sqGlassSurface(level: .card, cornerRadius: .SQCornerRadius.xl)
    }

    private func phaseBucketRow(_ row: SQSleepPhaseTrendRowViewModel) -> some View {
        HStack(spacing: 0) {
            HStack(spacing: .SQSpace.s) {
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(row.color)
                    .frame(width: 4, height: 18)

                Text(row.title)
                    .sqFont(.bodyExtraSmall)
                    .sqForegroundColor(.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
            }
            .frame(width: phaseColumnWidth, alignment: .leading)

            ForEach(controller.trendBuckets) { bucket in
                Text(bucket.durationTextByPhase[row.phase] ?? "--")
                    .sqFont(.bodyExtraSmall)
                    .sqForegroundColor(.textPrimary)
                    .monospacedDigit()
                    .lineLimit(1)
                    .frame(width: bucketColumnWidth, alignment: .trailing)
            }
        }
        .padding(.vertical, .SQSpace.s)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(SQColor.glassStroke.color.opacity(0.72))
                .frame(height: 1)
        }
    }

    private func tableHeaderCell(_ title: String, width: CGFloat, alignment: Alignment) -> some View {
        Text(title.uppercased())
            .sqFont(.headerSmall)
            .sqForegroundColor(.textDisabled)
            .lineLimit(1)
            .minimumScaleFactor(0.72)
            .frame(width: width, alignment: alignment)
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
                    } else {
                        if !controller.trendRows.isEmpty {
                            averageSummarySection
                        }

                        if let chartModel = controller.chartModel {
                            chartSection(chartModel)
                        }
                    }

                    if !controller.trendBuckets.isEmpty {
                        phaseBucketSection
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

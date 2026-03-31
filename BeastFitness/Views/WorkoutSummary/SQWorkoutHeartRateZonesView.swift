//
//  SQWorkoutHeartRateZonesView.swift
//  BeastFitness
//

import SwiftUI
import CoolCharts
import BeastFitnessCore

struct SQWorkoutHeartRateZonesView: View {
    let viewModel: SQWorkoutHeartRateZonesViewModel

    @State private var selectedZoneId: String?

    var body: some View {
        VStack(alignment: .leading, spacing: .SQSpace.l) {
            Text(viewModel.subtitle)
                .sqFont(.bodyExtraSmall)
                .sqForegroundColor(.textSecondary)

            ViewThatFits(in: .horizontal) {
                HStack(alignment: .center, spacing: .SQSpace.xl) {
                    zoneChart
                    zoneLegend
                }

                VStack(alignment: .leading, spacing: .SQSpace.l) {
                    zoneChart
                    zoneLegend
                }
            }

            heartRateSummaryRow

            if let selectedItem {
                selectedZoneDetail(selectedItem)
            }

            Text(viewModel.footnote)
                .sqFont(.bodyExtraSmall)
                .sqForegroundColor(.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var selectedItem: SQWorkoutHeartRateZonesViewModel.ZoneItem? {
        guard let selectedZoneId else { return nil }
        return viewModel.zoneItems.first(where: { $0.id == selectedZoneId })
    }

    private var zoneChart: some View {
        SQWorkoutHeartRateZonePieChart(
            items: viewModel.zoneItems,
            centerTopText: selectedItem?.title ?? "Avg HR",
            centerBottomText: selectedItem.map { durationText(for: $0.durationSeconds) } ?? viewModel.averageHeartRateText,
            selectedZoneId: selectedZoneId,
            onSelectionChanged: { zoneId in
                if selectedZoneId == zoneId {
                    selectedZoneId = nil
                } else {
                    selectedZoneId = zoneId
                }
            }
        )
        .frame(width: 148, height: 148)
    }

    private var zoneLegend: some View {
        VStack(alignment: .leading, spacing: .SQSpace.s) {
            ForEach(viewModel.zoneItems) { item in
                let isSelected = selectedZoneId == item.id
                Button {
                    if selectedZoneId == item.id {
                        selectedZoneId = nil
                    } else {
                        selectedZoneId = item.id
                    }
                } label: {
                    HStack(alignment: .center, spacing: .SQSpace.m) {
                        Capsule(style: .continuous)
                            .fill(item.color.color)
                            .frame(width: 16, height: 4)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.title)
                                .sqFont(.bodyExtraSmall)
                                .sqForegroundColor(isSelected ? .textPrimary : .textSecondary)

                            Text(item.rangeText)
                                .sqFont(.bodyExtraSmall)
                                .sqForegroundColor(.textSecondary)

                            Text("\(durationText(for: item.durationSeconds)) • \(durationPercentText(for: item.durationSeconds))")
                                .sqFont(.bodySmallSemiBold)
                                .sqForegroundColor(.textPrimary)
                        }

                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, .SQSpace.m)
                    .padding(.vertical, .SQSpace.s)
                    .background {
                        RoundedRectangle(cornerRadius: .SQCornerRadius.m, style: .continuous)
                            .fill(
                                isSelected
                                ? SQColor.glassCardTint.color.opacity(SQColor.isDarkMode ? 0.92 : 1)
                                : Color.clear
                            )
                            .overlay {
                                RoundedRectangle(cornerRadius: .SQCornerRadius.m, style: .continuous)
                                    .stroke(
                                        isSelected
                                        ? SQColor.glassStrokeStrong.color
                                        : Color.white.opacity(0.001),
                                        lineWidth: 1
                                    )
                            }
                    }
                    .opacity(selectedZoneId == nil || isSelected ? 1 : 0.62)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, .SQSpace.s)
    }

    private var heartRateSummaryRow: some View {
        HStack(spacing: .SQSpace.s) {
            heartRateCard(title: "Min", value: viewModel.minimumHeartRateText, color: .accentNeutral4)
            heartRateCard(title: "Avg", value: viewModel.averageHeartRateText, color: .dashboardGlowBlue)
            heartRateCard(title: "Max", value: viewModel.maximumHeartRateText, color: .dashboardTrendWarm)
        }
    }

    private func heartRateCard(title: String, value: String, color: SQColor) -> some View {
        VStack(alignment: .leading, spacing: .SQSpace.xs) {
            Text(title.uppercased())
                .sqFont(.headerSmall)
                .sqForegroundColor(.textSecondary)

            Text(value)
                .sqFont(.bodySmallSemiBold)
                .sqForegroundColor(.textPrimary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.SQSpace.m)
        .background {
            RoundedRectangle(cornerRadius: .SQCornerRadius.l, style: .continuous)
                .fill(SQColor.glassCardTint.color.opacity(SQColor.isDarkMode ? 0.76 : 0.98))
                .overlay {
                    RoundedRectangle(cornerRadius: .SQCornerRadius.l, style: .continuous)
                        .stroke(color.color.opacity(SQColor.isDarkMode ? 0.42 : 0.24), lineWidth: 1)
                }
        }
    }

    private func selectedZoneDetail(_ item: SQWorkoutHeartRateZonesViewModel.ZoneItem) -> some View {
        VStack(alignment: .leading, spacing: .SQSpace.s) {
            HStack(alignment: .firstTextBaseline, spacing: .SQSpace.s) {
                Text("\(item.title) • \(item.subtitle)")
                    .sqFont(.bodySmallSemiBold)
                    .sqForegroundColor(.textPrimary)

                Spacer(minLength: 0)

                Text("\(Int(item.contribution.rounded())) pts")
                    .sqFont(.bodySmallSemiBold)
                    .sqForegroundColor(.textPrimary)
            }

            Text("\(durationText(for: item.durationSeconds)) in range \(item.rangeText). This zone contributed \(Int(item.contribution.rounded())) weighted load points.")
                .sqFont(.bodyExtraSmall)
                .sqForegroundColor(.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.SQSpace.l)
        .background {
            RoundedRectangle(cornerRadius: .SQCornerRadius.l, style: .continuous)
                .fill(SQColor.glassCardTint.color.opacity(SQColor.isDarkMode ? 0.72 : 0.96))
                .overlay {
                    RoundedRectangle(cornerRadius: .SQCornerRadius.l, style: .continuous)
                        .stroke(SQColor.glassStroke.color, lineWidth: 1)
                }
        }
    }

    private func durationText(for durationSeconds: Double) -> String {
        durationSeconds.readableTime()
    }

    private func durationPercentText(for durationSeconds: Double) -> String {
        let totalDuration = max(viewModel.zoneItems.reduce(0) { $0 + $1.durationSeconds }, 1)
        let percent = durationSeconds / totalDuration
        return percent.toPercentageString(decimals: 0)
    }
}

private struct SQWorkoutHeartRateZonePieChart: View {
    private static let chartSize: CGFloat = 148
    private static let centerDiscSize: CGFloat = 86

    let items: [SQWorkoutHeartRateZonesViewModel.ZoneItem]
    let centerTopText: String
    let centerBottomText: String
    let selectedZoneId: String?
    let onSelectionChanged: (String?) -> Void

    @State private var pieChartModel: PieChartModel?

    private var rebuildKey: String {
        items
            .map { "\($0.id):\($0.durationSeconds)" }
            .joined(separator: "|")
    }

    var body: some View {
        ZStack {
            if let pieChartModel {
                PieChartView(model: pieChartModel, visualStyle: .glass)
            } else {
                Circle()
                    .stroke(Color.white.opacity(SQColor.isDarkMode ? 0.16 : 0.24), lineWidth: 18)
            }

            Circle()
                .fill(SQColor.glassPopoverTint.color.opacity(SQColor.isDarkMode ? 0.92 : 1))
                .frame(width: Self.centerDiscSize, height: Self.centerDiscSize)
                .overlay {
                    Circle()
                        .stroke(SQColor.glassStrokeStrong.color, lineWidth: 1)
                }

            VStack(spacing: 2) {
                Text(centerTopText)
                    .sqFont(.bodyExtraSmall)
                    .sqForegroundColor(.textSecondary)

                Text(centerBottomText)
                    .sqFont(.bodySmallSemiBold)
                    .sqForegroundColor(.textPrimary)
            }
            .frame(width: Self.centerDiscSize - 10)
            .onTapGesture {
                onSelectionChanged(nil)
            }
        }
        .frame(width: Self.chartSize, height: Self.chartSize)
        .onAppear {
            rebuildModel()
        }
        .onChange(of: rebuildKey) { _, _ in
            rebuildModel()
        }
        .onChange(of: selectedZoneId) { _, newValue in
            guard let pieChartModel, pieChartModel.focusedSectionId != newValue else { return }
            pieChartModel.sectionFocused(sectionId: newValue, shouldCallFocusCompletionHandler: false)
        }
    }

    private func rebuildModel() {
        let model = PieChartModel(
            sections: items.map { item in
                PieChartSectionConfig(
                    id: item.id,
                    magnitude: max(0.0001, item.durationSeconds),
                    color: item.color.color,
                    radialFillPercent: 1,
                    radialUnfilledColor: Color.white.opacity(SQColor.isDarkMode ? 0.12 : 0.18)
                )
            },
            sectionIdTapped: { sectionId in
                onSelectionChanged(sectionId)
            },
            sectionAlignment: .center,
            widthHeight: Self.chartSize,
            focusGrowthPercent: 0.5
        )

        if let model {
            model.expectedPieSections = model.expectedPieSections.map { section in
                var section = section
                section.strokeWidth = 16
                section.expectedStrokeWidth = 16
                return section
            }
            model.pieSections = model.expectedPieSections
        }

        pieChartModel = model
        if pieChartModel?.focusedSectionId != selectedZoneId {
            pieChartModel?.sectionFocused(sectionId: selectedZoneId, shouldCallFocusCompletionHandler: false)
        }
    }
}

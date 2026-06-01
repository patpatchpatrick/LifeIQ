//
//  SQDashboardSleepScoreRowView.swift
//  BeastFitness
//

import SwiftUI
import CoolCharts

struct SQDashboardSleepScoreRowView: View {
    @Bindable var viewModel: SQDashboardSleepScoreRowViewModel

    private func componentColor(for index: Int) -> Color {
        switch index {
        case 0:
            return SQColor.dashboardGlowBlue.color.opacity(0.95)
        case 1:
            return SQColor.dashboardGlowMint.color.opacity(SQColor.isDarkMode ? 0.82 : 0.92)
        case 2:
            return Color.white.opacity(SQColor.isDarkMode ? 0.72 : 0.82)
        default:
            return Color.white.opacity(SQColor.isDarkMode ? 0.46 : 0.62)
        }
    }

    var body: some View {
        let selectedComponent = viewModel.components.first(where: { $0.id == viewModel.selectedComponentId })

        return VStack(alignment: .leading, spacing: .SQSpace.l) {
            if let trendDelta = viewModel.trendDelta {
                SQDashboardTrendDeltaPill(viewModel: trendDelta)
            }

            HStack(alignment: .center, spacing: .SQSpace.xl) {
                SQSleepScorePieChart(
                    components: viewModel.components,
                    totalLabel: viewModel.scoreLabel,
                    isInteractive: viewModel.isSliceSelectionEnabled,
                    selectedComponentId: viewModel.selectedComponentId,
                    colorProvider: componentColor(for:),
                    onSelectionChanged: { componentId in
                        viewModel.selectedComponentId = componentId
                    }
                )
                .frame(width: 148, height: 148)

                Spacer()

                VStack(alignment: .leading, spacing: .SQSpace.m) {
                    ForEach(Array(viewModel.components.enumerated()), id: \.element.id) { index, component in
                        let isSelected = viewModel.selectedComponentId == component.id

                        Button {
                            viewModel.toggleSelection(for: component.id)
                        } label: {
                            HStack(alignment: .firstTextBaseline, spacing: .SQSpace.m) {
                                Capsule(style: .continuous)
                                    .fill(componentColor(for: index))
                                    .frame(width: 16, height: 4)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(component.title)
                                        .sqFont(.bodyExtraSmall)
                                        .sqForegroundColor(isSelected ? .textPrimary : .textSecondary)
                                    Text("\(Int(component.score))/\(Int(component.maxScore))")
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
                            .opacity(viewModel.selectedComponentId == nil || isSelected ? 1 : 0.62)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, .SQSpace.s)
            }

            if let selectedComponent {
                HStack(alignment: .top, spacing: .SQSpace.m) {
                    Capsule(style: .continuous)
                        .fill(componentColor(for: componentIndex(for: selectedComponent.id)))
                        .frame(width: 18, height: 5)
                        .padding(.top, 7)

                    Text(selectedComponent.detailText)
                        .sqFont(.bodyExtraSmall)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, .SQSpace.l)
                .padding(.vertical, .SQSpace.m)
                .background {
                    RoundedRectangle(cornerRadius: .SQCornerRadius.l, style: .continuous)
                        .fill(SQColor.glassCardTint.color.opacity(SQColor.isDarkMode ? 0.72 : 0.96))
                        .overlay {
                            RoundedRectangle(cornerRadius: .SQCornerRadius.l, style: .continuous)
                                .stroke(SQColor.glassStroke.color, lineWidth: 1)
                        }
                }
                .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
        }
        .animation(.easeInOut(duration: 0.18), value: viewModel.selectedComponentId)
    }

    private func componentIndex(for componentId: String) -> Int {
        viewModel.components.firstIndex(where: { $0.id == componentId }) ?? 0
    }
}

private struct SQSleepScorePieChart: View {
    private static let chartSize: CGFloat = 148
    private static let centerDiscSize: CGFloat = 86
    let components: [SQDashboardSleepScoreRowViewModel.Component]
    let totalLabel: String
    let isInteractive: Bool
    let selectedComponentId: String?
    let colorProvider: (Int) -> Color
    let onSelectionChanged: (String?) -> Void

    @State private var pieChartModel: PieChartModel?

    private var rebuildKey: String {
        components
            .map { "\($0.id):\($0.score):\($0.maxScore)" }
            .joined(separator: "|")
    }

    private var selectedComponent: SQDashboardSleepScoreRowViewModel.Component? {
        guard let selectedComponentId else { return nil }
        return components.first(where: { $0.id == selectedComponentId })
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
                .shadow(
                    color: Color.black.opacity(SQColor.isDarkMode ? 0.18 : 0.08),
                    radius: 10,
                    x: 0,
                    y: 6
                )

            VStack(spacing: 2) {
                if let selectedComponent {
                    Text(selectedComponent.title)
                        .sqFont(.bodyExtraSmall)
                        .sqForegroundColor(.textSecondary)
                    Text("\(Int(selectedComponent.score))")
                        .sqFont(.bodySmallSemiBold)
                        .sqForegroundColor(.textPrimary)
                } else {
                    Text(scoreDisplayText)
                        .sqFont(.title1)
                        .sqForegroundColor(.textPrimary)
                }
            }
            .frame(width: Self.centerDiscSize - 12)
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
        .onChange(of: selectedComponentId) { _, newValue in
            guard let pieChartModel, pieChartModel.focusedSectionId != newValue else { return }
            pieChartModel.sectionFocused(sectionId: newValue, shouldCallFocusCompletionHandler: false)
        }
    }

    private var scoreDisplayText: String {
        totalLabel
            .split(separator: "/")
            .first
            .map(String.init) ?? totalLabel
    }

    private func rebuildModel() {
        let sectionConfigs = buildSectionConfigs()
        let model = PieChartModel(
            sections: sectionConfigs,
            sectionIdTapped: { sectionId in
                guard isInteractive else { return }
                onSelectionChanged(sectionId.map(Self.componentId(from:)))
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
        if pieChartModel?.focusedSectionId != selectedComponentId {
            pieChartModel?.sectionFocused(sectionId: selectedComponentId, shouldCallFocusCompletionHandler: false)
        }
    }

    private func buildSectionConfigs() -> [PieChartSectionConfig] {
        components.enumerated().map { index, component in
            let clampedScore = min(component.maxScore, max(0, component.score))
            let fillPercent = clampedScore / max(component.maxScore, 1)
            let color = colorProvider(index)

            return PieChartSectionConfig(
                id: component.id,
                magnitude: max(0.0001, component.maxScore),
                color: color,
                radialFillPercent: fillPercent,
                radialUnfilledColor: Color.white.opacity(SQColor.isDarkMode ? 0.12 : 0.18)
            )
        }
    }

    private static func componentId(from sectionId: String) -> String {
        return sectionId
    }
}

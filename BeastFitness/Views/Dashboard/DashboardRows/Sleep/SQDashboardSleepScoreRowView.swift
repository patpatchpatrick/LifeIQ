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
            return Color.white.opacity(SQColor.isDarkMode ? 0.72 : 0.82)
        default:
            return Color.white.opacity(SQColor.isDarkMode ? 0.46 : 0.62)
        }
    }

    var body: some View {
        HStack(alignment: .center, spacing: .SQSpace.xl) {
            SQSleepScorePieChart(
                components: viewModel.components,
                totalLabel: viewModel.scoreLabel,
                isInteractive: viewModel.isSliceSelectionEnabled,
                colorProvider: componentColor(for:)
            )
            .frame(width: 148, height: 148)

            Spacer()

            VStack(alignment: .leading, spacing: .SQSpace.m) {
                ForEach(Array(viewModel.components.enumerated()), id: \.element.id) { index, component in
                    HStack(alignment: .firstTextBaseline, spacing: .SQSpace.m) {
                        Capsule(style: .continuous)
                            .fill(componentColor(for: index))
                            .frame(width: 16, height: 4)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(component.title)
                                .sqFont(.bodyExtraSmall)
                                .sqForegroundColor(.textSecondary)
                            Text("\(Int(component.score))/\(Int(component.maxScore))")
                                .sqFont(.bodySmallSemiBold)
                                .sqForegroundColor(.textPrimary)
                        }
                    }
                }
            }
            .padding(.vertical, .SQSpace.s)
        }
    }
}

private struct SQSleepScorePieChart: View {
    private static let chartSize: CGFloat = 148
    private static let centerDiscSize: CGFloat = 86
    let components: [SQDashboardSleepScoreRowViewModel.Component]
    let totalLabel: String
    let isInteractive: Bool
    let colorProvider: (Int) -> Color

    @State private var selectedComponentId: String?
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
                selectedComponentId = nil
                pieChartModel?.sectionFocused(sectionId: nil, shouldCallFocusCompletionHandler: false)
            }
        }
        .frame(width: Self.chartSize, height: Self.chartSize)
        .onAppear {
            rebuildModel()
        }
        .onChange(of: rebuildKey) { _, _ in
            rebuildModel()
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
                selectedComponentId = sectionId.map(Self.componentId(from:))
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
        selectedComponentId = nil
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

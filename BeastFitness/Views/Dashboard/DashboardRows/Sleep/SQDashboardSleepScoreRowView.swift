//
//  SQDashboardSleepScoreRowView.swift
//  BeastFitness
//

import SwiftUI
import CoolCharts

struct SQDashboardSleepScoreRowView: View {
    @Bindable var viewModel: SQDashboardSleepScoreRowViewModel

    var body: some View {
        HStack(alignment: .center, spacing: 0) {
            SQSleepScorePieChart(
                components: viewModel.components,
                totalLabel: viewModel.scoreLabel,
                isInteractive: viewModel.isSliceSelectionEnabled
            )
            .frame(width: 148, height: 148)
            
            Spacer()

            VStack(alignment: .leading, spacing: .SQSpace.xs) {
                ForEach(viewModel.components) { component in
                    HStack(spacing: .SQSpace.s) {
                        Circle()
                            .fill(component.color.color)
                            .frame(width: 8, height: 8)
                        Text("\(component.title): \(Int(component.score))/\(Int(component.maxScore))")
                            .sqFont(.bodyExtraSmall)
                            .sqForegroundColor(.textSecondary)
                    }
                }
            }
            
            Spacer()
        }
    }
}

private struct SQSleepScorePieChart: View {
    private static let chartSize: CGFloat = 148
    let components: [SQDashboardSleepScoreRowViewModel.Component]
    let totalLabel: String
    let isInteractive: Bool

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
                PieChartView(model: pieChartModel)
            } else {
                Circle()
                    .stroke(SQColor.backgroundTertiaryLight.color, lineWidth: 18)
            }

            VStack(spacing: 2) {
                if let selectedComponent {
                    Text(selectedComponent.title)
                        .sqFont(.bodyExtraSmall)
                        .sqForegroundColor(.textSecondary)
                    Text("\(Int(selectedComponent.score))/\(Int(selectedComponent.maxScore))")
                        .sqFont(.bodySmallSemiBold)
                        .sqForegroundColor(.textPrimary)
                } else {
                    Text(totalLabel)
                        .sqFont(.title2)
                        .sqForegroundColor(.textPrimary)
                }
            }
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
        components.map { component in
            let clampedScore = min(component.maxScore, max(0, component.score))
            let fillPercent = clampedScore / max(component.maxScore, 1)

            return PieChartSectionConfig(
                id: component.id,
                magnitude: max(0.0001, component.maxScore),
                color: component.color.color,
                radialFillPercent: fillPercent,
                radialUnfilledColor: component.color.color.opacity(0.22)
            )
        }
    }

    private static func componentId(from sectionId: String) -> String {
        return sectionId
    }
}

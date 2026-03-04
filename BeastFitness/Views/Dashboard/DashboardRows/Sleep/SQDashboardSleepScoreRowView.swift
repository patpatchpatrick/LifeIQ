//
//  SQDashboardSleepScoreRowView.swift
//  BeastFitness
//

import SwiftUI

struct SQDashboardSleepScoreRowView: View {
    @Bindable var viewModel: SQDashboardSleepScoreRowViewModel

    var body: some View {
        HStack(alignment: .center, spacing: .SQSpace.l) {
            SQSleepScoreDonutChart(components: viewModel.components)
                .frame(width: 120, height: 120)

            VStack(alignment: .leading, spacing: .SQSpace.m) {
                Text(viewModel.scoreLabel)
                    .sqFont(.title2)
                    .sqForegroundColor(.textPrimary)

                Text(viewModel.subtitle)
                    .sqFont(.bodyExtraSmall)
                    .sqForegroundColor(.textSecondary)

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
            }

            Spacer()
        }
    }
}

private struct SQSleepScoreDonutChart: View {
    let components: [SQDashboardSleepScoreRowViewModel.Component]

    private var totalMagnitude: Double {
        components.map(\.maxScore).reduce(0, +)
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(Array(components.enumerated()), id: \.element.id) { index, component in
                    let start = startFraction(at: index)
                    let fullFraction = component.maxScore / max(totalMagnitude, 1)
                    let earnedFraction = fullFraction * (component.score / max(component.maxScore, 1))

                    Circle()
                        .trim(from: start, to: start + fullFraction)
                        .stroke(component.color.color.opacity(0.20), style: .init(lineWidth: 18, lineCap: .butt))
                        .rotationEffect(.degrees(-90))

                    Circle()
                        .trim(from: start, to: start + earnedFraction)
                        .stroke(component.color.color, style: .init(lineWidth: 18, lineCap: .butt))
                        .rotationEffect(.degrees(-90))
                }

                Text("\(Int(components.map(\.score).reduce(0, +)))")
                    .sqFont(.title2)
                    .sqForegroundColor(.textPrimary)
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
    }

    private func startFraction(at index: Int) -> CGFloat {
        guard index > 0 else { return 0 }
        let priorTotal = components.prefix(index).map(\.maxScore).reduce(0, +)
        return CGFloat(priorTotal / max(totalMagnitude, 1))
    }
}

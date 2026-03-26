//
//  SQMultiSelect.swift
//  BeastFitness
//

import SwiftUI

struct SQMultiSelect: View {
    @ObservedObject var viewModel: SQMultiSelectViewModel

    var body: some View {
        HStack(spacing: .SQSpace.s) {
            ForEach(viewModel.items) { item in
                let isOn = viewModel.isSelected(item)
                Button {
                    viewModel.toggle(item)
                } label: {
                    Text(item.title)
                        .sqFont(.bodySmallSemiBold)
                        .sqForegroundColor(isOn ? .dashboardGlowBlueForeground : .textSecondary)
                        .padding(.horizontal, .SQSpace.m)
                        .padding(.vertical, .SQSpace.s)
                        .background(
                            RoundedRectangle(cornerRadius: .SQCornerRadius.l, style: .continuous)
                                .fill(
                                    isOn
                                        ? SQColor.dashboardGlowBlue.color.opacity(SQColor.isDarkMode ? 0.22 : 0.14)
                                        : SQColor.glassCardTint.color.opacity(SQColor.isDarkMode ? 0.78 : 0.96)
                                )
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: .SQCornerRadius.l, style: .continuous)
                                .stroke(
                                    isOn
                                        ? SQColor.dashboardGlowBlue.color.opacity(0.42)
                                        : SQColor.glassStroke.color,
                                    lineWidth: 1
                                )
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }
}

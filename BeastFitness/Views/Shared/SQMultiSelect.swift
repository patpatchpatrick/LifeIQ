//
//  SQMultiSelect.swift
//  BeastFitness
//

import SwiftUI

struct SQMultiSelect: View {
    @ObservedObject var viewModel: SQMultiSelectViewModel

    var body: some View {
        HStack(spacing: 8) {
            ForEach(viewModel.items) { item in
                let isOn = viewModel.isSelected(item)
                Button {
                    viewModel.toggle(item)
                } label: {
                    Text(item.title)
                        .sqFont(.bodySmall)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .foregroundStyle(isOn ? SQColor.textPrimary.color : SQColor.textSecondary.color)
                        .background(isOn ? SQColor.backgroundSecondary.color : Color.clear)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(isOn ? SQColor.textPrimary.color.opacity(0.3) : SQColor.textSecondary.color.opacity(0.2), lineWidth: 1)
                        )
                }
            }
        }
    }
}

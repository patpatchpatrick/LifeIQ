//
//  SQDashboardSectionHeader.swift
//  BeastFitness
//
//  Created by Claude Code on 2/6/26.
//

import SwiftUI

struct SQDashboardSectionHeader: View {
    let title: String
    @Binding var isCollapsed: Bool

    private var labelBackground: Color {
        SQColor.glassCardTint.color.opacity(SQColor.isDarkMode ? 0.55 : 0.9)
    }

    var body: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                isCollapsed.toggle()
            }
        } label: {
            HStack {
                HStack(spacing: .SQSpace.s) {
                    Text(title.uppercased())
                        .sqFont(.headerSmall)
                        .sqForegroundColor(.textSecondary)

                    SQImageView(
                        image: .init(
                            symbol: isCollapsed ? .chevronDown : .chevronUp,
                            symbolStyle: .colorWithFont(.textSecondary, font: .bodySmall)
                        )
                    )
                    .frame(width: 10, height: 10)
                }
                .padding(.horizontal, .SQSpace.l)
                .padding(.vertical, .SQSpace.s)
                .background(
                    Capsule(style: .continuous)
                        .fill(labelBackground)
                )
                .overlay(
                    Capsule(style: .continuous)
                        .stroke(SQColor.glassStroke.color, lineWidth: 1)
                )

                Spacer()
            }
            .frame(maxWidth: .infinity)
            .padding(.top, .SQSpace.l)
            .padding(.bottom, .SQSpace.m)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    VStack(spacing: 0) {
        SQDashboardSectionHeader(
            title: "Daily Stats",
            isCollapsed: .constant(false)
        )

        SQDashboardSectionHeader(
            title: "Workouts",
            isCollapsed: .constant(true)
        )
    }
    .sqBackgroundColor(.background)
}

//
//  SQDashboardSectionHeader.swift
//  BeastFitness
//
//  Created by Claude Code on 2/6/26.
//

import SwiftUI

struct SQDashboardSectionHeader: View {
    let title: String
    let titleButton: SQDashboardSubsectionViewModel.TitleButtonViewModel?
    @Binding var isCollapsed: Bool

    init(
        title: String,
        titleButton: SQDashboardSubsectionViewModel.TitleButtonViewModel? = nil,
        isCollapsed: Binding<Bool>
    ) {
        self.title = title
        self.titleButton = titleButton
        self._isCollapsed = isCollapsed
    }

    private var labelBackground: Color {
        SQColor.glassCardTint.color.opacity(SQColor.isDarkMode ? 0.55 : 0.9)
    }

    var body: some View {
        HStack {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isCollapsed.toggle()
                }
            } label: {
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
            }
            .buttonStyle(.plain)

            Spacer()

            if let titleButton {
                Button {
                    titleButton.onTap()
                } label: {
                    HStack(spacing: .SQSpace.xs) {
                        SQImageView(
                            image: .init(
                                symbol: titleButton.icon,
                                symbolStyle: .colorWithFont(.textPrimary, font: .headerSmall)
                            )
                        )
                        .frame(width: 10, height: 10)

                        if let title = titleButton.title {
                            Text(title)
                                .sqFont(.bodyExtraSmall)
                                .sqForegroundColor(.textPrimary)
                        }
                    }
                    .padding(.vertical, 6)
                    .padding(.horizontal, .SQSpace.s)
                    .background(
                        Capsule(style: .continuous)
                            .fill(SQColor.glassCardTint.color.opacity(SQColor.isDarkMode ? 0.82 : 0.96))
                    )
                    .overlay(
                        Capsule(style: .continuous)
                            .stroke(SQColor.glassStroke.color, lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, .SQSpace.l)
        .padding(.bottom, .SQSpace.m)
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

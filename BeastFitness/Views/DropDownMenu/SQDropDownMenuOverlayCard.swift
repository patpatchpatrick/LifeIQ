//
//  SQDropDownMenuOverlayCard.swift
//  BeastFitness
//

import SwiftUI

struct SQDropDownMenuOverlayCard: View {
    let menu: SQDropDownMenuState.MenuPresentation
    let menuState: SQDropDownMenuState
    private let scrollThreshold = 6

    @ViewBuilder
    private var scrollHint: some View {
        HStack(spacing: .SQSpace.xs) {
            Text("Scroll")
                .sqFont(.bodyExtraSmall)
                .sqForegroundColor(.dashboardGlowBlue)

            SQImageView(
                image: .init(
                    symbol: .chevronDown,
                    symbolStyle: .colorWithFont(.dashboardGlowBlue, font: .bodyExtraSmall)
                )
            )
            .frame(width: 10, height: 10)
        }
        .padding(.horizontal, .SQSpace.s)
        .padding(.vertical, 6)
        .background(
            Capsule(style: .continuous)
                .fill(SQColor.glassCardTint.color.opacity(SQColor.isDarkMode ? 0.92 : 0.96))
        )
        .overlay(
            Capsule(style: .continuous)
                .stroke(SQColor.glassStroke.color.opacity(0.8), lineWidth: 1)
        )
        .allowsHitTesting(false)
    }

    @ViewBuilder
    private var menuItemsContent: some View {
        VStack(spacing: 0) {
            ForEach(Array(menu.items.enumerated()), id: \.offset) { index, item in
                Button {
                    // Dismiss the overlay first, then fire selection after the animation settles
                    withAnimation(.easeInOut(duration: 0.15)) {
                        menuState.dismiss()
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                        menu.onSelect(item.title)
                    }
                } label: {
                    HStack(alignment: .center, spacing: .SQSpace.s) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(item.title)
                                .sqFont(.body)
                                .sqForegroundColor(.textPrimary)

                            if let subtitle = item.subtitle, !subtitle.isEmpty {
                                Text(subtitle)
                                    .sqFont(.bodyExtraSmall)
                                    .sqForegroundColor(.textSecondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }

                        if let badgeText = item.badgeText {
                            SQDashboardNewBadge(text: badgeText)
                        } else if item.showsIndicatorDot {
                            Circle()
                                .fill(SQColor.dashboardGlowBlue.color)
                                .frame(width: 8, height: 8)
                        }

                        Spacer()
                        if item.title == menu.selectedTitle {
                            SQImageView(
                                image: .init(
                                    symbol: .checkmark,
                                    symbolStyle: .colorWithFont(.textPrimary, font: .body)
                                )
                            )
                            .frame(width: 14, height: 14)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                if index < menu.items.count - 1 {
                    Rectangle()
                        .fill(SQColor.glassStroke.color.opacity(0.72))
                        .frame(height: 1)
                        .padding(.leading, 16)
                }
            }
        }
    }

    var body: some View {
        Group {
            if menu.items.count > scrollThreshold {
                ScrollView {
                    menuItemsContent
                }
                .frame(maxHeight: 320)
                .overlay(alignment: .bottom) {
                    scrollHint
                        .padding(.bottom, .SQSpace.s)
                }
            } else {
                menuItemsContent
            }
        }
        .frame(minWidth: 160)
        .fixedSize(horizontal: false, vertical: true)
        .background {
            RoundedRectangle(cornerRadius: .SQCornerRadius.xl, style: .continuous)
                .fill(SQColor.backgroundTertiaryDark.color.opacity(SQColor.isDarkMode ? 0.96 : 0.98))
                .overlay {
                    RoundedRectangle(cornerRadius: .SQCornerRadius.xl, style: .continuous)
                        .fill(SQColor.glassCardTint.color.opacity(SQColor.isDarkMode ? 0.62 : 0.86))
                }
                .overlay {
                    RoundedRectangle(cornerRadius: .SQCornerRadius.xl, style: .continuous)
                        .stroke(SQColor.glassStroke.color.opacity(SQColor.isDarkMode ? 0.86 : 0.72), lineWidth: 1)
                }
        }
        .shadow(color: Color.black.opacity(SQColor.isDarkMode ? 0.18 : 0.08), radius: 14, x: 0, y: 8)
    }
}

//
//  SQAlertCard.swift
//  BeastFitness
//
//  Created by Patrick Doyle on 12/17/25.
//

import SwiftUI

struct SQAlertCard: View {
    let alert: SQAlertViewModel
    let onPrimary: () -> Void
    let onSecondary: () -> Void
    let onDismiss: () -> Void

    private var headerAccentColor: SQColor {
        if alert.primary.role == .destructive || alert.secondary?.role == .destructive {
            return .dashboardTrendWarm
        }
        return .dashboardGlowBlue
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            VStack(spacing: .SQSpace.xl) {
                VStack(spacing: .SQSpace.m) {
                    headerBadge

                    VStack(spacing: .SQSpace.s) {
                        Text(alert.title)
                            .sqFont(.title3)
                            .sqForegroundColor(.textPrimary)
                            .multilineTextAlignment(.center)

                        if let attributedSubtitle = alert.attributedSubtitle {
                            Text(attributedSubtitle)
                                .sqFont(.body)
                                .multilineTextAlignment(.center)
                        } else if let subtitle = alert.subtitle, !subtitle.isEmpty {
                            Text(subtitle)
                                .sqFont(.body)
                                .sqForegroundColor(.textSecondary)
                                .multilineTextAlignment(.center)
                        }
                    }
                }

                if let dd = alert.dropDown {
                    dropDownView(dd)
                }

                VStack(spacing: .SQSpace.m) {
                    Button(alert.primary.title) { onPrimary() }
                        .buttonStyle(SQAlertButtonStyle(role: alert.primary.role, isPrimary: true))
                        .font(SQFont(type: .body).font)

                    if let secondary = alert.secondary {
                        Button(secondary.title) { onSecondary() }
                            .buttonStyle(SQAlertButtonStyle(role: secondary.role, isPrimary: false))
                            .font(SQFont(type: .body).font)
                    }
                }
            }
            .padding(.horizontal, .SQSpace.xl)
            .padding(.vertical, .SQSpace.xxl)
            .background {
                RoundedRectangle(cornerRadius: .SQCornerRadius.xxl, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                SQColor.sheetGradientMid.color.opacity(SQColor.isDarkMode ? 0.98 : 0.96),
                                SQColor.sheetGradientEnd.color.opacity(SQColor.isDarkMode ? 0.96 : 0.94)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay {
                        RoundedRectangle(cornerRadius: .SQCornerRadius.xxl, style: .continuous)
                            .fill(SQColor.glassPopoverTint.color.opacity(SQColor.isDarkMode ? 0.30 : 0.62))
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: .SQCornerRadius.xxl, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(SQColor.isDarkMode ? 0.045 : 0.16),
                                        Color.clear
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: .SQCornerRadius.xxl, style: .continuous)
                            .stroke(SQColor.glassStrokeStrong.color.opacity(SQColor.isDarkMode ? 0.58 : 0.68), lineWidth: 1)
                    }
            }

            if alert.canDismiss {
                dismissButton
                    .padding(.top, .SQSpace.l)
                    .padding(.trailing, .SQSpace.l)
            }
        }
        .frame(maxWidth: 360)
        .padding(.horizontal, .SQSpace.xl)
        .shadow(
            color: Color.black.opacity(SQColor.isDarkMode ? 0.18 : 0.10),
            radius: 22,
            x: 0,
            y: 12
        )
    }

    private var headerBadge: some View {
        HStack(spacing: .SQSpace.xs) {
            Circle()
                .fill(headerAccentColor.color)
                .frame(width: 8, height: 8)

            Text("Notice")
                .sqFont(.bodyExtraSmall)
                .sqForegroundColor(.textSecondary)
                .textCase(.uppercase)
        }
        .padding(.horizontal, .SQSpace.m)
        .padding(.vertical, .SQSpace.xs)
        .background {
            Capsule(style: .continuous)
                .fill(headerAccentColor.color.opacity(SQColor.isDarkMode ? 0.14 : 0.12))
                .overlay {
                    Capsule(style: .continuous)
                        .stroke(SQColor.glassStroke.color, lineWidth: 1)
                }
        }
    }

    private var dismissButton: some View {
        Button { onDismiss() } label: {
            SQImageView(
                image: .init(
                    symbol: .xMark,
                    symbolStyle: .colorWithFont(.textPrimary, font: .bodyExtraSmall)
                )
            )
            .frame(width: 12, height: 12)
            .padding(10)
            .background {
                Circle()
                    .fill(SQColor.glassCardTint.color.opacity(SQColor.isDarkMode ? 0.72 : 0.92))
                    .overlay {
                        Circle()
                            .stroke(SQColor.glassStroke.color.opacity(0.8), lineWidth: 1)
                    }
            }
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func dropDownView(_ dd: SQAlertDropDownViewModel) -> some View {
        VStack(alignment: .leading, spacing: .SQSpace.s) {
            if let title = dd.title {
                Text(title)
                    .sqFont(.bodySmallBold)
                    .sqForegroundColor(.textPrimary)
            }

            SQDropDown(
                options: dd.options,
                selectedId: Binding(
                    get: { dd.selectedOptionId },
                    set: { dd.selectedOptionId = $0 }
                ),
                selectedBackgroundColor: .sheetGradientMid,
                optionsBackgroundColor: .sheetGradientEnd
            )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.SQSpace.l)
        .background {
            RoundedRectangle(cornerRadius: .SQCornerRadius.xl, style: .continuous)
                .fill(SQColor.glassCardTint.color.opacity(SQColor.isDarkMode ? 0.70 : 0.92))
                .overlay {
                    RoundedRectangle(cornerRadius: .SQCornerRadius.xl, style: .continuous)
                        .stroke(SQColor.glassStroke.color.opacity(0.72), lineWidth: 1)
                }
        }
    }
}

struct SQAlertButtonStyle: ButtonStyle {
    let role: SQAlertViewModel.Action.Role?
    let isPrimary: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 15, weight: .semibold))
            .frame(maxWidth: .infinity, minHeight: 50)
            .background(backgroundView)
            .overlay(strokeView)
            .foregroundStyle(foregroundColor)
            .clipShape(RoundedRectangle(cornerRadius: .SQCornerRadius.xl, style: .continuous))
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .opacity(configuration.isPressed ? 0.92 : 1)
    }

    private var fillColor: Color {
        switch (role, isPrimary) {
        case (.destructive, _):
            return SQColor.dashboardTrendWarm.color.opacity(SQColor.isDarkMode ? 0.22 : 0.18)
        case (_, true):
            return SQColor.dashboardGlowBlue.color.opacity(SQColor.isDarkMode ? 0.22 : 0.18)
        case (.cancel, false):
            return SQColor.glassCardTint.color.opacity(SQColor.isDarkMode ? 0.72 : 0.92)
        case (_, false):
            return SQColor.glassCardTint.color.opacity(SQColor.isDarkMode ? 0.58 : 0.84)
        }
    }

    private var foregroundColor: Color {
        switch (role, isPrimary) {
        case (.destructive, _):
            return SQColor.textPrimary.color
        case (_, true):
            return SQColor.textPrimary.color
        default:
            return SQColor.textPrimary.color
        }
    }

    private var backgroundView: some View {
        RoundedRectangle(cornerRadius: .SQCornerRadius.xl, style: .continuous)
            .fill(fillColor)
            .overlay {
                RoundedRectangle(cornerRadius: .SQCornerRadius.xl, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(SQColor.isDarkMode ? 0.045 : 0.14),
                                Color.clear
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .mask(
                        RoundedRectangle(cornerRadius: .SQCornerRadius.xl, style: .continuous)
                    )
            }
    }

    private var strokeView: some View {
        RoundedRectangle(cornerRadius: .SQCornerRadius.xl, style: .continuous)
            .stroke(strokeColor, lineWidth: 1)
    }

    private var strokeColor: Color {
        switch (role, isPrimary) {
        case (.destructive, _):
            return SQColor.dashboardTrendWarm.color.opacity(SQColor.isDarkMode ? 0.48 : 0.34)
        case (_, true):
            return SQColor.dashboardGlowBlue.color.opacity(SQColor.isDarkMode ? 0.44 : 0.32)
        default:
            return SQColor.glassStroke.color.opacity(0.78)
        }
    }
}

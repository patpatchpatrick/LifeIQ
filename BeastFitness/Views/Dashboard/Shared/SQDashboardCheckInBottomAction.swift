//
//  SQDashboardCheckInBottomAction.swift
//  BeastFitness
//
//  Created by Codex on 6/1/26.
//

import SwiftUI

struct SQDashboardCheckInBottomAction: View {
    let viewModel: SQDashboardCheckInActionViewModel

    private var isHighlighted: Bool {
        viewModel.state == .incomplete
    }

    private var accentColor: SQColor {
        switch viewModel.state {
        case .incomplete:
            return .dashboardGlowBlue
        case .complete:
            return .textSecondary
        case .guest:
            return .dashboardGlowBlue
        }
    }

    private var borderOpacity: Double {
        isHighlighted ? (SQColor.isDarkMode ? 0.34 : 0.22) : (SQColor.isDarkMode ? 0.30 : 0.20)
    }

    var body: some View {
        Button(action: viewModel.onTap) {
            HStack(spacing: .SQSpace.m) {
                ZStack(alignment: .topTrailing) {
                    Circle()
                        .fill(accentColor.color.opacity(isHighlighted ? 0.12 : 0.10))
                        .frame(width: 38, height: 38)
                        .overlay {
                            Circle()
                                .stroke(accentColor.color.opacity(borderOpacity), lineWidth: 1)
                        }

                    SQImageView(
                        image: .init(
                            symbol: viewModel.icon,
                            symbolStyle: .colorWithFont(accentColor, font: .bodySmallSemiBold)
                        )
                    )
                    .frame(width: 16, height: 16)

                    if isHighlighted {
                        Circle()
                            .fill(SQColor.dashboardTrendWarm.color)
                            .frame(width: 7, height: 7)
                            .overlay {
                                Circle()
                                    .stroke(SQColor.background.color, lineWidth: 1)
                            }
                    }
                }
                .frame(width: 38, height: 38)

                VStack(alignment: .leading, spacing: 2) {
                    Text(viewModel.title)
                        .sqFont(.bodySemiBold)
                        .sqForegroundColor(.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.82)

                    if let subtitle = viewModel.subtitle {
                        Text(subtitle)
                            .sqFont(.bodyExtraSmall)
                            .sqForegroundColor(.textTertiary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.78)
                    }
                }

                Spacer(minLength: .SQSpace.s)

                SQImageView(
                    image: .init(
                        symbol: .chevronRight,
                        symbolStyle: .colorWithFont(.textTertiary, font: .bodyExtraSmall)
                    )
                )
                .frame(width: 9, height: 9)
            }
            .padding(.horizontal, .SQSpace.l)
            .padding(.vertical, .SQSpace.m)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: .SQCornerRadius.xl, style: .continuous)
                    .fill(SQColor.dashboardGradientMid.color.opacity(SQColor.isDarkMode ? 0.92 : 0.78))
                    .overlay {
                        RoundedRectangle(cornerRadius: .SQCornerRadius.xl, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        SQColor.dashboardGlowBlue.color.opacity(isHighlighted ? 0.055 : 0.030),
                                        SQColor.dashboardGradientEnd.color.opacity(SQColor.isDarkMode ? 0.16 : 0.08)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: .SQCornerRadius.xl, style: .continuous)
                            .stroke(
                                isHighlighted
                                    ? SQColor.dashboardGlowBlue.color.opacity(borderOpacity)
                                    : SQColor.glassStroke.color.opacity(0.58),
                                lineWidth: 1
                            )
                    }
            }
            .shadow(
                color: Color.black.opacity(SQColor.isDarkMode ? 0.08 : 0.04),
                radius: isHighlighted ? 9 : 6,
                x: 0,
                y: 4
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(viewModel.title)
    }
}

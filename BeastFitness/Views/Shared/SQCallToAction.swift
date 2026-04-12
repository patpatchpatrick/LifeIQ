//
//  SQCallToAction.swift
//  BeastFitness
//
//  Created by Patrick Doyle on 11/24/25.
//

import SwiftUI

struct SQCallToAction: View {
    let viewModel: SQCallToActionViewModel

    private var accentColor: SQColor {
        viewModel.priority == .high ? .dashboardTrendWarm : .dashboardGlowBlue
    }

    private var backgroundOpacity: Double {
        viewModel.priority == .high
            ? (SQColor.isDarkMode ? 0.26 : 0.30)
            : (SQColor.isDarkMode ? 0.16 : 0.20)
    }

    private var iconFillOpacity: Double {
        viewModel.priority == .high
            ? (SQColor.isDarkMode ? 0.24 : 0.20)
            : (SQColor.isDarkMode ? 0.18 : 0.14)
    }

    @ViewBuilder
    private var cardContent: some View {
        HStack(spacing: .SQSpace.m) {
                if let icon = viewModel.icon {
                    RoundedRectangle(cornerRadius: .SQCornerRadius.m, style: .continuous)
                        .fill(accentColor.color.opacity(iconFillOpacity))
                        .frame(width: 36, height: 36)
                        .overlay {
                            RoundedRectangle(cornerRadius: .SQCornerRadius.m, style: .continuous)
                                .stroke(SQColor.glassStrokeStrong.color, lineWidth: 1)
                        }
                        .overlay {
                            SQImageView(image: icon)
                                .sqTintColor(accentColor)
                                .frame(width: 16, height: 16)
                        }
                }

                VStack(alignment: .leading, spacing: .SQSpace.xs) {
                    Text(viewModel.badgeTitle)
                        .sqFont(.bodyExtraSmall)
                        .sqForegroundColor(accentColor)
                        .padding(.horizontal, .SQSpace.s)
                        .padding(.vertical, 4)
                        .background {
                            Capsule(style: .continuous)
                                .fill(accentColor.color.opacity(viewModel.priority == .high ? (SQColor.isDarkMode ? 0.24 : 0.18) : (SQColor.isDarkMode ? 0.16 : 0.12)))
                                .overlay {
                                    Capsule(style: .continuous)
                                        .stroke(SQColor.glassStrokeStrong.color, lineWidth: 1)
                                }
                        }

                    Text(viewModel.title)
                        .sqFont(.bodyBold)
                        .sqForegroundColor(.textPrimary)

                    if let subtitle = viewModel.subtitle {
                        Text(subtitle)
                            .sqFont(.bodyExtraSmall)
                            .sqForegroundColor(.textSecondary)
                    }

                    if let actionText = viewModel.actionText {
                        Text(actionText)
                            .sqFont(.bodyExtraSmall)
                            .sqForegroundColor(.textSecondary)
                    }
                }

                Spacer(minLength: .SQSpace.m)

                if viewModel.showsChevron {
                    Circle()
                        .fill(accentColor.color.opacity(viewModel.priority == .high ? (SQColor.isDarkMode ? 0.22 : 0.18) : (SQColor.isDarkMode ? 0.16 : 0.12)))
                        .frame(width: 30, height: 30)
                        .overlay {
                            Circle()
                                .stroke(SQColor.glassStrokeStrong.color, lineWidth: 1)
                        }
                        .overlay {
                                SQImageView(image: .init(symbol: .chevronRight, symbolStyle: .colorWithFont(.textSecondary, font: .bodyExtraSmall)))
                                    .sqTintColor(accentColor)
                                    .frame(width: 10, height: 10)
                        }
                }
            }
            .padding(.horizontal, .SQSpace.l)
            .padding(.vertical, .SQSpace.m)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: .SQCornerRadius.l, style: .continuous)
                    .fill(accentColor.color.opacity(backgroundOpacity))
                    .overlay {
                        RoundedRectangle(cornerRadius: .SQCornerRadius.l, style: .continuous)
                            .stroke(
                                accentColor.color.opacity(viewModel.priority == .high ? (SQColor.isDarkMode ? 0.55 : 0.30) : (SQColor.isDarkMode ? 0.32 : 0.18)),
                                lineWidth: 1
                            )
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: .SQCornerRadius.l, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(viewModel.priority == .high ? (SQColor.isDarkMode ? 0.18 : 0.24) : (SQColor.isDarkMode ? 0.14 : 0.20)),
                                        Color.clear
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    }
            }
            .sqGlassSurface(level: .floating, cornerRadius: .SQCornerRadius.l)
            .shadow(
                color: accentColor.color.opacity(viewModel.priority == .high ? (SQColor.isDarkMode ? 0.34 : 0.22) : (SQColor.isDarkMode ? 0.24 : 0.16)),
                radius: viewModel.priority == .high ? 30 : 24,
                x: 0,
                y: 12
            )
        }

    var body: some View {
        Group {
            if let onTap = viewModel.onTap {
                Button(action: onTap) {
                    cardContent
                }
                .buttonStyle(.plain)
            } else {
                cardContent
            }
        }
    }
}

struct SQCallToActionViewModel {
    enum Priority {
        case standard
        case high
    }

    let icon: SQImage?
    let priority: Priority
    let badgeTitle: String
    let title: String
    let subtitle: String?
    let actionText: String?
    let onTap: (() -> Void)?
    let showsChevron: Bool

    init(
        icon: SQImage? = nil,
        priority: Priority = .standard,
        badgeTitle: String = "Action Needed",
        title: String,
        subtitle: String? = nil,
        actionText: String? = "Tap to log now",
        onTap: (() -> Void)?,
        showsChevron: Bool = true
    ) {
        self.icon = icon
        self.priority = priority
        self.badgeTitle = badgeTitle
        self.title = title
        self.subtitle = subtitle
        self.actionText = actionText
        self.onTap = onTap
        self.showsChevron = showsChevron
    }
}

#Preview {
    VStack(spacing: .SQSpace.l) {
        // With icon
        SQCallToAction(viewModel: .init(
            icon: .init(symbol: .checkmark),
            title: "Complete daily check-in",
            onTap: nil
        ))

        // Without icon
        SQCallToAction(viewModel: .init(
            title: "Another action",
            onTap: nil
        ))
    }
    .padding()
    .preferredColorScheme(.dark)
}

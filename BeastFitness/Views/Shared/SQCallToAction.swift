//
//  SQCallToAction.swift
//  BeastFitness
//
//  Created by Patrick Doyle on 11/24/25.
//

import SwiftUI

struct SQCallToAction: View {
    let viewModel: SQCallToActionViewModel

    var body: some View {
        Button(action: { viewModel.onTap?() }) {
            HStack(spacing: .SQSpace.m) {
                if let icon = viewModel.icon {
                    RoundedRectangle(cornerRadius: .SQCornerRadius.m, style: .continuous)
                        .fill(SQColor.dashboardGlowBlue.color.opacity(SQColor.isDarkMode ? 0.18 : 0.14))
                        .frame(width: 36, height: 36)
                        .overlay {
                            RoundedRectangle(cornerRadius: .SQCornerRadius.m, style: .continuous)
                                .stroke(SQColor.glassStrokeStrong.color, lineWidth: 1)
                        }
                        .overlay {
                            SQImageView(image: icon)
                                .sqTintColor(.dashboardGlowBlue)
                                .frame(width: 16, height: 16)
                        }
                }

                VStack(alignment: .leading, spacing: .SQSpace.xs) {
                    Text("Action Needed")
                        .sqFont(.bodyExtraSmall)
                        .sqForegroundColor(.dashboardGlowBlue)
                        .padding(.horizontal, .SQSpace.s)
                        .padding(.vertical, 4)
                        .background {
                            Capsule(style: .continuous)
                                .fill(SQColor.dashboardGlowBlue.color.opacity(SQColor.isDarkMode ? 0.16 : 0.12))
                                .overlay {
                                    Capsule(style: .continuous)
                                        .stroke(SQColor.glassStrokeStrong.color, lineWidth: 1)
                                }
                        }

                    Text(viewModel.title)
                        .sqFont(.bodyBold)
                        .sqForegroundColor(.textPrimary)

                    Text("Tap to log now")
                        .sqFont(.bodyExtraSmall)
                        .sqForegroundColor(.textSecondary)
                }

                Spacer(minLength: .SQSpace.m)

                Circle()
                    .fill(SQColor.dashboardGlowBlue.color.opacity(SQColor.isDarkMode ? 0.16 : 0.12))
                    .frame(width: 30, height: 30)
                    .overlay {
                        Circle()
                            .stroke(SQColor.glassStrokeStrong.color, lineWidth: 1)
                    }
                    .overlay {
                            SQImageView(image: .init(symbol: .chevronRight, symbolStyle: .colorWithFont(.textSecondary, font: .bodyExtraSmall)))
                                .sqTintColor(.dashboardGlowBlue)
                                .frame(width: 10, height: 10)
                    }
            }
            .padding(.horizontal, .SQSpace.l)
            .padding(.vertical, .SQSpace.m)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: .SQCornerRadius.l, style: .continuous)
                    .fill(SQColor.dashboardGlowBlue.color.opacity(SQColor.isDarkMode ? 0.16 : 0.20))
                    .overlay {
                        RoundedRectangle(cornerRadius: .SQCornerRadius.l, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(SQColor.isDarkMode ? 0.14 : 0.20),
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
                color: SQColor.dashboardGlowBlue.color.opacity(SQColor.isDarkMode ? 0.24 : 0.16),
                radius: 24,
                x: 0,
                y: 12
            )
        }
        .buttonStyle(.plain)
    }
}

struct SQCallToActionViewModel {
    let icon: SQImage?
    let title: String
    let onTap: (() -> Void)?

    init(icon: SQImage? = nil, title: String, onTap: (() -> Void)?) {
        self.icon = icon
        self.title = title
        self.onTap = onTap
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

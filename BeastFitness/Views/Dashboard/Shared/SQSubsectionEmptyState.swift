//
//  SQSubsectionEmptyState.swift
//  BeastFitness
//

import SwiftUI

struct SQSubsectionEmptyState: View {
    let title: String
    let subtitle: String?
    let icon: SQImageSymbol
    let onTap: (() -> Void)?

    init(message: String, icon: SQImageSymbol = .exclamationmarkCircle) {
        self.title = message
        self.subtitle = nil
        self.icon = icon
        self.onTap = nil
    }

    init(viewModel: SQDashboardSubsectionViewModel.EmptyStateViewModel) {
        self.title = viewModel.title
        self.subtitle = viewModel.subtitle
        self.icon = viewModel.icon
        self.onTap = viewModel.onTap
    }

    var body: some View {
        Group {
            if let onTap {
                Button(action: onTap) {
                    actionContent
                }
                .buttonStyle(.plain)
            } else {
                defaultContent
            }
        }
    }

    private var defaultContent: some View {
        VStack(spacing: .SQSpace.m) {
            SQImageView(image: .init(
                symbol: icon,
                symbolStyle: .colorWithFont(.textSecondary, font: .body)
            ))
            .frame(width: 25, height: 25)

            Text(title)
                .sqFont(.body)
                .sqForegroundColor(.textSecondary)
                .multilineTextAlignment(.center)

            if let subtitle {
                Text(subtitle)
                    .sqFont(.bodyExtraSmall)
                    .sqForegroundColor(.textSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.vertical, 32)
        .frame(maxWidth: .infinity)
    }

    private var actionContent: some View {
        HStack(spacing: .SQSpace.m) {
            RoundedRectangle(cornerRadius: .SQCornerRadius.m, style: .continuous)
                .fill(SQColor.dashboardGlowBlue.color.opacity(SQColor.isDarkMode ? 0.18 : 0.14))
                .frame(width: 38, height: 38)
                .overlay {
                    RoundedRectangle(cornerRadius: .SQCornerRadius.m, style: .continuous)
                        .stroke(SQColor.glassStrokeStrong.color, lineWidth: 1)
                }
                .overlay {
                    SQImageView(image: .init(
                        symbol: icon,
                        symbolStyle: .colorWithFont(.dashboardGlowBlue, font: .bodySmallSemiBold)
                    ))
                    .frame(width: 18, height: 18)
                }

            VStack(alignment: .leading, spacing: .SQSpace.xs) {
                Text("Action Needed")
                    .sqFont(.bodyExtraSmall)
                    .sqForegroundColor(.dashboardGlowBlue)
                    .padding(.horizontal, .SQSpace.s)
                    .padding(.vertical, 4)
                    .background {
                        Capsule(style: .continuous)
                            .fill(SQColor.dashboardGlowBlue.color.opacity(SQColor.isDarkMode ? 0.14 : 0.10))
                            .overlay {
                                Capsule(style: .continuous)
                                    .stroke(SQColor.glassStrokeStrong.color, lineWidth: 1)
                            }
                    }

                Text(title)
                    .sqFont(.bodySemiBold)
                    .sqForegroundColor(.textPrimary)
                    .multilineTextAlignment(.leading)

                if let subtitle {
                    Text(subtitle)
                        .sqFont(.bodyExtraSmall)
                        .sqForegroundColor(.textSecondary)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
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
                    SQImageView(image: .init(
                        symbol: .chevronRight,
                        symbolStyle: .colorWithFont(.dashboardGlowBlue, font: .bodyExtraSmall)
                    ))
                    .frame(width: 10, height: 10)
                }
        }
        .padding(.horizontal, .SQSpace.l)
        .padding(.vertical, .SQSpace.m)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: .SQCornerRadius.l, style: .continuous)
                .fill(SQColor.dashboardGlowBlue.color.opacity(SQColor.isDarkMode ? 0.12 : 0.16))
                .overlay {
                    RoundedRectangle(cornerRadius: .SQCornerRadius.l, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(SQColor.isDarkMode ? 0.10 : 0.16),
                                    Color.clear
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
        }
        .sqGlassSurface(level: .card, cornerRadius: .SQCornerRadius.l)
        .padding(.vertical, .SQSpace.s)
    }
}

#Preview {
    SQSubsectionEmptyState(message: "No metrics in this group")
        .sqBackgroundColor(.background)
}

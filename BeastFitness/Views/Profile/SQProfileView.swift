//
//  SQProfileView.swift
//  BeastFitness
//
//  Created by Patrick Doyle on 3/18/26.
//

import SwiftUI

struct SQProfileView: View {
    @State var controller: SQProfileController

    @ViewBuilder
    private func glassActionButton(
        title: String,
        isPrimary: Bool = false,
        isDisabled: Bool = false,
        isLoading: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            ZStack {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint((isPrimary ? SQColor.dashboardGlowBlueForeground : .textPrimary).color)
                } else {
                    Text(title)
                        .sqFont(.bodySmallSemiBold)
                        .sqForegroundColor(isPrimary ? .dashboardGlowBlueForeground : .textPrimary)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, .SQSpace.m)
            .background(
                RoundedRectangle(cornerRadius: .SQCornerRadius.xl, style: .continuous)
                    .fill(
                        isPrimary
                            ? SQColor.dashboardGlowBlue.color.opacity(SQColor.isDarkMode ? 0.88 : 0.72)
                            : SQColor.glassCardTint.color.opacity(SQColor.isDarkMode ? 0.82 : 0.96)
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: .SQCornerRadius.xl, style: .continuous)
                    .stroke(
                        isPrimary
                            ? SQColor.dashboardGlowBlue.color.opacity(0.44)
                            : SQColor.glassStroke.color,
                        lineWidth: 1
                    )
            )
        }
        .buttonStyle(.plain)
        .disabled(isDisabled || isLoading)
        .opacity(isDisabled ? 0.5 : 1)
    }

    @ViewBuilder
    private var heroCard: some View {
        VStack(spacing: .SQSpace.m) {
            ZStack {
                Circle()
                    .fill(SQColor.glassCardTint.color.opacity(SQColor.isDarkMode ? 0.86 : 0.96))
                    .overlay(
                        Circle()
                            .stroke(SQColor.glassStroke.color, lineWidth: 1)
                    )
                    .frame(width: 78, height: 78)

                SQImageView(
                    image: .init(
                        symbol: .personCircleFill,
                        symbolStyle: .colorWithFont(.textPrimary, font: .title2)
                    )
                )
                .frame(width: 34, height: 34)
            }

            VStack(spacing: .SQSpace.xs) {
                Text(controller.subtitle)
                    .sqFont(.title4)
                    .sqForegroundColor(.textPrimary)

                if let detailText = controller.detailText {
                    Text(detailText)
                        .sqFont(.bodyExtraSmall)
                        .sqForegroundColor(.textSecondary)
                }
            }

            SQDashboardTrendBadge(text: controller.statusTitle, tone: .neutral, symbol: nil)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, .SQSpace.xl)
        .sqGlassSurface(level: .card, cornerRadius: .SQCornerRadius.xl)
    }

    @ViewBuilder
    private func actionRow(title: String, subtitle: String? = nil, symbol: SQImageSymbol, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: .SQSpace.m) {
                RoundedRectangle(cornerRadius: .SQCornerRadius.l, style: .continuous)
                    .fill(SQColor.glassCardTint.color.opacity(SQColor.isDarkMode ? 0.84 : 0.96))
                    .frame(width: 38, height: 38)
                    .overlay(
                        RoundedRectangle(cornerRadius: .SQCornerRadius.l, style: .continuous)
                            .stroke(SQColor.glassStroke.color, lineWidth: 1)
                    )
                    .overlay(
                        SQImageView(
                            image: .init(
                                symbol: symbol,
                                symbolStyle: .colorWithFont(.textPrimary, font: .bodySmall)
                            )
                        )
                        .frame(width: 14, height: 14)
                    )

                VStack(alignment: .leading, spacing: .SQSpace.xs) {
                    Text(title)
                        .sqFont(.bodySemiBold)
                        .sqForegroundColor(.textPrimary)

                    if let subtitle {
                        Text(subtitle)
                            .sqFont(.bodyExtraSmall)
                            .sqForegroundColor(.textSecondary)
                    }
                }

                Spacer(minLength: .SQSpace.m)

                SQImageView(
                    image: .init(
                        symbol: .chevronRight,
                        symbolStyle: .colorWithFont(.textTertiary, font: .bodyExtraSmall)
                    )
                )
                .frame(width: 8, height: 12)
            }
            .padding(.horizontal, .SQSpace.l)
            .padding(.vertical, .SQSpace.l)
            .sqGlassSurface(level: .card, cornerRadius: .SQCornerRadius.xl)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var authCard: some View {
        if controller.loginButtonViewModel != nil || controller.signUpButtonViewModel != nil {
            VStack(alignment: .leading, spacing: .SQSpace.m) {
                Text("Account")
                    .sqFont(.title4)
                    .sqForegroundColor(.textPrimary)

                Text("Log in to sync your data and personalize your dashboard.")
                    .sqFont(.bodyExtraSmall)
                    .sqForegroundColor(.textSecondary)

                HStack(spacing: .SQSpace.s) {
                    if let vm = controller.loginButtonViewModel {
                        glassActionButton(
                            title: vm.title,
                            isPrimary: true,
                            isDisabled: controller.isLoggingOut
                        ) {
                            vm.tapped()
                        }
                    }

                    if let vm = controller.signUpButtonViewModel {
                        glassActionButton(
                            title: vm.title,
                            isDisabled: controller.isLoggingOut
                        ) {
                            vm.tapped()
                        }
                    }
                }
            }
            .padding(.SQSpace.l)
            .sqGlassSurface(level: .card, cornerRadius: .SQCornerRadius.xl)
            .opacity(controller.isLoggingOut ? 0.5 : 1)
        }
    }

    @ViewBuilder
    private var actionsSection: some View {
        VStack(alignment: .leading, spacing: .SQSpace.s) {
            Text("Actions")
                .sqFont(.headerSmall)
                .sqForegroundColor(.textSecondary)
                .padding(.horizontal, .SQSpace.xs)

            actionRow(
                title: "Settings",
                subtitle: "Preferences, hidden workouts, and advanced options.",
                symbol: .gear
            ) {
                controller.settingsTapped()
            }

            if let vm = controller.logOutButtonViewModel {
                glassActionButton(
                    title: vm.title,
                    isDisabled: controller.isLoggingOut,
                    isLoading: controller.isLoggingOut
                ) {
                    vm.tapped()
                }
                .padding(.top, .SQSpace.m)
            }
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: .SQSpace.l) {
                heroCard
                authCard
                actionsSection
            }
            .padding(.horizontal, .SQSpace.l)
            .padding(.top, .SQSpace.l)
            .padding(.bottom, .SQSpace.xl)
            .frame(maxWidth: .infinity)
        }
        .navigationTitle(controller.title)
        .navigationBarTitleDisplayMode(.inline)
        .background {
            SQSheetBackground()
        }
    }
}

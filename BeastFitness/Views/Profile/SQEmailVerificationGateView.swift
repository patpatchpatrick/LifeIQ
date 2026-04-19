//
//  SQEmailVerificationGateView.swift
//  BeastFitness
//
//  Created by Codex on 4/19/26.
//

import SwiftUI

struct SQEmailVerificationGateView: View {
    @Bindable var controller: SQEmailVerificationController

    var body: some View {
        ZStack {
            Color.black.opacity(SQColor.isDarkMode ? 0.52 : 0.24)
                .ignoresSafeArea()

            VStack(spacing: .SQSpace.l) {
                Circle()
                    .fill(SQColor.dashboardGlowBlue.color.opacity(SQColor.isDarkMode ? 0.20 : 0.14))
                    .frame(width: 78, height: 78)
                    .overlay {
                        Circle()
                            .stroke(SQColor.glassStrokeStrong.color, lineWidth: 1)
                    }
                    .overlay {
                        SQImageView(
                            image: .init(
                                symbol: .infoCircle,
                                symbolStyle: .colorWithFont(.dashboardGlowBlue, font: .title3)
                            )
                        )
                        .frame(width: 26, height: 26)
                    }

                VStack(spacing: .SQSpace.s) {
                    Text(controller.title)
                        .sqFont(.title3)
                        .sqForegroundColor(.textPrimary)

                    Text(controller.subtitle)
                        .sqFont(.bodySmall)
                        .sqForegroundColor(.textSecondary)
                        .multilineTextAlignment(.center)
                }

                VStack(spacing: .SQSpace.m) {
                    SQButton(
                        style: .glassPrimary,
                        shouldHugContent: false,
                        title: "I've Verified My Email",
                        isLoading: controller.isRefreshingStatus
                    ) {
                        controller.refreshStatusTapped()
                    }

                    SQButton(
                        style: .secondary,
                        shouldHugContent: false,
                        title: controller.resendButtonTitle,
                        isDisabled: controller.isResendDisabled,
                        isLoading: controller.isResendingEmail
                    ) {
                        controller.resendEmailTapped()
                    }

                    if let resendHelperText = controller.resendHelperText {
                        Text(resendHelperText)
                            .sqFont(.bodyExtraSmall)
                            .sqForegroundColor(.textSecondary)
                            .multilineTextAlignment(.center)
                    }

                    Button(action: controller.logOutTapped) {
                        Text(controller.isLoggingOut ? "Logging out..." : "Log Out")
                            .sqFont(.bodySmallSemiBold)
                            .sqForegroundColor(.textSecondary)
                    }
                    .buttonStyle(.plain)
                    .disabled(controller.isLoggingOut)
                    .opacity(controller.isLoggingOut ? 0.6 : 1)
                }
            }
            .padding(.SQSpace.xl)
            .frame(maxWidth: 420)
            .sqGlassSurface(level: .floating, cornerRadius: .SQCornerRadius.xl)
            .padding(.horizontal, .SQSpace.l)
        }
        .transition(.opacity)
    }
}

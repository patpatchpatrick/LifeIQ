//
//  SQLoginView.swift
//  BeastFitness
//
//  Created by Patrick Doyle on 3/18/26.
//

import SwiftUI
import GoogleSignInSwift

struct SQLoginView: View {
    @State var controller: SQLoginController

    private var heroSubtitle: String {
        switch controller.mode {
        case .login:
            return "Access your account to sync data and keep your dashboard personalized."
        case .signup:
            return "Create an account to save your progress and sync your health and workout data."
        }
    }

    private var alternatePrompt: String {
        switch controller.mode {
        case .login:
            return "Need an account?"
        case .signup:
            return "Already have an account?"
        }
    }

    @ViewBuilder
    private var signupDisabledNoticeCard: some View {
        if let signupDisabledMessage = controller.signupDisabledMessage {
            SQCallToAction(
                viewModel: .init(
                    icon: .init(symbol: .exclamationmarkTriangleFill),
                    priority: .high,
                    badgeTitle: "Signups Unavailable",
                    title: "New account creation is temporarily unavailable",
                    subtitle: signupDisabledMessage,
                    actionText: nil,
                    onTap: nil,
                    showsChevron: false
                )
            )
        }
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
                Text(controller.title)
                    .sqFont(.title2)
                    .sqForegroundColor(.textPrimary)

                Text(heroSubtitle)
                    .sqFont(.bodyExtraSmall)
                    .sqForegroundColor(.textSecondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, .SQSpace.xl)
        .sqGlassSurface(level: .card, cornerRadius: .SQCornerRadius.xl)
    }

    @ViewBuilder
    private var formCard: some View {
        VStack(alignment: .leading, spacing: .SQSpace.m) {
            Text("Credentials")
                .sqFont(.title4)
                .sqForegroundColor(.textPrimary)

            VStack(spacing: .SQSpace.m) {
                SQUITextField(viewModel: controller.emailViewModel)
                SQUITextField(viewModel: controller.passwordViewModel)
            }

            Text(controller.mode == .signup ? "Use at least 8 characters with upper, lower, and a number." : "Enter the email and password tied to your account.")
                .sqFont(.bodyExtraSmall)
                .sqForegroundColor(.textSecondary)
        }
        .padding(.SQSpace.l)
        .sqGlassSurface(level: .card, cornerRadius: .SQCornerRadius.xl)
    }

    @ViewBuilder
    private var socialAuthCard: some View {
        VStack(alignment: .leading, spacing: .SQSpace.m) {
            Text("Continue With")
                .sqFont(.title4)
                .sqForegroundColor(.textPrimary)

            Text("Use a connected account for a faster sign-in flow.")
                .sqFont(.bodyExtraSmall)
                .sqForegroundColor(.textSecondary)

            GoogleSignInButton(
                scheme: SQColor.isDarkMode ? .dark : .light,
                style: .wide,
                state: controller.isLoading ? .disabled : .normal
            ) {
                controller.googleButtonTapped()
            }
            .frame(height: 50)
            .clipShape(RoundedRectangle(cornerRadius: .SQCornerRadius.xl, style: .continuous))
            .buttonStyle(.plain)
            .background(Color.clear)
            .shadow(color: .clear, radius: 0)
        }
        .padding(.SQSpace.l)
        .sqGlassSurface(level: .card, cornerRadius: .SQCornerRadius.xl)
    }

    @ViewBuilder
    private var alternateModeRow: some View {
        if !controller.isSignupDisabled {
            HStack(spacing: .SQSpace.xs) {
                Text(alternatePrompt)
                    .sqFont(.bodySmall)
                    .sqForegroundColor(.textSecondary)

                Button(action: controller.toggleMode) {
                    Text(controller.mode.toggleTitle)
                        .sqFont(.bodySmallSemiBold)
                        .sqForegroundColor(.textPrimary)
                }
                .buttonStyle(.plain)
            }
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.top, .SQSpace.xs)
        }
    }

    @ViewBuilder
    private var privacyPolicyFooter: some View {
        VStack(spacing: .SQSpace.xs) {
            Text("Review how LifeIQ handles your data before continuing.")
                .sqFont(.bodyExtraSmall)
                .sqForegroundColor(.textSecondary)
                .multilineTextAlignment(.center)

            Button(action: controller.openPrivacyPolicy) {
                Text("Privacy Policy")
                    .underline()
                    .sqFont(.bodySmallSemiBold)
                    .sqForegroundColor(.textPrimary)
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private var bottomAction: some View {
        VStack(spacing: .SQSpace.s) {
            SQButton(
                style: .glassPrimary,
                shouldHugContent: false,
                title: controller.title,
                isLoading: controller.isLoading
            ) {
                controller.loginOrSignUpButtonTapped()
            }
            .padding(.horizontal, .SQSpace.xl)

            alternateModeRow

            privacyPolicyFooter
        }
        .padding(.bottom, .SQSpace.l)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: .SQSpace.l) {
                heroCard
                signupDisabledNoticeCard
                formCard
                socialAuthCard
            }
            .padding(.horizontal, .SQSpace.l)
            .padding(.top, .SQSpace.l)
            .padding(.bottom, .SQSpace.xl)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .navigationTitle(controller.title)
        .navigationBarTitleDisplayMode(.inline)
        .disabled(controller.isLoading)
        .opacity(controller.isLoading ? 0.6 : 1)
        .background {
            SQSheetBackground()
        }
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 0) {
                Divider()
                    .sqTintColor(.glassStroke)

                bottomAction
            }
            .background(.ultraThinMaterial)
        }
    }
}

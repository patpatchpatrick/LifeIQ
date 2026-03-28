//
//  SQLoginView.swift
//  BeastFitness
//
//  Created by Patrick Doyle on 3/18/26.
//

import SwiftUI

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
    private var alternateModeRow: some View {
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
                .padding(.bottom, .SQSpace.l)
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: .SQSpace.l) {
                heroCard
                formCard
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

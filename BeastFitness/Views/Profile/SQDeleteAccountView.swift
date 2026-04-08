//
//  SQDeleteAccountView.swift
//  BeastFitness
//
//  Created by OpenAI on 4/7/26.
//

import SwiftUI
import SwiftData
import GoogleSignInSwift

struct SQDeleteAccountView: View {
    @State var controller: SQDeleteAccountController
    @Environment(\.modelContext) private var modelContext

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
                        symbol: .trash,
                        symbolStyle: .colorWithFont(.textPrimary, font: .title2)
                    )
                )
                .frame(width: 30, height: 30)
            }

            VStack(spacing: .SQSpace.xs) {
                Text("Delete Account")
                    .sqFont(.title3)
                    .sqForegroundColor(.textPrimary)

                Text("Permanently remove your LifeIQ account and app-managed data. This action cannot be undone.")
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
    private var impactCard: some View {
        VStack(alignment: .leading, spacing: .SQSpace.m) {
            Text("What gets deleted")
                .sqFont(.title4)
                .sqForegroundColor(.textPrimary)

            bulletRow("Your LifeIQ account and profile")
            bulletRow("Cloud check-ins, custom metrics, metric entries, and workout metadata")
            bulletRow("Local app data on this device, including cached workouts and preferences")

            Divider()
                .sqTintColor(.glassStroke)

            bulletRow("Apple Health data stays in the Health app and is not deleted here")
            bulletRow("App Store subscriptions, if any, must be managed separately in Apple settings")
        }
        .padding(.SQSpace.l)
        .sqGlassSurface(level: .card, cornerRadius: .SQCornerRadius.xl)
    }

    @ViewBuilder
    private var passwordCard: some View {
        if controller.supportsPasswordConfirmation {
            VStack(alignment: .leading, spacing: .SQSpace.m) {
                Text("Confirm with password")
                    .sqFont(.title4)
                    .sqForegroundColor(.textPrimary)

                if !controller.email.isEmpty {
                    Text(controller.email)
                        .sqFont(.bodyExtraSmall)
                        .sqForegroundColor(.textSecondary)
                }

                SQUITextField(viewModel: controller.passwordViewModel)

                destructiveButton(
                    title: "Delete Account With Password",
                    isLoading: controller.isLoading
                ) {
                    controller.deleteWithPassword(modelContext: modelContext)
                }
            }
            .padding(.SQSpace.l)
            .sqGlassSurface(level: .card, cornerRadius: .SQCornerRadius.xl)
        }
    }

    @ViewBuilder
    private var googleCard: some View {
        if controller.supportsGoogleConfirmation {
            VStack(alignment: .leading, spacing: .SQSpace.m) {
                Text("Confirm with Google")
                    .sqFont(.title4)
                    .sqForegroundColor(.textPrimary)

                Text("You’ll re-authenticate with Google before the account is deleted.")
                    .sqFont(.bodyExtraSmall)
                    .sqForegroundColor(.textSecondary)

                GoogleSignInButton(
                    scheme: SQColor.isDarkMode ? .dark : .light,
                    style: .wide,
                    state: controller.isLoading ? .disabled : .normal
                ) {
                    controller.deleteWithGoogle(modelContext: modelContext)
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
    }

    private func bulletRow(_ text: String) -> some View {
        HStack(alignment: .top, spacing: .SQSpace.s) {
            Circle()
                .fill(SQColor.dashboardTrendWarm.color.opacity(SQColor.isDarkMode ? 0.88 : 0.72))
                .frame(width: 7, height: 7)
                .padding(.top, 6)

            Text(text)
                .sqFont(.bodyExtraSmall)
                .sqForegroundColor(.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func destructiveButton(
        title: String,
        isLoading: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            ZStack {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(SQColor.textPrimary.color)
                } else {
                    Text(title)
                        .sqFont(.bodySmallSemiBold)
                        .sqForegroundColor(.textPrimary)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, .SQSpace.m)
            .background(
                RoundedRectangle(cornerRadius: .SQCornerRadius.xl, style: .continuous)
                    .fill(SQColor.dashboardTrendWarm.color.opacity(SQColor.isDarkMode ? 0.32 : 0.22))
            )
            .overlay(
                RoundedRectangle(cornerRadius: .SQCornerRadius.xl, style: .continuous)
                    .stroke(SQColor.glassStrokeStrong.color, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .disabled(isLoading)
        .opacity(isLoading ? 0.65 : 1)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: .SQSpace.l) {
                heroCard
                impactCard
                passwordCard
                googleCard
            }
            .padding(.horizontal, .SQSpace.l)
            .padding(.top, .SQSpace.l)
            .padding(.bottom, .SQSpace.xl)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .navigationTitle(controller.title)
        .navigationBarTitleDisplayMode(.inline)
        .background {
            SQSheetBackground()
        }
        .disabled(controller.isLoading)
        .opacity(controller.isLoading ? 0.7 : 1)
        .onAppear {
            controller.refreshProviders()
        }
    }
}

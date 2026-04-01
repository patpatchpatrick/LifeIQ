//
//  SQDashboardView.swift
//  BeastFitness
//
//  Created by Patrick Doyle on 11/11/25.
//

import SwiftUI

struct SQDashboardView: View {
    @Bindable var controller: SQDashboardController
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.modelContext) private var modelContext
    @State private var shouldRefreshOnNextActive = false
    static let uiConfig = UIConfig()

    private var shouldShowDashboardErrorState: Bool {
        !controller.state.isLoading && controller.state.availableLayoutGroups.isEmpty
    }

    var mainScroll: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Dashboard controls
                ZStack {
                    HStack {
                        SQDropDownMenu(
                            menuViewModel: controller.timeRangeMenuViewModel,
                            isDisabled: false
                        )

                        Spacer()

                        HStack(spacing: .SQSpace.m) {
                            Button {
                                controller.handleLayoutButtonTap()
                            } label: {
                                SQImageView(
                                    image: .init(
                                        symbol: .sliderHorizontal3,
                                        symbolStyle: .colorWithFont(.textPrimary, font: .body)
                                    )
                                )
                                .frame(width: 20, height: 20)
                            }
                            .accessibilityLabel("Customize dashboard")

                            Button {
                                controller.handleAuthButtonTap()
                            } label: {
                                if let user = controller.userState.loggedInUser {
                                    SQUserIcon(user: user, size: 30)
                                } else {
                                    SQImageView(
                                        image: .init(
                                            symbol: controller.authButtonSymbol,
                                            symbolStyle: .colorWithFont(.textPrimary, font: .body)
                                        )
                                    )
                                    .frame(width: 28, height: 28)
                                }
                            }
                            .accessibilityLabel(controller.userState.isLoggedIn ? "Profile" : "Sign in")
                        }
                    }

                    Text("LifeIQ")
                        .font(SQFont.brandFont(.wordmark))
                        .sqForegroundColor(.textPrimary)
                        .tracking(1.2)
                        .opacity(SQColor.isDarkMode ? 0.24 : 0.18)
                }
                .padding(.horizontal, 16)
                .padding(.top, 10)
                .padding(.bottom, 10)

                if let lifeScoreViewModel = controller.lifeScoreViewModel {
                    Button {
                        controller.handleLifeScoreTap()
                    } label: {
                        SQLifeScoreHeroCard(viewModel: lifeScoreViewModel)
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)
                    .accessibilityLabel(lifeScoreViewModel.accessibilityLabel)
                }

                // Daily Check-In CTA Banner - hide while loading
                if !controller.state.isLoading,
                   let dailyCheckInCtaViewModel = controller.state.dailyCheckInCtaViewModel {
                    SQCallToAction(viewModel: dailyCheckInCtaViewModel)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 16)
                }

                if shouldShowDashboardErrorState {
                    SQSubsectionEmptyState(
                        viewModel: .init(
                            title: "Dashboard data couldn't load",
                            subtitle: "Something went wrong while loading your dashboard. Open the Health app, tap your profile picture, then go to Apps > LifeIQ and make sure Health access is enabled. After that, pull to refresh and try again.",
                            icon: .exclamationmarkTriangle,
                            onTap: nil
                        )
                    )
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                } else {
                    // Main sections - always rendered so mock data shows as a redacted skeleton
                    LazyVStack(spacing: 0, pinnedViews: [.sectionHeaders]) {
                        ForEach(controller.state.sectionGroups) { sectionGroup in
                            SQDashboardSectionGroupView(sectionGroup: sectionGroup)
                        }
                    }
                }

                Spacer()
            }
        }
        .refreshable {
            await controller.refreshUI(for: modelContext)
        }
    }

    var body: some View {
        ZStack {
            SQDashboardBackground()

            mainScroll
        }
            .navigationBarTitleDisplayMode(.inline)
            .redacted(controller.state.isLoading, reason: .placeholder)
            .disabled(controller.state.isLoading)
            .task {
                await controller.loadUI(for: modelContext)
            }
            .onChange(of: scenePhase) { _, newPhase in
                switch newPhase {
                case .background:
                    shouldRefreshOnNextActive = true
                case .active:
                    guard shouldRefreshOnNextActive, controller.hasLoadedUI else { return }
                    shouldRefreshOnNextActive = false
                    Task {
                        await controller.refreshUI(for: modelContext)
                    }
                case .inactive:
                    break
                @unknown default:
                    break
                }
            }
            .sheet(isPresented: .init(
                get: { controller.state.isDailyCheckInSheetVisible },
                set: { isVisible in controller.state.toggleDailyCheckInSheetVisibility(isVisible) })) {
                    if let dailyCheckInViewModel = controller.state.dailyCheckInViewModel {
                        SQDailyCheckInView(viewModel: dailyCheckInViewModel)
                    }
                }
    }
}

private struct SQLifeScoreHeroCard: View {
    let viewModel: SQLifeScoreViewModel

    var body: some View {
        VStack(spacing: .SQSpace.m) {
            SQLifeScoreOrbView(viewModel: viewModel, size: 156, scoreFont: .title1)

            VStack(spacing: .SQSpace.xs) {
                HStack(alignment: .firstTextBaseline, spacing: .SQSpace.s) {
                    Text("Life Score")
                        .sqFont(.bodyExtraSmall)
                        .sqForegroundColor(.textSecondary)

                    if let score = viewModel.score {
                        Text("\(score)/100")
                            .sqFont(.bodySmallSemiBold)
                            .sqForegroundColor(.textSecondary)
                    }
                }

                Text(viewModel.state.title)
                    .sqFont(.title3)
                    .sqForegroundColor(.textPrimary)

                Text(viewModel.subtitle)
                    .sqFont(.bodyExtraSmall)
                    .sqForegroundColor(.textSecondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 260)

                Text("Tap for breakdown")
                    .sqFont(.bodyExtraSmall)
                    .sqForegroundColor(.textPrimary)
                    .opacity(0.7)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 8)
        .padding(.bottom, 20)
    }
}

private struct SQLifeScoreOrbView: View {
    let viewModel: SQLifeScoreViewModel
    let size: CGFloat
    let scoreFont: SQFont.FontType

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isAnimating = false

    private var outerGlowSize: CGFloat { size * 0.92 }
    private var orbSize: CGFloat { size * 0.68 }
    private var highlightSize: CGFloat { max(10, size * 0.12) }

    var body: some View {
        ZStack {
            Circle()
                .stroke(viewModel.state.primaryColor.color.opacity(SQColor.isDarkMode ? 0.36 : 0.22), lineWidth: size * 0.11)
                .frame(width: outerGlowSize, height: outerGlowSize)
                .blur(radius: isAnimating ? size * 0.10 : size * 0.06)
                .scaleEffect(isAnimating ? 1.04 : 0.98)
                .opacity(isAnimating ? 0.96 : 0.78)
                .shadow(
                    color: viewModel.state.primaryColor.color.opacity(SQColor.isDarkMode ? 0.45 : 0.24),
                    radius: isAnimating ? size * 0.18 : size * 0.10,
                    x: 0,
                    y: 0
                )

            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color.white.opacity(SQColor.isDarkMode ? 0.14 : 0.10),
                            viewModel.state.secondaryColor.color.opacity(SQColor.isDarkMode ? 0.06 : 0.04),
                            Color.clear,
                            viewModel.state.primaryColor.color.opacity(SQColor.isDarkMode ? 0.72 : 0.54)
                        ],
                        center: .init(x: 0.36, y: 0.30),
                        startRadius: 1,
                        endRadius: orbSize * 0.68
                    )
                )
                .frame(width: orbSize, height: orbSize)
                .overlay {
                    Circle()
                        .stroke(Color.white.opacity(SQColor.isDarkMode ? 0.34 : 0.60), lineWidth: 1)
                }
                .overlay(alignment: .topLeading) {
                    Circle()
                        .fill(Color.white.opacity(SQColor.isDarkMode ? 0.56 : 0.76))
                        .frame(width: highlightSize, height: highlightSize)
                        .blur(radius: 1.2)
                        .offset(x: orbSize * 0.16, y: orbSize * 0.18)
                }

            Circle()
                .fill(SQColor.background.color.opacity(SQColor.isDarkMode ? 0.30 : 0.18))
                .frame(width: orbSize * 0.42, height: orbSize * 0.42)
                .blur(radius: 2)

            Text(viewModel.scoreText)
                .sqFont(scoreFont)
                .sqForegroundColor(.textPrimary)
        }
        .frame(width: size, height: size)
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true)) {
                isAnimating = true
            }
        }
    }
}

// MARK: - UI Config
/// Controls shared UI configuration for the dashboard sub-views

extension SQDashboardView {
    
    struct UIConfig {
        let sectionGroupHorizPadding: CGFloat = .SQSpace.l
        
        let sectionHeaderHorizPadding: CGFloat = .SQSpace.l
        let sectionRowHorizPadding: CGFloat = .SQSpace.l
        let sectionRowVertPadding: CGFloat = .SQSpace.l
        let sectionRowSpacing: CGFloat = .SQSpace.xxl
        let spacingBetweenSections: CGFloat = .SQSpace.l
    }
    
    @ViewBuilder
    static func sectionTitle(title: String) -> some View {
        Text(title)
            .sqFont(.title2)
            .sqForegroundColor(.textPrimary)
            .padding(.bottom, .SQSpace.xl)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    @ViewBuilder
    static func cardTitle(title: String, icon: SQImageSymbol? = nil) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: .SQSpace.m) {
            Text(title)
                .sqFont(.title3)
                .sqForegroundColor(.textPrimary)
            
            if let icon {
                SQImageView(image: .init(symbol: icon, symbolStyle: .colorWithFont(.textPrimary, font: .bodyExtraSmall)))
                    .frame(width: 14)
            }
        }
    }
    
    @ViewBuilder
        static func card<Content: View>(
            background: SQColor = SQColor.backgroundSecondary,
            innerHoriz: CGFloat = .SQSpace.l,
            innerVert: CGFloat = .SQSpace.l,
            cornerRadius: CGFloat = .SQCornerRadius.m,
            outerHoriz: CGFloat? = .SQSpace.l,
            outerVert: CGFloat? = nil,
            @ViewBuilder content: () -> Content
        ) -> some View {
            content()
                .padding(.horizontal, innerHoriz)
                .padding(.vertical, innerVert)
                .sqBackgroundColor(background)
                .cornerRadius(cornerRadius)
        }
}

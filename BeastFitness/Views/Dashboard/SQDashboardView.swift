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

    private var displayedLifeScoreViewModel: SQLifeScoreViewModel? {
        controller.lifeScoreViewModel ?? (controller.state.isLoading ? .mock : nil)
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
                        .sqFont(.title2)
                        .sqForegroundColor(.textPrimary)
                        .opacity(SQColor.isDarkMode ? 0.24 : 0.18)
                }
                .padding(.horizontal, 16)
                .padding(.top, 10)
                .padding(.bottom, 10)

                if let lifeScoreViewModel = displayedLifeScoreViewModel {
                    Group {
                        if controller.lifeScoreViewModel != nil && !controller.state.isLoading {
                            Button {
                                controller.handleLifeScoreTap()
                            } label: {
                                SQLifeScoreHeroCard(viewModel: lifeScoreViewModel)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(lifeScoreViewModel.accessibilityLabel)
                        } else {
                            SQLifeScoreHeroCard(viewModel: lifeScoreViewModel)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 8)
                }

                if let runtimeControlCtaViewModel = controller.runtimeControlCtaViewModel {
                    SQCallToAction(viewModel: runtimeControlCtaViewModel)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 16)
                }

                if !controller.state.isLoading,
                   let healthKitAccessCtaViewModel = controller.healthKitAccessCtaViewModel {
                    SQCallToAction(viewModel: healthKitAccessCtaViewModel)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 16)
                } else if !controller.state.isLoading,
                          let dailyCheckInCtaViewModel = controller.state.dailyCheckInCtaViewModel {
                    SQCallToAction(viewModel: dailyCheckInCtaViewModel)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 16)
                }

                if shouldShowDashboardErrorState {
                    SQSubsectionEmptyState(
                        viewModel: .init(
                            title: "Dashboard data couldn't load",
                            subtitle: "Something went wrong while loading your dashboard. You may not have Health data yet, or some Health access may not be enabled. If you use Health data in LifeIQ, check Health app > Profile > Apps > LifeIQ, then pull to refresh and try again.",
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
        .padding(.top, 18)
        .padding(.bottom, 10)
    }
}

private struct SQLifeScoreOrbView: View {
    let viewModel: SQLifeScoreViewModel
    let size: CGFloat
    let scoreFont: SQFont.FontType

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isAnimating = false

    private var auraSize: CGFloat { size * 0.98 }
    private var orbSize: CGFloat { size * 0.72 }
    private var currentLineWidth: CGFloat { max(6, size * 0.055) }

    var body: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color.clear,
                            viewModel.state.secondaryColor.color.opacity(SQColor.isDarkMode ? 0.10 : 0.08),
                            viewModel.state.primaryColor.color.opacity(SQColor.isDarkMode ? 0.34 : 0.24),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: auraSize * 0.12,
                        endRadius: auraSize * 0.52
                    )
                )
                .frame(width: auraSize, height: auraSize)
                .blur(radius: size * 0.08)
                .scaleEffect(isAnimating ? 1.06 : 0.99)
                .opacity(isAnimating ? 0.96 : 0.78)
                .shadow(
                    color: viewModel.state.primaryColor.color.opacity(SQColor.isDarkMode ? 0.45 : 0.24),
                    radius: size * 0.16,
                    x: 0,
                    y: 0
                )

            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color.white.opacity(SQColor.isDarkMode ? 0.10 : 0.08),
                            viewModel.state.secondaryColor.color.opacity(SQColor.isDarkMode ? 0.18 : 0.14),
                            viewModel.state.primaryColor.color.opacity(SQColor.isDarkMode ? 0.24 : 0.18),
                            Color.clear,
                            viewModel.state.primaryColor.color.opacity(SQColor.isDarkMode ? 0.74 : 0.56)
                        ],
                        center: .init(x: 0.47, y: 0.44),
                        startRadius: 1,
                        endRadius: orbSize * 0.74
                    )
                )
                .frame(width: orbSize, height: orbSize)
                .overlay {
                    Circle()
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.95),
                                    viewModel.state.secondaryColor.color.opacity(0.55),
                                    viewModel.state.primaryColor.color.opacity(0.88)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.4
                        )
                        .blur(radius: 0.4)
                }
                .overlay {
                    Circle()
                        .stroke(
                            AngularGradient(
                                colors: [
                                    viewModel.state.primaryColor.color.opacity(0.0),
                                    viewModel.state.primaryColor.color.opacity(0.60),
                                    Color.white.opacity(0.85),
                                    viewModel.state.secondaryColor.color.opacity(0.55),
                                    viewModel.state.primaryColor.color.opacity(0.0)
                                ],
                                center: .center
                            ),
                            lineWidth: currentLineWidth
                        )
                        .frame(width: orbSize * 0.90, height: orbSize * 0.90)
                        .blur(radius: 7)
                        .rotationEffect(.degrees(isAnimating ? 18 : -12))
                        .scaleEffect(isAnimating ? 1.02 : 0.98)
                }

            Group {
                Circle()
                    .trim(from: 0.10, to: 0.58)
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.06),
                                viewModel.state.secondaryColor.color.opacity(0.65),
                                viewModel.state.primaryColor.color.opacity(0.10)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        style: StrokeStyle(lineWidth: currentLineWidth, lineCap: .round)
                    )
                    .frame(width: orbSize * 0.76, height: orbSize * 0.76)
                    .rotationEffect(.degrees(isAnimating ? 142 : 116))
                    .blur(radius: 2.4)

                Circle()
                    .trim(from: 0.28, to: 0.76)
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.clear,
                                viewModel.state.primaryColor.color.opacity(0.46),
                                Color.white.opacity(0.30),
                                Color.clear
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        style: StrokeStyle(lineWidth: currentLineWidth * 0.7, lineCap: .round)
                    )
                    .frame(width: orbSize * 0.58, height: orbSize * 0.58)
                    .rotationEffect(.degrees(isAnimating ? -38 : -12))
                    .blur(radius: 1.8)
            }
            .blendMode(.plusLighter)

            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color.white.opacity(0.03),
                            viewModel.state.secondaryColor.color.opacity(0.08),
                            SQColor.background.color.opacity(SQColor.isDarkMode ? 0.06 : 0.04),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: orbSize * 0.22
                    )
                )
                .frame(width: orbSize * 0.54, height: orbSize * 0.54)
                .blur(radius: 6)

            Text(viewModel.scoreText)
                .sqFont(scoreFont)
                .sqForegroundColor(.textPrimary)
                .shadow(
                    color: viewModel.state.primaryColor.color.opacity(0.22),
                    radius: 10,
                    x: 0,
                    y: 0
                )
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

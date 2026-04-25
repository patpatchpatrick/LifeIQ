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
                                SQLifeScoreHeroCard(
                                    viewModel: lifeScoreViewModel,
                                    timeRange: controller.state.selectedTimeRange
                                )
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(lifeScoreViewModel.accessibilityLabel)
                        } else {
                            SQLifeScoreHeroCard(
                                viewModel: lifeScoreViewModel,
                                timeRange: controller.state.selectedTimeRange
                            )
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
                .disabled(controller.state.isLoading || controller.emailVerificationRequirement != nil)

            if controller.emailVerificationRequirement != nil {
                SQEmailVerificationGateView(controller: controller.emailVerificationController)
                    .zIndex(2)
            }
        }
            .navigationBarTitleDisplayMode(.inline)
            .redacted(controller.state.isLoading, reason: .placeholder)
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
                        await controller.refreshUIIfNeededOnForeground(for: modelContext)
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
    let timeRange: AppTimeRange

    private var driverColumns: [GridItem] {
        [.init(.adaptive(minimum: 88), spacing: .SQSpace.xs, alignment: .center)]
    }

    private var shouldShowTodayBriefing: Bool {
        timeRange == .today && viewModel.primaryInsight != nil
    }

    private var primaryAction: SQInsightAction? {
        viewModel.actions.first
    }

    var body: some View {
        VStack(spacing: .SQSpace.m) {
            SQLifeScoreOrbView(viewModel: viewModel, size: 156, scoreFont: .title1)

            VStack(spacing: .SQSpace.s) {
                Text(viewModel.state.title)
                    .sqFont(.title3)
                    .sqForegroundColor(.textPrimary)

                if shouldShowTodayBriefing, let primaryInsight = viewModel.primaryInsight {
                    VStack(spacing: .SQSpace.s) {
                        Text(primaryInsight.title)
                            .sqFont(.bodySmallSemiBold)
                            .sqForegroundColor(.textPrimary)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: 280)
                            .fixedSize(horizontal: false, vertical: true)

                        if !viewModel.drivers.isEmpty {
                            heroDrivers
                        }

                        if let primaryAction {
                            Text("Best move: \(primaryAction.summary)")
                                .sqFont(.bodyExtraSmall)
                                .sqForegroundColor(.textSecondary)
                                .multilineTextAlignment(.center)
                                .frame(maxWidth: 280)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 18)
        .padding(.bottom, 10)
    }

    private var heroDrivers: some View {
        LazyVGrid(columns: driverColumns, alignment: .center, spacing: .SQSpace.xs) {
            ForEach(Array(viewModel.drivers.prefix(3))) { driver in
                HeroDriverChip(driver: driver)
            }
        }
        .frame(maxWidth: 300)
    }
}

private struct HeroDriverChip: View {
    let driver: SQInsightDriver

    private var color: SQColor {
        driver.direction == .supportive ? .dashboardGlowMint : .colorErrorRed
    }

    private var symbolText: String {
        driver.direction == .supportive ? "+" : "-"
    }

    var body: some View {
        Text("\(symbolText) \(driver.title)")
            .sqFont(.bodyExtraSmall)
            .sqForegroundColor(.textPrimary)
            .padding(.vertical, 6)
            .padding(.horizontal, .SQSpace.s)
            .background {
                Capsule(style: .continuous)
                    .fill(color.color.opacity(SQColor.isDarkMode ? 0.16 : 0.10))
            }
            .overlay {
                Capsule(style: .continuous)
                    .stroke(color.color.opacity(SQColor.isDarkMode ? 0.30 : 0.20), lineWidth: 1)
            }
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
    private var usesQuePalette: Bool {
        switch viewModel.state {
        case .aligned, .steady:
            return true
        case .mixed, .strained, .calibrating:
            return false
        }
    }
    private var primaryAccent: Color {
        usesQuePalette ? SQColor.hex("#6FCFF6").color : viewModel.state.primaryColor.color
    }
    private var secondaryAccent: Color {
        usesQuePalette ? SQColor.hex("#35D9E1").color : viewModel.state.secondaryColor.color
    }
    private var deepAccent: Color {
        usesQuePalette ? SQColor.hex("#2A76D9").color : viewModel.state.primaryColor.color
    }
    private var mintAccent: Color {
        usesQuePalette ? SQColor.hex("#8CEEBB").color : viewModel.state.secondaryColor.color
    }
    private var greenAccent: Color {
        usesQuePalette ? SQColor.hex("#B8F47D").color : viewModel.state.secondaryColor.color
    }

    var body: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color.clear,
                            secondaryAccent.opacity(usesQuePalette ? (SQColor.isDarkMode ? 0.11 : 0.08) : (SQColor.isDarkMode ? 0.10 : 0.08)),
                            primaryAccent.opacity(usesQuePalette ? (SQColor.isDarkMode ? 0.34 : 0.24) : (SQColor.isDarkMode ? 0.34 : 0.24)),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: auraSize * 0.12,
                        endRadius: auraSize * 0.52
                    )
                )
                .frame(width: auraSize, height: auraSize)
                .blur(radius: size * 0.08)
                .scaleEffect(usesQuePalette ? (isAnimating ? 1.04 : 0.99) : (isAnimating ? 1.06 : 0.99))
                .opacity(usesQuePalette ? (isAnimating ? 0.88 : 0.70) : (isAnimating ? 0.96 : 0.78))
                .shadow(
                    color: primaryAccent.opacity(usesQuePalette ? (SQColor.isDarkMode ? 0.42 : 0.26) : (SQColor.isDarkMode ? 0.45 : 0.24)),
                    radius: size * 0.16,
                    x: 0,
                    y: 0
                )

            Circle()
                .fill(
                    RadialGradient(
                        colors: usesQuePalette ? [
                            Color.white.opacity(SQColor.isDarkMode ? 0.06 : 0.04),
                            secondaryAccent.opacity(SQColor.isDarkMode ? 0.28 : 0.20),
                            primaryAccent.opacity(SQColor.isDarkMode ? 0.34 : 0.24),
                            Color.clear,
                            deepAccent.opacity(SQColor.isDarkMode ? 0.64 : 0.48)
                        ] : [
                            Color.white.opacity(SQColor.isDarkMode ? 0.10 : 0.08),
                            secondaryAccent.opacity(SQColor.isDarkMode ? 0.18 : 0.14),
                            primaryAccent.opacity(SQColor.isDarkMode ? 0.24 : 0.18),
                            Color.clear,
                            primaryAccent.opacity(SQColor.isDarkMode ? 0.74 : 0.56)
                        ],
                        center: usesQuePalette ? .init(x: 0.47, y: 0.40) : .init(x: 0.47, y: 0.44),
                        startRadius: 1,
                        endRadius: orbSize * 0.74
                    )
                )
                .frame(width: orbSize, height: orbSize)
                .overlay {
                    if usesQuePalette {
                        Circle()
                            .fill(
                                RadialGradient(
                                    colors: [
                                        greenAccent.opacity(SQColor.isDarkMode ? 0.54 : 0.42),
                                        mintAccent.opacity(SQColor.isDarkMode ? 0.34 : 0.26),
                                        secondaryAccent.opacity(SQColor.isDarkMode ? 0.10 : 0.08),
                                        Color.clear
                                    ],
                                    center: .init(x: 0.52, y: 0.90),
                                    startRadius: 0,
                                    endRadius: orbSize * 0.58
                                )
                            )
                    }
                }
                .overlay {
                    if usesQuePalette {
                        Circle()
                            .trim(from: 0.55, to: 0.95)
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        mintAccent.opacity(0.35),
                                        greenAccent.opacity(0.76),
                                        secondaryAccent.opacity(0.42)
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                ),
                                style: StrokeStyle(lineWidth: currentLineWidth * 0.78, lineCap: .round)
                            )
                            .frame(width: orbSize * 0.84, height: orbSize * 0.84)
                            .rotationEffect(.degrees(isAnimating ? -11 : -7))
                            .blur(radius: 0.55)
                            .shadow(color: greenAccent.opacity(0.20), radius: 8, x: 0, y: 2)
                    }
                }
                .overlay {
                    Circle()
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(usesQuePalette ? 0.42 : 0.95),
                                    usesQuePalette ? primaryAccent.opacity(0.46) : secondaryAccent.opacity(0.55),
                                    usesQuePalette ? mintAccent.opacity(0.46) : viewModel.state.primaryColor.color.opacity(0.88)
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
                                    primaryAccent.opacity(0.0),
                                    primaryAccent.opacity(usesQuePalette ? 0.10 : 0.60),
                                    Color.white.opacity(usesQuePalette ? 0.04 : 0.85),
                                    mintAccent.opacity(usesQuePalette ? 0.16 : 0.55),
                                    primaryAccent.opacity(0.0)
                                ],
                                center: .center
                            ),
                            lineWidth: usesQuePalette ? currentLineWidth * 0.5 : currentLineWidth
                        )
                        .frame(width: orbSize * 0.90, height: orbSize * 0.90)
                        .blur(radius: 7)
                        .rotationEffect(.degrees(isAnimating ? 18 : -12))
                        .scaleEffect(isAnimating ? 1.02 : 0.98)
                }

            Group {
                if !usesQuePalette {
                    Circle()
                        .trim(from: 0.10, to: 0.58)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.06),
                                    primaryAccent.opacity(0.65),
                                    deepAccent.opacity(0.10)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            style: StrokeStyle(lineWidth: currentLineWidth, lineCap: .round)
                        )
                        .frame(width: orbSize * 0.76, height: orbSize * 0.76)
                        .rotationEffect(.degrees(isAnimating ? 142 : 116))
                        .blur(radius: 2.4)
                }

                if !usesQuePalette {
                    Circle()
                        .trim(from: 0.28, to: 0.76)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color.clear,
                                    deepAccent.opacity(0.46),
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
            }
            .blendMode(.plusLighter)

            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color.white.opacity(usesQuePalette ? 0.04 : 0.03),
                            secondaryAccent.opacity(usesQuePalette ? 0.08 : 0.08),
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
                    color: primaryAccent.opacity(0.26),
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

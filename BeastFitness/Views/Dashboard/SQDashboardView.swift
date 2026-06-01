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

    private var loadingPercentText: String {
        let progress = controller.state.loadingProgress ?? 0
        return "\(Int((progress * 100).rounded()))%"
    }

    var mainScroll: some View {
        ScrollView {
            VStack(spacing: 0) {
                HStack(alignment: .center, spacing: .SQSpace.m) {
                    Text("LifeIQ")
                        .sqFont(.titleNav)
                        .sqForegroundColor(.textPrimary)
                        .contentShape(Rectangle())
                        .onLongPressGesture(minimumDuration: 0.9) {
                            controller.handleViewLabTrigger()
                        }

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

                        SQDropDownMenu(
                            menuViewModel: controller.timeRangeMenuViewModel,
                            isDisabled: false
                        )

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
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 8)

                if let lifeScoreViewModel = displayedLifeScoreViewModel {
                    SQLifeScoreCommandCard(
                        viewModel: lifeScoreViewModel,
                        onOpenDetail: controller.lifeScoreViewModel != nil && !controller.state.isLoading
                            ? { controller.handleLifeScoreTap() }
                            : nil
                    )
                    .accessibilityLabel(lifeScoreViewModel.accessibilityLabel)
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 20)
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
                    SQDashboardGridView(
                        controller: controller,
                        lifeScoreViewModel: displayedLifeScoreViewModel
                    )
                }

                Spacer()
            }
        }
        .refreshable {
            await controller.refreshUI(for: modelContext)
        }
        .safeAreaInset(edge: .bottom) {
            if !controller.state.isLoading,
               let checkInActionViewModel = controller.state.dailyCheckInActionViewModel {
                SQDashboardCheckInBottomAction(viewModel: checkInActionViewModel)
                    .padding(.horizontal, 16)
                    .padding(.top, .SQSpace.s)
                    .padding(.bottom, .SQSpace.s)
            }
        }
    }

    var body: some View {
        ZStack {
            SQDashboardBackground()

            mainScroll
                .disabled(controller.state.isLoading || controller.emailVerificationRequirement != nil)

            if controller.state.isLoading {
                loadingProgressOverlay
                    .zIndex(1)
                    .unredacted()
            }

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

    private var loadingProgressOverlay: some View {
        VStack {
            HStack {
                Spacer()

                HStack(spacing: .SQSpace.s) {
                    ProgressView(value: controller.state.loadingProgress ?? 0, total: 1)
                        .progressViewStyle(.linear)
                        .tint(SQColor.dashboardGlowBlue.color)
                        .frame(width: 72)

                    Text(loadingPercentText)
                        .sqFont(.bodyExtraSmall)
                        .sqForegroundColor(.textPrimary)
                        .monospacedDigit()
                        .frame(width: 34, alignment: .trailing)
                }
                .padding(.horizontal, .SQSpace.m)
                .padding(.vertical, .SQSpace.s)
                .background(
                    Capsule(style: .continuous)
                        .fill(SQColor.glassCardTint.color.opacity(SQColor.isDarkMode ? 0.92 : 0.98))
                )
                .overlay(
                    Capsule(style: .continuous)
                        .stroke(SQColor.glassStroke.color, lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(SQColor.isDarkMode ? 0.20 : 0.08), radius: 12, x: 0, y: 6)
            }
            .padding(.horizontal, 16)
            .padding(.top, 58)

            Spacer()
        }
        .allowsHitTesting(false)
    }
}

private struct SQDashboardCheckInBottomAction: View {
    let viewModel: SQDashboardCheckInActionViewModel

    private var isHighlighted: Bool {
        viewModel.state == .incomplete
    }

    private var accentColor: SQColor {
        switch viewModel.state {
        case .incomplete:
            return .dashboardGlowBlue
        case .complete:
            return .textSecondary
        case .guest:
            return .dashboardGlowBlue
        }
    }

    private var borderOpacity: Double {
        isHighlighted ? (SQColor.isDarkMode ? 0.34 : 0.22) : (SQColor.isDarkMode ? 0.30 : 0.20)
    }

    var body: some View {
        Button(action: viewModel.onTap) {
            HStack(spacing: .SQSpace.m) {
                ZStack(alignment: .topTrailing) {
                    Circle()
                        .fill(accentColor.color.opacity(isHighlighted ? 0.12 : 0.10))
                        .frame(width: 38, height: 38)
                        .overlay {
                            Circle()
                                .stroke(accentColor.color.opacity(borderOpacity), lineWidth: 1)
                        }

                    SQImageView(
                        image: .init(
                            symbol: viewModel.icon,
                            symbolStyle: .colorWithFont(accentColor, font: .bodySmallSemiBold)
                        )
                    )
                    .frame(width: 16, height: 16)

                    if isHighlighted {
                        Circle()
                            .fill(SQColor.dashboardTrendWarm.color)
                            .frame(width: 7, height: 7)
                            .overlay {
                                Circle()
                                    .stroke(SQColor.background.color, lineWidth: 1)
                            }
                    }
                }
                .frame(width: 38, height: 38)

                VStack(alignment: .leading, spacing: 2) {
                    Text(viewModel.title)
                        .sqFont(.bodySemiBold)
                        .sqForegroundColor(.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.82)

                    if let subtitle = viewModel.subtitle {
                        Text(subtitle)
                            .sqFont(.bodyExtraSmall)
                            .sqForegroundColor(.textTertiary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.78)
                    }
                }

                Spacer(minLength: .SQSpace.s)

                SQImageView(
                    image: .init(
                        symbol: .chevronRight,
                        symbolStyle: .colorWithFont(.textTertiary, font: .bodyExtraSmall)
                    )
                )
                .frame(width: 9, height: 9)
            }
            .padding(.horizontal, .SQSpace.l)
            .padding(.vertical, .SQSpace.m)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: .SQCornerRadius.xl, style: .continuous)
                    .fill(SQColor.dashboardGradientMid.color.opacity(SQColor.isDarkMode ? 0.92 : 0.78))
                    .overlay {
                        RoundedRectangle(cornerRadius: .SQCornerRadius.xl, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        SQColor.dashboardGlowBlue.color.opacity(isHighlighted ? 0.055 : 0.030),
                                        SQColor.dashboardGradientEnd.color.opacity(SQColor.isDarkMode ? 0.16 : 0.08)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: .SQCornerRadius.xl, style: .continuous)
                            .stroke(
                                isHighlighted
                                    ? SQColor.dashboardGlowBlue.color.opacity(borderOpacity)
                                    : SQColor.glassStroke.color.opacity(0.58),
                                lineWidth: 1
                            )
                    }
            }
            .shadow(
                color: Color.black.opacity(SQColor.isDarkMode ? 0.08 : 0.04),
                radius: isHighlighted ? 9 : 6,
                x: 0,
                y: 4
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(viewModel.title)
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
        let spacingBetweenSections: CGFloat = .SQSpace.xl
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

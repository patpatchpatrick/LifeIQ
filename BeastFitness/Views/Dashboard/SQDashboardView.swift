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
                        .contentShape(Rectangle())
                        .onLongPressGesture(minimumDuration: 0.9) {
                            controller.handleViewLabTrigger()
                        }
                }
                .padding(.horizontal, 16)
                .padding(.top, 10)
                .padding(.bottom, 10)

                if let lifeScoreViewModel = displayedLifeScoreViewModel {
                    SQLifeScoreHeroCard(
                        viewModel: lifeScoreViewModel,
                        timeRange: controller.state.selectedTimeRange,
                        onOpenDetail: controller.lifeScoreViewModel != nil && !controller.state.isLoading
                            ? { controller.handleLifeScoreTap() }
                            : nil
                    )
                    .accessibilityLabel(lifeScoreViewModel.accessibilityLabel)
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 12)

                    if controller.state.selectedTimeRange == .today,
                       !lifeScoreViewModel.changes.isEmpty {
                        SQLifeScoreRecentChangesCard(
                            changes: Array(lifeScoreViewModel.changes.prefix(3)),
                            onAccessoryTap: { controller.handleSeeMoreInsightsTap() }
                        )
                        .padding(.horizontal, 16)
                        .padding(.bottom, 28)
                    } else {
                        Color.clear
                            .frame(height: 20)
                    }
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

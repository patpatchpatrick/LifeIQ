//
//  SQDashboardView.swift
//  BeastFitness
//
//  Created by Patrick Doyle on 11/11/25.
//

import SwiftUI

struct SQDashboardView: View {
    @Bindable var controller: SQDashboardController
    @Environment(\.modelContext) private var modelContext
    static let uiConfig = UIConfig()

    var mainScroll: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Dashboard controls
                HStack {
                    SQDropDownMenu(
                        menuViewModel: controller.timeRangeMenuViewModel,
                        isDisabled: false
                    )

                    Spacer()

                    Button {
                        controller.handleAuthButtonTap()
                    } label: {
                        SQImageView(
                            image: .init(
                                symbol: controller.authButtonSymbol,
                                symbolStyle: .colorWithFont(.textPrimary, font: .body)
                            )
                        )
                        .frame(width: 28, height: 28)
                    }
                    .accessibilityLabel(controller.userState.isLoggedIn ? "Profile" : "Sign in")
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)

                // Daily Check-In CTA Banner - hide while loading
                if !controller.state.isLoading,
                   let dailyCheckInCtaViewModel = controller.state.dailyCheckInCtaViewModel {
                    SQCallToAction(viewModel: dailyCheckInCtaViewModel)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 16)
                }

                // Main sections - always rendered so mock data shows as a redacted skeleton
                LazyVStack(spacing: 0, pinnedViews: [.sectionHeaders]) {
                    ForEach(controller.state.sectionGroups) { sectionGroup in
                        SQDashboardSectionGroupView(sectionGroup: sectionGroup)
                    }
                }

                Spacer()
            }
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

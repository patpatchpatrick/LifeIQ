//
//  SQDashboardView.swift
//  BeastFitness
//
//  Created by Patrick Doyle on 11/11/25.
//

import SwiftUI

struct SQDashboardView: View {
    @Bindable var viewModel: SQDashboardViewModel
    static let uiConfig = UIConfig()
    
    var mainScroll: some View {
        ScrollView {
            LazyVStack(spacing: 0, pinnedViews: [.sectionHeaders]) {
                
                Spacer()
                    .frame(height: .SQSpace.l)
                
                ForEach(viewModel.rowViewModels) { rowViewModel in
                    switch rowViewModel.rowType {
                    case .text:
                        if let textRowViewModel = rowViewModel as? SQDashboardTextRowViewModel {
                            SQDashboardTextRow(viewModel: textRowViewModel)
                                .padding(.bottom, .SQSpace.xxl)
                        }
                    case .weekSummary:
                        if let weekSummaryViewModel = rowViewModel as? SQDashboardWorkoutSummaryRowViewModel {
                            SQDashboardWorkoutSummaryRow(
                                viewModel: weekSummaryViewModel)
                        }
                    }
                }
                
                Spacer()
            }
            .padding(.top, .SQSpace.xxl)
        }
    }

    var body: some View {
        mainScroll
            .navigationBarTitleDisplayMode(.inline)
                               .toolbar {
                                   ToolbarItem(placement: .topBarLeading) {
                                       HStack(spacing: 12) {
                                           // Profile icon
                                           ZStack {
                                               Circle()
                                                   .fill(Color(.systemGray5))
                                               Text("P") // or an SF Symbol / image
                                                   .font(.system(size: 16, weight: .semibold))
                                           }
                                           .frame(width: 34, height: 34)
                                           
                                           // Multiline welcome text
                                           VStack(alignment: .leading, spacing: 2) {
                                               Text("Welcome back! 👋🏻")
                                                   .font(.system(size: 13, weight: .medium))
                                                   .foregroundStyle(Color.secondary)
                                               
                                               Text("Patrick Doyle")
                                                   .font(.system(size: 17, weight: .semibold))
                                                   .foregroundStyle(Color.primary)
                                           }
                                       }
                                   }
                               }
            .background(SQColor.background.color.ignoresSafeArea())
            .sheet(isPresented: .init(
                get: { viewModel.state.isDailyCheckInSheetVisible },
                set: { isVisible in viewModel.state.toggleDailyCheckInSheetVisibility(isVisible) })) {
                    if let dailyCheckInViewModel = viewModel.dailyCheckInViewModel {
                        SQDailyCheckInView(viewModel: dailyCheckInViewModel)
                    }
                }
    }
}

// MARK: - UI Config
/// Controls shared UI configuration for the dashboard sub-views

extension SQDashboardView {
    
    struct UIConfig {
        let cardInnerTitleBottomPadding: CGFloat = .SQSpace.xl
        let cardSectionSpacing: CGFloat = .SQSpace.xxl
        let sectionHorizPadding: CGFloat = .SQSpace.l
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
    static func cardTitle(title: String) -> some View {
        Text(title)
            .sqFont(.title3)
            .sqForegroundColor(.textPrimary)
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

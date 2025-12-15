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
            LazyVStack(spacing: 0, pinnedViews: [.sectionHeaders]) {
                
                Spacer()
                    .frame(height: .SQSpace.l)
                
                ForEach(controller.state.rowViewModels) { rowViewModel in
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
                                       HStack(spacing: .SQSpace.l) {
                                           
                                           // TODO: Remove mock
                                           SQUserIcon(user: .mock)
                                           .frame(width: 34, height: 34)
                                           
                                           // Multiline welcome text
                                           VStack(alignment: .leading, spacing: 2) {
                                               Text("Welcome back! 👋🏻")
                                                   .font(.system(size: 13, weight: .medium))
                                                   .foregroundStyle(Color.secondary)
                                               
                                               // TODO: - Replace with actual user
                                               Text(SQUser.mock.name)
                                                   .font(.system(size: 17, weight: .semibold))
                                                   .foregroundStyle(Color.primary)
                                           }
                                       }
                                   }
                               }
            .background(SQColor.background.color.ignoresSafeArea())
            .task {
                await controller.loadUI(for: modelContext)
            }
            .task { controller.attach(context: modelContext) }
            .sheet(isPresented: .init(
                get: { controller.state.isDailyCheckInSheetVisible },
                set: { isVisible in controller.state.toggleDailyCheckInSheetVisibility(isVisible) })) {
                    if let dailyCheckInViewModel = controller.state.dailyCheckInViewModel {
                        SQDailyCheckInView(viewModel: dailyCheckInViewModel)
                    }
                }
            .sheet(isPresented: .init(
                get: { controller.state.isWorkoutListSheetVisible },
                set: { isVisible in controller.state.toggleWorkoutListSheetVisibility(isVisible) })) {
                    if let workoutListController = controller.state.workoutsListController {
                        SQWorkoutsListView(controller: workoutListController)
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
    static func cardTitle(title: String, icon: SQImageSymbol? = nil) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .sqFont(.title3)
                .sqForegroundColor(.textPrimary)
            
            if let icon {
                SQImageView(image: .init(symbol: icon, symbolStyle: .colorWithFont(.textPrimary, font: .body)))
                    .frame(width: 20)
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

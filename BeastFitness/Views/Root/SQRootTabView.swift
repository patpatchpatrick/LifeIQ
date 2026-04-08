//
//  SQRootTabView.swift
//  BeastFitness
//
//  Created by Patrick Doyle on 11/11/25.
//

import SwiftUI

struct SQRootTabView: View {
    @State private var viewModel: SQRootTabViewModel
    @Environment(\.modelContext) private var modelContext
    
    init(appState: SQAppState) {
        _viewModel = .init(initialValue: .init(appState: appState))
    }

    @ViewBuilder
    func view(for route: SQNavRoute.DashboardRoute) -> some View {
        switch route {
        case .workoutReview(workouts: let workouts):
            SQWorkoutReviewView(reviewState: .init(hub: SQAppState.shared.hub, workouts: workouts))
        case .workoutSummary(let controller):
            SQWorkoutSummaryView(controller: controller)
        case .workoutInsightDetail(let controller):
            SQWorkoutInsightDetailView(controller: controller)
        case .lifeScoreDetail(let controller):
            SQLifeScoreDetailView(controller: controller)
        case .editWorkout(workout: let workout):
            SQEditWorkoutView(controller: .init(workout: workout))
        case .workoutsList(workouts: let workouts):
            SQWorkoutsListView(controller: .init(eventHub: SQAppState.shared.hub, workouts: workouts))
        case .leaderboard(controller: let controller):
            SQLeaderboardView(controller: controller)
        case .metricDetail(controller: let controller):
            SQMetricDetailView(controller: controller)
        case .profile(controller: let controller):
            SQProfileView(controller: controller)
        case .login(controller: let controller):
            SQLoginView(controller: controller)
        case .deleteAccount(controller: let controller):
            SQDeleteAccountView(controller: controller)
        case .onboarding(controller: let controller):
            SQOnboardingView(controller: controller)
        case .settings(controller: let controller):
            SQSettingsView(controller: controller)
        case .dashboardLayout(controller: let controller):
            SQDashboardLayoutView(controller: controller)
        case .dashboardSubsectionLayout(controller: let controller, groupId: let groupId):
            SQDashboardSubsectionLayoutView(controller: controller, groupId: groupId)
        }
    }
    
    var dashboardViewWithNavSheet: some View {
        SQDashboardView(controller: viewModel.dashboardController)
            .sheet(item: $viewModel.navigationState.dashboardRootSheetView) { route in
                NavigationStack(path: $viewModel.navigationState.dashboardNavPath) { view(for: route)
                        .navigationDestination(for: SQNavRoute.DashboardRoute.self) { route in
                                view(for: route)
                            }
                }
                .background(SQColor.backgroundSheet.color)
            }
    }
    
    var body: some View {
        dashboardViewWithNavSheet
        .frame(maxHeight: .infinity)
        .background(Color.purple)
        .accentColor(SQColor.textPrimary.color)
        .onOpenURL(perform: { url in
            if SQAuthManager.shared.handleGoogleSignIn(url: url) {
                return
            }
            viewModel.deepLinkManager.handleUriDeepLink(for: url)
        })
        .task {
            SQAppState.shared.modelContext = modelContext

//            // Ensure metrics are loaded before migration so period/normalization lookups work
//            try? SQMetricsManager.shared.loadIfNeeded(using: modelContext)
//
//            // One-time migration: convert legacy SQDailyCheckInStats → SQMetricEntry records
//            await SQMetricMigrationManager.runIfNeeded(
//                context: modelContext,
//                metricsManager: SQMetricsManager.shared
//            )

        }
    }
}

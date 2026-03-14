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
    var navigationState: NavigationStating { viewModel.navigationState }
    
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
        case .editWorkout(workout: let workout):
            SQEditWorkoutView(controller: .init(workout: workout))
        case .workoutsList(workouts: let workouts):
            SQWorkoutsListView(controller: .init(eventHub: SQAppState.shared.hub, workouts: workouts))
        case .leaderboard(controller: let controller):
            SQLeaderboardView(controller: controller)
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
    
//    @ViewBuilder
//    var mainTabView: some View {
//        TabView(selection: .init(
//            get: { navigationState.selectedTab },
//            set: { navigationState.changeTab(to: $0) })) {
//                
//                NavigationStack(path: $viewModel.navigationState.dashboardNavPath) {
//                    SQDashboardView(controller: viewModel.dashboardController)
//                        .navigationDestination(for: SQNavRoute.DashboardRoute.self) { route in
//                            switch route {
//                            case .workoutView(let workout):
//                                SQWorkoutSummaryView(controller: .init(workout: workout))
//                            case .editWorkout(workout: let workout):
//                                SQWorkoutSessionView(isBeingDisplayedWithinNavStack: true, controller: .default(for: workout, onDismiss: { print("PTD POP VIEW") }))
//                            case .workoutsList(workouts: let workouts):
//                                SQWorkoutsListView(controller: .init(eventHub: SQAppState.shared.hub, workouts: workouts))
//                            }
//                        }
//                }
//                .tabItem {
//                    Image(systemName: "house")
//                    Text("Home")
//                }
//                .tag(NavigationState.Tab.home)
//            
//                NavigationStack(path: $viewModel.workoutsNavigationPath) {
//                    SQWorkoutsLandingView(controller: viewModel.workoutsScreenController)
//                }
//                .tabItem {
//                    Image(systemName: "plus")
//                    Text("Workouts")
//                }
//                .tag(NavigationState.Tab.workouts)
//        }
//    }
    
    var mainTabViewWithSheets: some View {
        dashboardViewWithNavSheet
            .sheet(isPresented: .init(
                get: { navigationState.isSettingsSheetVisible },
                set: { isVisible in navigationState.toggleSettingsSheetVisibility(isVisible) })) {
                    SQSettingsView(controller: .default)
                }
    }
    
    var body: some View {
        mainTabViewWithSheets
        .frame(maxHeight: .infinity)
        .background(Color.purple)
        .accentColor(SQColor.textPrimary.color)
        .onOpenURL(perform: { url in
            viewModel.deepLinkManager.handleUriDeepLink(for: url)
        })
        .task {
            SQAppState.shared.modelContext = modelContext

            // One-time migration: convert legacy SQDailyCheckInStats → SQMetricEntry records
            SQMetricMigrationManager.runIfNeeded(
                context: modelContext,
                metricsManager: SQMetricsManager.shared
            )
        }
    }
}

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
    
    var navigableDashboardView: some View {
        NavigationStack(path: $viewModel.navigationState.dashboardNavPath) {
            SQDashboardView(controller: viewModel.dashboardController)
                .navigationDestination(for: SQNavRoute.DashboardRoute.self) { route in
                    switch route {
                    case .workoutView(let workout):
                        SQWorkoutSummaryView(controller: .init(workout: workout))
                    case .editWorkout(workout: let workout):
                        SQWorkoutSessionView(isBeingDisplayedWithinNavStack: true, controller: .default(for: workout, onDismiss: { print("PTD POP VIEW") }))
                    case .workoutsList(workouts: let workouts):
                        SQWorkoutsListView(controller: .init(eventHub: SQAppState.shared.hub, workouts: workouts))
                    }
                }
        }
    }
    
    @ViewBuilder
    var mainTabView: some View {
        TabView(selection: .init(
            get: { navigationState.selectedTab },
            set: { navigationState.changeTab(to: $0) })) {
                
                NavigationStack(path: $viewModel.navigationState.dashboardNavPath) {
                    SQDashboardView(controller: viewModel.dashboardController)
                        .navigationDestination(for: SQNavRoute.DashboardRoute.self) { route in
                            switch route {
                            case .workoutView(let workout):
                                SQWorkoutSummaryView(controller: .init(workout: workout))
                            case .editWorkout(workout: let workout):
                                SQWorkoutSessionView(isBeingDisplayedWithinNavStack: true, controller: .default(for: workout, onDismiss: { print("PTD POP VIEW") }))
                            case .workoutsList(workouts: let workouts):
                                SQWorkoutsListView(controller: .init(eventHub: SQAppState.shared.hub, workouts: workouts))
                            }
                        }
                }
                .tabItem {
                    Image(systemName: "house")
                    Text("Home")
                }
                .tag(NavigationState.Tab.home)
            
                NavigationStack(path: $viewModel.workoutsNavigationPath) {
                    SQWorkoutsLandingView(controller: viewModel.workoutsScreenController)
                }
                .tabItem {
                    Image(systemName: "plus")
                    Text("Workouts")
                }
                .tag(NavigationState.Tab.workouts)
        }
    }
    
    var mainTabViewWithSheets: some View {
        navigableDashboardView
            .sheet(isPresented: .init(
                get: { navigationState.isSettingsSheetVisible },
                set: { isVisible in navigationState.toggleSettingsSheetVisibility(isVisible) })) {
                    SQSettingsView(controller: .default)
                }
    }
    
    var body: some View {
        ZStack {
            mainTabViewWithSheets
                .disabled(SQAppState.shared.newWorkoutReviewState.isPresented)

            SQNewWorkoutReviewHost(
                reviewState: SQAppState.shared.newWorkoutReviewState
            )
        }
        .frame(maxHeight: .infinity)
        .background(Color.purple)
        .accentColor(SQColor.textPrimary.color)
        .onOpenURL(perform: { url in
            viewModel.deepLinkManager.handleUriDeepLink(for: url)
        })
        .task {
            SQAppState.shared.modelContext = modelContext
        }
    }
}

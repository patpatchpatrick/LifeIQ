//
//  SQRootTabView.swift
//  BeastFitness
//
//  Created by Patrick Doyle on 11/11/25.
//

import SwiftUI

struct SQRootTabView: View {
    @State private var viewModel: SQRootTabViewModel
    let navigationState: NavigationState
    
    init(appState: AppState) {
        self.navigationState = appState.navigationState
        _viewModel = .init(initialValue: .init(appState: appState))
    }
    
    @ViewBuilder
    var mainTabView: some View {
        TabView(selection: .init(
            get: { navigationState.selectedTab },
            set: { navigationState.changeTab(to: $0) })) {
                
                NavigationStack(path: $viewModel.dashboardNavigationPath) {
                    SQDashboardView(controller: viewModel.dashboardController)
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
    
    var body: some View {
        mainTabView
            .frame(maxHeight: .infinity)
            .background(Color.purple)
            .accentColor(SQColor.textPrimary.color)
            .onOpenURL(perform: { url in
                viewModel.deepLinkManager.handleUriDeepLink(for: url)
            })
    }
}

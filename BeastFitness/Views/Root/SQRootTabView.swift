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
                    SQDashboardView(viewModel: viewModel.dashboardViewModel)
                }
                .tabItem {
                    Image(systemName: "house")
                    Text("Home")
                }
                .tag(NavigationState.Tab.home)
            
//                NavigationStack {
//                    SQSimulatorView(viewModel: viewModel.simulatorViewModel)
//                }
//                .tabItem {
//                    Image(systemName: "gamecontroller")
//                    Text("Old Root")
//                }
//                .tag(NavigationState.Tab.simulator)
        }
    }
    
    var body: some View {
        mainTabView
            .frame(maxHeight: .infinity)
            .background(Color.purple)
            .accentColor(SQColor.text.color)
    }
}

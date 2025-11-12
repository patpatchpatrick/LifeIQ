//
//  SQOldRootView.swift
//  Beast
//
//  Created by Patrick Doyle on 9/23/24.
//

import SwiftUI

struct SQOldRootView: View {
    
    @State var viewModel = SQOldRootViewModel()
    
    var homeDashboard: some View {
        List {
            SQRootActivitySection(viewModel: viewModel.activitySection)
            
            SQRootLeaderboardSection(viewModel: viewModel.leaderboardSection)
        }
        .listStyle(PlainListStyle())
        .sqNavMenu(viewModel.navBarViewModel)
        .background(SQColor.background.color)
    }
    
    var navigableContent: some View {
        NavigationStack(path: $viewModel.navigationPath) {
            homeDashboard
        }
    }
    
    var body: some View {
        navigableContent
        .padding()
        .background(SQColor.background.color)
        .onOpenURL(perform: { url in
            viewModel.deepLinkManager.handleUriDeepLink(for: url)
        })
    }
}

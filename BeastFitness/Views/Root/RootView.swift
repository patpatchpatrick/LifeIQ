//
//  RootView.swift
//  Beast
//
//  Created by Patrick Doyle on 9/23/24.
//

import SwiftUI

struct RootView: View {
    
    @State var viewModel = RootViewModel()
    
    var homeDashboard: some View {
        List {
            RootActivitySection(viewModel: viewModel.activitySection)
        }
        .listStyle(PlainListStyle())
        .sqNavMenu(viewModel.navBarViewModel)
    }
    
    var navigableContent: some View {
        NavigationStack(path: $viewModel.navigationPath) {
            homeDashboard
        }
    }
    
    var body: some View {
        VStack {
            navigableContent
        }
        .padding()
        .background(SQColor.background.color)
        .onOpenURL(perform: { url in
            viewModel.deepLinkManager.handleUriDeepLink(for: url)
        })
    }
}

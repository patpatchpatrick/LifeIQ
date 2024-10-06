//
//  RootView.swift
//  Beast
//
//  Created by Patrick Doyle on 9/23/24.
//

import SwiftUI

struct RootView: View {
    
    @State var viewModel = RootViewModel()
    
    var content: some View {
        List {
            RootActivitySection(viewModel: viewModel.activitySection)
        }
        .listStyle(PlainListStyle())
    }
    
    var body: some View {
        VStack {
           content
        }
        .padding()
        .background(SQColor.background.color)
    }
}

#Preview {
    RootView()
}

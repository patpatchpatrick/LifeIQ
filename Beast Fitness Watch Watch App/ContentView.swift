//
//  ContentView.swift
//  Beast Fitness Watch Watch App
//
//  Created by Patrick Doyle on 12/18/25.
//

import SwiftUI

struct ContentView: View {
    @Bindable var state = SQWatchAppState.shared
    var body: some View {
        VStack(spacing: 8) {
              Text("Beast Fitness")
              Text(state.lastLaunchMessage)
                  .font(.footnote)
          }
        .padding()
    }
}

#Preview {
    ContentView()
}

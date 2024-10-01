//
//  RootView.swift
//  Beast
//
//  Created by Patrick Doyle on 9/23/24.
//

import SwiftUI

struct RootView: View {
    
    @State var rootViewModel = RootViewModel()
    
    var body: some View {
        VStack {
            Image(systemName: "globe")
                .imageScale(.large)
                .foregroundStyle(.tint)
            Text("Hello, world!")
            
            Button(action: {
                Task {
//                    await rootViewModel.getPermissions()
                }
            }, label: {
                Text("Get Permissions")
            })
            
            Button(action: {
                Task {
//                    await rootViewModel.fetchHealthData(forSampleType: .workoutType())
                }
            }, label: {
                Text("Fetch Heart Rate")
            })
        }
        .padding()
    }
}

#Preview {
    RootView()
}

//
//  ContentView.swift
//  Beast Fitness Watch Watch App
//
//  Created by Patrick Doyle on 12/18/25.
//

import SwiftUI
import HealthKit
import BeastFitnessCore

struct SWRootView: View {
    @State var viewModel: SWRootViewModel
    
    init(appState: SWAppState) {
        _viewModel = .init(initialValue: .init(appState: appState))
    }
    
    var body: some View {
        VStack(spacing: 8) {
            Text(viewModel.rootState.title)
                .font(.title)
            
            Text(viewModel.rootState.heartRateTitle)
                .font(.footnote)
          }
        .padding()
    }
}

#Preview {
    SWRootView(appState: .shared)
}

final class WatchAppDelegate: NSObject, WKApplicationDelegate {
    
    // Ensure this exact signature is used
    func handle(_ workoutConfiguration: HKWorkoutConfiguration) {
        
        SQLogger.shared.logW("Starting workout via Watch App Delegate", .debug, context: .watchInterface)
        
        Task { @MainActor in
            SWWorkoutManager.shared.startWorkout(with: workoutConfiguration)
        }
    }
}

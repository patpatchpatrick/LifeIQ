//
//  BeastFitnessApp.swift
//  BeastFitness
//
//  Created by Patrick Doyle on 9/25/24.
//

import SwiftUI
import SwiftData

@main
struct BeastFitnessApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        WindowGroup {
            SQRootTabView(appState: .shared)
                .task { @MainActor in
                   SQOverlayWindow.shared.attachIfNeeded(
                    alerts: AppState.shared.alertState,
                    toasts: AppState.shared.toastState
                   )
               }
        }
        .modelContainer(for: [
            SQDailyCheckInEntity.self,
            SQWorkoutSessionEntity.self
        ])
    }
}

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
                    
                    SQLaunchManager.shared.performLaunchTasks()
                    
                    SQOverlayWindow.shared.attachIfNeeded(
                        alerts: SQAppState.shared.alertState,
                        toasts: SQAppState.shared.toastState,
                        modals: SQAppState.shared.modalState
                    )
               }
        }
        .modelContainer(for: [
            SQDailyCheckInEntity.self,
            SQWorkoutSessionEntity.self,
            SQMetricDefinitionEntity.self,
            SQSyncMetadataEntity.self
        ])
    }
}

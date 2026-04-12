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
    @Environment(\.scenePhase) private var scenePhase
    private let modelContainer: ModelContainer

    init() {
        do {
            self.modelContainer = try SQPersistenceController.makeModelContainer()
        } catch {
            fatalError("Failed to initialize SwiftData container: \(error)")
        }
    }
    
    var body: some Scene {
        WindowGroup {
            SQRootTabView(appState: .shared)
                .task { @MainActor in
                    
                    SQLaunchManager.shared.performLaunchTasks()
                    
                    SQOverlayWindow.shared.attachIfNeeded(
                        appBlocker: SQAppState.shared.appBlockerState,
                        alerts: SQAppState.shared.alertState,
                        toasts: SQAppState.shared.toastState,
                        modals: SQAppState.shared.modalState,
                        dropdownMenu: SQAppState.shared.dropDownMenuState
                    )
               }
        }
        .modelContainer(modelContainer)
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active else { return }
            guard SQAppState.shared.appBlockerState.isPresented else { return }

            SQRemoteConfigManager.shared.refreshForCriticalStateCheck()
        }
    }
}

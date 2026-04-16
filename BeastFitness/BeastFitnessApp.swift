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
    @State private var isSplashVisible = true
    @State private var hasStartedLaunchSequence = false

    init() {
        do {
            self.modelContainer = try SQPersistenceController.makeModelContainer()
        } catch {
            fatalError("Failed to initialize SwiftData container: \(error)")
        }
    }
    
    var body: some Scene {
        WindowGroup {
            ZStack {
                SQRootTabView(appState: .shared)

                if isSplashVisible {
                    SQLaunchSplashView()
                        .transition(.opacity.animation(.easeInOut(duration: 0.4)))
                        .zIndex(1)
                }
            }
            .task { @MainActor in
                guard !hasStartedLaunchSequence else { return }
                hasStartedLaunchSequence = true

                let splashStartDate = Date()

                SQLaunchManager.shared.performLaunchTasks()

                SQOverlayWindow.shared.attachIfNeeded(
                    appBlocker: SQAppState.shared.appBlockerState,
                    alerts: SQAppState.shared.alertState,
                    toasts: SQAppState.shared.toastState,
                    modals: SQAppState.shared.modalState,
                    dropdownMenu: SQAppState.shared.dropDownMenuState
                )

                let minimumSplashDuration: TimeInterval = 1.6
                let elapsed = Date().timeIntervalSince(splashStartDate)
                let remainingDelay = max(0, minimumSplashDuration - elapsed)

                if remainingDelay > 0 {
                    try? await Task.sleep(for: .seconds(remainingDelay))
                }

                withAnimation(.easeInOut(duration: 0.4)) {
                    isSplashVisible = false
                }
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

//
//  SQLaunchManager.swift
//  BeastFitness
//
//  Created by Patrick Doyle on 12/19/25.
//

@MainActor
final class SQLaunchManager {
    static let shared = SQLaunchManager()

    private var hasPerformedLaunchTasks = false

    func performLaunchTasks() {
        guard !hasPerformedLaunchTasks else { return }
        hasPerformedLaunchTasks = true

        SQUserDefaults.shared.recordInstallDateIfNeeded()
        SQRemoteConfigManager.shared.configure()
        SQAnalyticsManager.shared.configure(
            hub: SQAppState.shared.hub,
            userState: SQAppState.shared.userState
        )
        SQAppState.shared.subscriptionService.configure()
        SQWatchInterface.shared.configureMirroringHandler()
        SQAuthManager.shared.startListening(userState: SQAppState.shared.userState)
    }
}

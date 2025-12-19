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
        SQWatchInterface.shared.configureMirroringHandler(onStart: { _ in })
    }
}

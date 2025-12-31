//
//  SQSettingsController.swift
//  BeastFitness
//
//  Created by Patrick Doyle on 12/17/25.
//

import SwiftUI
import Observation

@MainActor
protocol SQSettingsInterface { }

@MainActor
@Observable
final class SQSettingsController: SQSettingsInterface {
    let state: SettingsStating
    var navigationPath = NavigationPath()
    private(set) var rows: [SQSettingsRowViewModel] = []

    @MainActor
    static let `default` = SQSettingsController(state: SQAppState.shared.settingsState)

    init(state: SettingsStating) {
        self.state = state
        buildRows()
    }

    private func buildRows() {
        rows = [
            .init(
                title: "Clear hidden workouts",
                subtitle: "Shows workouts you previously hid after failing to delete in HealthKit.",
                showsChevron: false
            ) { [weak self] in
                guard let self else { return }
                SQUserDefaults.shared.clearHiddenWorkouts()
                self.state.hub.workoutEvents.send(.workoutsUpdated([:]))
                self.state.hub.toastEvents.send(.present(.init(title: "Hidden workouts cleared", style: .success)))
                // Optional: show your custom alert here later
                // AppState.shared.alertState.present(...)
            },

            // Example nested item for later:
            .init(
                title: "Advanced",
                subtitle: nil,
                showsChevron: true
            ) { [weak self] in
                self?.navigationPath.append(SQNavRoute.Settings.nested)
            }
        ]
    }

    func popView() {
        if !navigationPath.isEmpty {
            navigationPath.removeLast()
        }
    }
}

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
    let id = UUID().uuidString
    let state: SettingsStating
    let dashboardState: DashboardStating
    private let dashboardLayoutService: SQDashboardLayoutServicing
    var navigationPath = NavigationPath()
    private(set) var rows: [SQSettingsRowViewModel] = []

    @MainActor
    static let `default` = SQSettingsController(state: SQAppState.shared.settingsState)

    init(
        state: SettingsStating,
        dashboardState: DashboardStating = SQAppState.shared.dashboardState,
        dashboardLayoutService: SQDashboardLayoutServicing? = nil
    ) {
        self.state = state
        self.dashboardState = dashboardState
        self.dashboardLayoutService = dashboardLayoutService ?? SQDashboardLayoutService()
        buildRows()
    }

    private func buildRows() {
        rows = [
            .init(
                title: "Customize dashboard",
                subtitle: "Reorder, hide, and restore dashboard sections and subsections.",
                showsChevron: true
            ) { [weak self] in
                guard let self else { return }
                let controller = SQDashboardLayoutController(
                    availableGroups: self.dashboardState.availableLayoutGroups,
                    layoutService: self.dashboardLayoutService
                ) { [weak self] in
                    guard let self else { return }
                    self.dashboardState.updateSectionGroups(
                        to: self.dashboardLayoutService.apply(to: self.dashboardState.uncustomizedSectionGroups)
                    )
                }

                self.state.hub.domainEvents.send(.pushDashboardRoute(.dashboardLayout(controller: controller)))
            },

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

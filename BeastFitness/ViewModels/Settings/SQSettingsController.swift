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
    let userState: SQUserStating
    private let dashboardLayoutService: SQDashboardLayoutServicing
    var navigationPath = NavigationPath()
    private(set) var rows: [SQSettingsRowViewModel] = []

    @MainActor
    static let `default` = SQSettingsController(state: SQAppState.shared.settingsState)

    init(
        state: SettingsStating,
        dashboardState: DashboardStating = SQAppState.shared.dashboardState,
        userState: SQUserStating = SQAppState.shared.userState,
        dashboardLayoutService: SQDashboardLayoutServicing? = nil
    ) {
        self.state = state
        self.dashboardState = dashboardState
        self.userState = userState
        self.dashboardLayoutService = dashboardLayoutService ?? SQDashboardLayoutService()
        buildRows()
    }

    private func buildRows() {
        var builtRows: [SQSettingsRowViewModel] = []

        if userState.isLoggedIn {
            builtRows.append(
                .init(
                    title: "Edit profile stats",
                    subtitle: "Update your name, height, weight, birth date, and sleep schedule.",
                    showsChevron: true
                ) { [weak self] in
                    guard let self else { return }
                    let controller = SQOnboardingController(mode: .editProfile)
                    self.state.hub.domainEvents.send(.pushDashboardRoute(.onboarding(controller: controller)))
                }
            )
        }

        builtRows.append(contentsOf: [
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
                self?.confirmClearHiddenWorkouts()
            },

            // Example nested item for later:
            .init(
                title: "Advanced",
                subtitle: nil,
                showsChevron: true
            ) { [weak self] in
                self?.navigationPath.append(SQNavRoute.Settings.nested)
            }
        ])

        rows = builtRows
    }

    private func confirmClearHiddenWorkouts() {
        let alert = SQAlertViewModel(
            title: "Clear hidden workouts?",
            subtitle: "This will restore workouts you previously hid after a failed HealthKit delete, so they can appear in your workout lists again.",
            primary: .init(title: "Clear", role: .destructive) { [weak self] _ in
                guard let self else { return }
                SQUserDefaults.shared.clearHiddenWorkouts()
                self.state.hub.workoutEvents.send(.workoutsUpdated([:]))
                self.state.hub.toastEvents.send(.present(.init(title: "Hidden workouts cleared", style: .success)))
            },
            secondary: .init(title: "Cancel", role: .cancel),
            canDismiss: true
        )

        state.hub.alertEvents.send(.present(alert))
    }

    func popView() {
        if !navigationPath.isEmpty {
            navigationPath.removeLast()
        }
    }
}

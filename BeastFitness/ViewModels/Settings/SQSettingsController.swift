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
    private let userManager: SQUserManaging
    var navigationPath = NavigationPath()
    private(set) var rows: [SQSettingsRowViewModel] = []

    @MainActor
    static let `default` = SQSettingsController(state: SQAppState.shared.settingsState)

    init(
        state: SettingsStating,
        dashboardState: DashboardStating = SQAppState.shared.dashboardState,
        userState: SQUserStating = SQAppState.shared.userState,
        dashboardLayoutService: SQDashboardLayoutServicing? = nil,
        userManager: SQUserManaging = SQUserManager.shared
    ) {
        self.state = state
        self.dashboardState = dashboardState
        self.userState = userState
        self.dashboardLayoutService = dashboardLayoutService ?? SQDashboardLayoutService()
        self.userManager = userManager
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
                    SQAnalyticsManager.shared.track(.settingsActionTaken(action: "edit_profile_stats"))
                    let controller = SQOnboardingController(mode: .editProfile)
                    self.state.hub.domainEvents.send(.pushDashboardRoute(.onboarding(controller: controller)))
                }
            )

            builtRows.append(
                .init(
                    title: "Delete account",
                    subtitle: "Permanently delete your LifeIQ account and app-managed data.",
                    showsChevron: true
                ) { [weak self] in
                    guard let self else { return }
                    SQAnalyticsManager.shared.track(.settingsActionTaken(action: "delete_account"))
                    let controller = SQDeleteAccountController()
                    self.state.hub.domainEvents.send(.pushDashboardRoute(.deleteAccount(controller: controller)))
                }
            )
        }

        builtRows.append(contentsOf: [
            .init(
                title: "Units",
                subtitle: "Currently \(currentUnitSystem.title).",
                showsChevron: true
            ) { [weak self] in
                SQAnalyticsManager.shared.track(.settingsActionTaken(action: "units"))
                self?.presentUnitSystemPicker()
            },

            .init(
                title: "Customize dashboard",
                subtitle: "Reorder, hide, and restore dashboard sections and subsections.",
                showsChevron: true
            ) { [weak self] in
                guard let self else { return }
                SQAnalyticsManager.shared.track(.settingsActionTaken(action: "customize_dashboard"))
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
                subtitle: "Restore workouts you previously hid so they appear in the app again.",
                showsChevron: false
            ) { [weak self] in
                SQAnalyticsManager.shared.track(.settingsActionTaken(action: "clear_hidden_workouts"))
                self?.confirmClearHiddenWorkouts()
            }
        ])

        rows = builtRows
    }

    private var currentUnitSystem: SQUnitSystem {
        SQUnitSystemResolver.resolve(for: userState.loggedInUser)
    }

    private func confirmClearHiddenWorkouts() {
        let alert = SQAlertViewModel(
            title: "Clear hidden workouts?",
            subtitle: "This will restore workouts you previously hid so they appear in the app again.",
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

    private func presentUnitSystemPicker() {
        let dropDown = SQAlertDropDownViewModel(
            title: "Units",
            options: SQUnitSystem.allCases.map { .init(id: $0.rawValue, title: $0.title) },
            defaultSelectedOptionId: currentUnitSystem.rawValue
        )

        let alert = SQAlertViewModel(
            title: "Choose Units",
            subtitle: "This changes how measurements appear throughout the app.",
            primary: .init(title: "Save") { [weak self] context in
                guard
                    let self,
                    let rawValue = context?.selectedDropDownId,
                    let unitSystem = SQUnitSystem(rawValue: rawValue)
                else { return }

                Task { @MainActor in
                    await self.saveUnitSystem(unitSystem)
                }
            },
            secondary: .init(title: "Cancel", role: .cancel),
            canDismiss: true,
            dropDown: dropDown
        )

        state.hub.alertEvents.send(.present(alert))
    }

    private func saveUnitSystem(_ unitSystem: SQUnitSystem) async {
        let previousUnitSystem = currentUnitSystem
        SQUserDefaults.shared.setPreferredUnitSystem(unitSystem)

        if let user = userState.loggedInUser {
            let updatedUser = SQUser(
                id: user.id,
                createdAt: user.createdAt,
                name: user.name,
                email: user.email,
                firstName: user.firstName,
                lastName: user.lastName,
                dateOfBirth: user.dateOfBirth,
                heightCentimeters: user.heightCentimeters,
                weightKilograms: user.weightKilograms,
                unitSystem: unitSystem,
                sleepSchedule: user.sleepSchedule,
                subscriptionLevel: user.subscriptionLevel,
                onboardingCompletedAt: user.onboardingCompletedAt,
                onboardingStatus: user.onboardingStatus
            )

            do {
                let savedUser = try await userManager.saveUser(updatedUser)
                userState.updateLoggedInUser(savedUser, hasLoadedProfile: true)
                state.hub.userEvents.send(.profileUpdated)
            } catch {
                state.hub.alertEvents.send(.present(.init(error as? SQUserFacingError ?? SQError.standard)))
                return
            }
        }

        buildRows()
        if unitSystem != previousUnitSystem {
            SQAnalyticsManager.shared.track(.unitsChanged(unitSystem: unitSystem))
        }
        state.hub.toastEvents.send(.present(.init(title: "Units updated", style: .success)))
    }

    func popView() {
        if !navigationPath.isEmpty {
            navigationPath.removeLast()
        }
    }
}

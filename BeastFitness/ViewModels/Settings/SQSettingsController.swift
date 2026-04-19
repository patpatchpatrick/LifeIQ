//
//  SQSettingsController.swift
//  BeastFitness
//
//  Created by Patrick Doyle on 12/17/25.
//

import SwiftUI
import UIKit
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
    private(set) var sections: [SQSettingsSectionViewModel] = []

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
        buildSections()
    }

    private func buildSections() {
        var builtSections: [SQSettingsSectionViewModel] = []
        var accountRows: [SQSettingsRowViewModel] = []

        if userState.isLoggedIn {
            accountRows.append(
                .init(
                    title: "Edit profile stats",
                    subtitle: "Update your name, height, weight, birth date, and sleep schedule.",
                    icon: .personCircle,
                    showsChevron: true
                ) { [weak self] in
                    guard let self else { return }
                    SQAnalyticsManager.shared.track(.settingsActionTaken(action: "edit_profile_stats"))
                    let controller = SQOnboardingController(mode: .editProfile)
                    self.state.hub.domainEvents.send(.pushDashboardRoute(.onboarding(controller: controller)))
                }
            )

            accountRows.append(
                .init(
                    title: "Delete account",
                    subtitle: "Permanently delete your LifeIQ account and app-managed data.",
                    icon: .trash,
                    showsChevron: true
                ) { [weak self] in
                    guard let self else { return }
                    SQAnalyticsManager.shared.track(.settingsActionTaken(action: "delete_account"))
                    let controller = SQDeleteAccountController()
                    self.state.hub.domainEvents.send(.pushDashboardRoute(.deleteAccount(controller: controller)))
                }
            )
        }

        if !accountRows.isEmpty {
            builtSections.append(.init(title: "Account", rows: accountRows))
        }

        let preferenceRows: [SQSettingsRowViewModel] = [
            .init(
                title: "Units",
                subtitle: "Currently \(currentUnitSystem.title).",
                icon: .sliderHorizontal3,
                showsChevron: true
            ) { [weak self] in
                SQAnalyticsManager.shared.track(.settingsActionTaken(action: "units"))
                self?.presentUnitSystemPicker()
            },

            .init(
                title: "Customize dashboard",
                subtitle: "Reorder, hide, and restore dashboard sections and subsections.",
                icon: .circleGrid2x2,
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
                icon: .eye,
                showsChevron: false
            ) { [weak self] in
                SQAnalyticsManager.shared.track(.settingsActionTaken(action: "clear_hidden_workouts"))
                self?.confirmClearHiddenWorkouts()
            }
        ]

        builtSections.append(.init(title: "App Preferences", rows: preferenceRows))

        let supportRows: [SQSettingsRowViewModel] = [
            .init(
                title: "Help & Support",
                subtitle: "Email support@lifeiq.app if you need help or want to report a bug.",
                icon: .questionmarkCircle,
                showsChevron: true
            ) { [weak self] in
                SQAnalyticsManager.shared.track(.settingsActionTaken(action: "help_support"))
                self?.openSupportEmail()
            },

            .init(
                title: "Privacy Policy",
                subtitle: "Review how LifeIQ collects, uses, shares, and deletes your data.",
                icon: .infoCircle,
                showsChevron: true
            ) { [weak self] in
                SQAnalyticsManager.shared.track(.settingsActionTaken(action: "privacy_policy"))
                self?.state.hub.domainEvents.send(
                    .pushDashboardRoute(
                        .webContent(title: "Privacy Policy", urlString: SQAppLinks.privacyPolicyURLString)
                    )
                )
            },

            .init(
                title: "Send Feedback",
                subtitle: "We'd love to hear what's working, what's not, and what you'd like to see next.",
                icon: .faceSmiling,
                showsChevron: true
            ) { [weak self] in
                SQAnalyticsManager.shared.track(.settingsActionTaken(action: "send_feedback"))
                self?.openFeedbackEmail()
            }
        ]

        builtSections.append(.init(title: "Support", rows: supportRows))

        sections = builtSections
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

        if userState.isLoggedIn {
            do {
                try SQRemoteConfigManager.shared.assertServerWritesEnabled()
            } catch {
                state.hub.alertEvents.send(.present(.init(error as? SQUserFacingError ?? SQError.standard)))
                return
            }
        }

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

        buildSections()
        if unitSystem != previousUnitSystem {
            SQAnalyticsManager.shared.track(.unitsChanged(unitSystem: unitSystem))
        }
        state.hub.toastEvents.send(.present(.init(title: "Units updated", style: .success)))
    }

    private func openSupportEmail() {
        openEmail(
            subject: "LifeIQ Support",
            fallbackTitle: "Contact Support",
            fallbackSubtitle: "Email \(SQError.supportEmail) and we’ll get back to you as soon as we can.",
            copiedToastTitle: "Support email copied"
        )
    }

    private func openFeedbackEmail() {
        openEmail(
            subject: "LifeIQ Feedback",
            fallbackTitle: "Send Feedback",
            fallbackSubtitle: "Email \(SQError.supportEmail) to share feedback, report friction, or request a feature.",
            copiedToastTitle: "Feedback email copied"
        )
    }

    private func openEmail(
        subject: String,
        fallbackTitle: String,
        fallbackSubtitle: String,
        copiedToastTitle: String
    ) {
        let encodedSubject = subject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        guard let url = URL(string: "mailto:\(SQError.supportEmail)?subject=\(encodedSubject)") else {
            presentEmailFallback(
                title: fallbackTitle,
                subtitle: fallbackSubtitle,
                copiedToastTitle: copiedToastTitle
            )
            return
        }

        guard UIApplication.shared.canOpenURL(url) else {
            presentEmailFallback(
                title: fallbackTitle,
                subtitle: fallbackSubtitle,
                copiedToastTitle: copiedToastTitle
            )
            return
        }

        UIApplication.shared.open(url)
    }

    private func presentEmailFallback(
        title: String,
        subtitle: String,
        copiedToastTitle: String
    ) {
        let alert = SQAlertViewModel(
            title: title,
            subtitle: subtitle,
            primary: .init(title: "Copy Email") { [weak self] _ in
                UIPasteboard.general.string = SQError.supportEmail
                self?.state.hub.toastEvents.send(.present(.init(title: copiedToastTitle, style: .success)))
            },
            secondary: .init(title: "Close", role: .cancel),
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

//
//  SQOnboardingController.swift
//  BeastFitness
//

import Foundation
import SwiftUI
import BeastFitnessCore

@MainActor
@Observable final class SQOnboardingController: Identifiable {
    enum Mode {
        case setup
        case editProfile
    }

    let id = UUID().uuidString
    let hub: EventHub
    let userState: SQUserStating

    let mode: Mode
    var isLoading = false
    var includesDateOfBirth: Bool
    var selectedDateOfBirth: Date
    var selectedSleepTime: Date
    var selectedWakeTime: Date

    let firstNameField: SQUITextFieldViewModel
    let lastNameField: SQUITextFieldViewModel
    let heightFeetField: SQUITextFieldViewModel
    let heightInchesField: SQUITextFieldViewModel
    let weightField: SQUITextFieldViewModel

    private let userManager: SQUserManaging

    init(
        mode: Mode = .setup,
        userState: SQUserStating = SQAppState.shared.userState,
        userManager: SQUserManaging = SQUserManager.shared,
        hub: EventHub = SQAppState.shared.hub
    ) {
        self.mode = mode
        self.userState = userState
        self.userManager = userManager
        self.hub = hub

        let existingUser = userState.loggedInUser
        let initialDateOfBirth = existingUser?.dateOfBirth ?? Calendar.current.date(byAdding: .year, value: -25, to: .now) ?? .now
        let initialSleepSchedule = existingUser?.sleepSchedule ?? .onboardingDefault

        self.includesDateOfBirth = existingUser?.dateOfBirth != nil || existingUser?.onboardingStatus != .completed
        self.selectedDateOfBirth = initialDateOfBirth
        self.selectedSleepTime = initialSleepSchedule.sleepTime.date(on: .now)
        self.selectedWakeTime = initialSleepSchedule.wakeTime.date(on: .now)

        self.firstNameField = SQUITextFieldViewModel(
            placeholder: "First name",
            font: SQFont(type: .body).uiFont,
            keyboardType: .default,
            autocapitalizationType: .words,
            autocorrectionType: .no,
            selectAllOnFocus: true,
            textChangeFormatter: .maxLength(40),
            validationRule: nil,
            errorHandler: { _ in nil }
        )
        self.lastNameField = SQUITextFieldViewModel(
            placeholder: "Last name (optional)",
            font: SQFont(type: .body).uiFont,
            keyboardType: .default,
            autocapitalizationType: .words,
            autocorrectionType: .no,
            selectAllOnFocus: true,
            textChangeFormatter: .maxLength(40),
            validationRule: nil,
            errorHandler: { _ in nil }
        )
        self.heightFeetField = SQUITextFieldViewModel(
            placeholder: "Ft",
            font: SQFont(type: .body).uiFont,
            keyboardType: .numberPad,
            autocapitalizationType: .none,
            autocorrectionType: .no,
            selectAllOnFocus: true,
            textChangeFormatter: .integer,
            validationRule: nil,
            errorHandler: { _ in nil }
        )
        self.heightInchesField = SQUITextFieldViewModel(
            placeholder: "In",
            font: SQFont(type: .body).uiFont,
            keyboardType: .numberPad,
            autocapitalizationType: .none,
            autocorrectionType: .no,
            selectAllOnFocus: true,
            textChangeFormatter: .integer,
            validationRule: nil,
            errorHandler: { _ in nil }
        )
        self.weightField = SQUITextFieldViewModel(
            placeholder: "Weight in pounds",
            font: SQFont(type: .body).uiFont,
            keyboardType: .decimalPad,
            autocapitalizationType: .none,
            autocorrectionType: .no,
            selectAllOnFocus: true,
            textChangeFormatter: .decimal(maxDecimalPlaces: 1),
            validationRule: nil,
            errorHandler: { _ in nil }
        )

        firstNameField.setText(existingUser?.firstName ?? "")
        lastNameField.setText(existingUser?.lastName ?? "")
        if let heightInInches = existingUser?.heightInInches {
            let roundedHeight = max(Int(heightInInches.rounded()), 0)
            heightFeetField.setText("\(roundedHeight / 12)")
            heightInchesField.setText("\(roundedHeight % 12)")
        } else {
            heightFeetField.setText("")
            heightInchesField.setText("")
        }
        weightField.setText(existingUser?.weightInPounds.map(Self.format) ?? "")
    }

    var title: String {
        switch mode {
        case .setup:
            return "Complete Setup"
        case .editProfile:
            return "Edit Profile"
        }
    }

    var heroTitle: String {
        switch mode {
        case .setup:
            return "Set up your profile"
        case .editProfile:
            return "Update your profile"
        }
    }

    var heroSubtitle: String {
        switch mode {
        case .setup:
            return "A little more context helps personalize insights, scores, and trends."
        case .editProfile:
            return "Keep your personal stats and sleep schedule current so insights stay accurate."
        }
    }

    var saveButtonTitle: String {
        switch mode {
        case .setup:
            return "Finish Setup"
        case .editProfile:
            return "Save Changes"
        }
    }

    var shouldPreventInteractiveDismiss: Bool {
        mode == .setup
    }

    private var parsedHeightFeet: Int? {
        Int(heightFeetField.text)
    }

    private var parsedHeightInches: Int {
        Int(heightInchesField.text) ?? 0
    }

    private var totalHeightInInches: Double? {
        guard let feet = parsedHeightFeet, feet > 0 else { return nil }
        guard (0...11).contains(parsedHeightInches) else { return nil }
        return Double((feet * 12) + parsedHeightInches)
    }

    var canSave: Bool {
        guard !firstNameField.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return false }
        guard totalHeightInInches != nil else { return false }
        guard let weight = Double(weightField.text), weight > 0 else { return false }
        guard sleepTimeOfDay != wakeTimeOfDay else { return false }
        return true
    }

    var saveDisabledMessage: String? {
        if firstNameField.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "First name is required."
        }
        if parsedHeightFeet == nil || (parsedHeightFeet ?? 0) <= 0 {
            return "Enter a valid height in feet."
        }
        if !(0...11).contains(parsedHeightInches) {
            return "Inches must be between 0 and 11."
        }
        if totalHeightInInches == nil {
            return "Enter a valid height."
        }
        if Double(weightField.text) == nil || (Double(weightField.text) ?? 0) <= 0 {
            return "Enter a valid weight in pounds."
        }
        if sleepTimeOfDay == wakeTimeOfDay {
            return "Sleep time and wake time should be different."
        }
        return nil
    }

    private var sleepTimeOfDay: SQTimeOfDay {
        SQTimeOfDay(date: selectedSleepTime)
    }

    private var wakeTimeOfDay: SQTimeOfDay {
        SQTimeOfDay(date: selectedWakeTime)
    }

    func completeTapped() async {
        guard !isLoading else { return }
        guard canSave else {
            hub.alertEvents.send(.present(.init(SQError.standard(withDescription: saveDisabledMessage ?? "Complete the required fields to continue."))))
            return
        }
        guard let existingUser = userState.loggedInUser else {
            hub.alertEvents.send(.present(.init(SQError.standard(withDescription: "You need to be logged in to finish setup."))))
            return
        }
        guard let height = totalHeightInInches, let weight = Double(weightField.text) else { return }

        isLoading = true
        defer { isLoading = false }

        let trimmedFirstName = firstNameField.text.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedLastName = lastNameField.text.trimmingCharacters(in: .whitespacesAndNewlines)
        let fullName = [trimmedFirstName, trimmedLastName]
            .filter { !$0.isEmpty }
            .joined(separator: " ")

        let updatedUser = SQUser(
            id: existingUser.id,
            name: fullName,
            email: existingUser.email,
            firstName: trimmedFirstName,
            lastName: trimmedLastName.isEmpty ? nil : trimmedLastName,
            dateOfBirth: includesDateOfBirth ? selectedDateOfBirth : nil,
            heightInInches: height,
            weightInPounds: weight,
            sleepSchedule: .init(
                sleepTime: sleepTimeOfDay,
                wakeTime: wakeTimeOfDay
            ),
            subscriptionLevel: existingUser.subscriptionLevel,
            onboardingCompletedAt: .now,
            onboardingStatus: .completed
        )

        do {
            let savedUser = try await userManager.saveUser(updatedUser)
            SQUserDefaults.shared.clearPendingOnboarding(for: savedUser.id)
            userState.updateLoggedInUser(savedUser, hasLoadedProfile: true)

            switch mode {
            case .setup:
                hub.domainEvents.send(.dismissDashboardNavStack)
                hub.toastEvents.send(.present(.init(title: "Setup complete", style: .success)))
            case .editProfile:
                hub.domainEvents.send(.popDashboardRoute)
                hub.toastEvents.send(.present(.init(title: "Profile updated", style: .success)))
            }

            await Task.yield()
            hub.userEvents.send(.profileUpdated)
        } catch {
            hub.alertEvents.send(.present(.init(error as? SQUserFacingError ?? SQError.standard)))
        }
    }

    private static func format(_ value: Double) -> String {
        if value.rounded() == value {
            return "\(Int(value))"
        }
        return String(format: "%.1f", value)
    }
}

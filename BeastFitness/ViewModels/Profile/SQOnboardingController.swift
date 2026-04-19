//
//  SQOnboardingController.swift
//  BeastFitness
//

import Foundation
import SwiftUI
import BeastFitnessCore

@MainActor
@Observable final class SQOnboardingController: Identifiable, SQUITextFieldViewModelDelegate {
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
    var selectedUnitSystem: SQUnitSystem

    let firstNameField: SQUITextFieldViewModel
    let lastNameField: SQUITextFieldViewModel
    let heightFeetField: SQUITextFieldViewModel
    let heightInchesField: SQUITextFieldViewModel
    let weightField: SQUITextFieldViewModel

    private let userManager: SQUserManaging
    private var validationRevision: Int = 0

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
        let initialUnitSystem = SQUnitSystemResolver.resolve(for: existingUser)

        self.includesDateOfBirth = existingUser?.dateOfBirth != nil || existingUser?.onboardingStatus != .completed
        self.selectedDateOfBirth = initialDateOfBirth
        self.selectedSleepTime = initialSleepSchedule.sleepTime.date(on: .now)
        self.selectedWakeTime = initialSleepSchedule.wakeTime.date(on: .now)
        self.selectedUnitSystem = initialUnitSystem

        self.firstNameField = SQUITextFieldViewModel(
            placeholder: "First name",
            font: SQFont(type: .body).uiFont,
            keyboardType: .default,
            autocapitalizationType: .words,
            autocorrectionType: .no,
            returnKeyType: .next,
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
            returnKeyType: .next,
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
            returnKeyType: .next,
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
            returnKeyType: .next,
            selectAllOnFocus: true,
            textChangeFormatter: .integer,
            validationRule: nil,
            errorHandler: { _ in nil }
        )
        self.weightField = SQUITextFieldViewModel(
            placeholder: "Weight",
            font: SQFont(type: .body).uiFont,
            keyboardType: .decimalPad,
            autocapitalizationType: .none,
            autocorrectionType: .no,
            returnKeyType: .done,
            selectAllOnFocus: true,
            textChangeFormatter: .decimal(maxDecimalPlaces: 1),
            validationRule: nil,
            errorHandler: { _ in nil }
        )

        firstNameField.setText(existingUser?.firstName ?? "")
        lastNameField.setText(existingUser?.lastName ?? "")
        applyMeasurementFieldPlaceholders()
        populateMeasurementFields(
            heightCentimeters: existingUser?.heightCentimeters,
            weightKilograms: existingUser?.weightKilograms
        )
        configureFieldDelegates()
        configureKeyboardReturnChain()
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

    var unitSystemOptions: [SQUnitSystem] {
        SQUnitSystem.allCases
    }

    var heightPrimaryLabel: String {
        switch selectedUnitSystem {
        case .imperial:
            return "Ft"
        case .metric:
            return "Cm"
        }
    }

    var heightSecondaryLabel: String? {
        switch selectedUnitSystem {
        case .imperial:
            return "In"
        case .metric:
            return nil
        }
    }

    var showsHeightSecondaryField: Bool {
        selectedUnitSystem == .imperial
    }

    var weightLabel: String {
        switch selectedUnitSystem {
        case .imperial:
            return "Weight (lb)"
        case .metric:
            return "Weight (kg)"
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

    private var canonicalHeightCentimeters: Double? {
        let trimmedPrimary = heightFeetField.text.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedSecondary = heightInchesField.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedPrimary.isEmpty || !trimmedSecondary.isEmpty else { return nil }
        return selectedUnitSystem.canonicalHeight(
            primaryText: heightFeetField.text,
            secondaryText: heightInchesField.text
        )
    }

    private var canonicalWeightKilograms: Double? {
        let trimmedWeight = weightField.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedWeight.isEmpty else { return nil }
        guard let weight = Double(trimmedWeight), weight > 0 else { return nil }
        return selectedUnitSystem.canonicalWeight(fromDisplayWeight: weight)
    }

    var canSave: Bool {
        let _ = validationRevision
        guard !firstNameField.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return false }
        guard sleepTimeOfDay != wakeTimeOfDay else { return false }
        let trimmedHeightPrimary = heightFeetField.text.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedHeightSecondary = heightInchesField.text.trimmingCharacters(in: .whitespacesAndNewlines)
        if (!trimmedHeightPrimary.isEmpty || !trimmedHeightSecondary.isEmpty), canonicalHeightCentimeters == nil {
            return false
        }
        return true
    }

    var saveDisabledMessage: String? {
        let _ = validationRevision
        if firstNameField.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "First name is required."
        }
        let trimmedHeightPrimary = heightFeetField.text.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedHeightSecondary = heightInchesField.text.trimmingCharacters(in: .whitespacesAndNewlines)
        let hasHeightInput = !trimmedHeightPrimary.isEmpty || !trimmedHeightSecondary.isEmpty

        if hasHeightInput, selectedUnitSystem == .imperial {
            if Int(heightFeetField.text) == nil || (Int(heightFeetField.text) ?? 0) <= 0 {
                return "Enter a valid height in feet."
            }
            if !((0...11).contains(Int(heightInchesField.text) ?? 0)) {
                return "Inches must be between 0 and 11."
            }
        } else if hasHeightInput, Double(heightFeetField.text) == nil || (Double(heightFeetField.text) ?? 0) <= 0 {
            return "Enter a valid height in centimeters."
        }
        if hasHeightInput, canonicalHeightCentimeters == nil {
            return "Enter a valid height."
        }
        let trimmedWeight = weightField.text.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedWeight.isEmpty, canonicalWeightKilograms == nil {
            return selectedUnitSystem == .imperial
                ? "Enter a valid weight in pounds."
                : "Enter a valid weight in kilograms."
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
        isLoading = true
        defer { isLoading = false }

        let trimmedFirstName = firstNameField.text.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedLastName = lastNameField.text.trimmingCharacters(in: .whitespacesAndNewlines)
        let fullName = [trimmedFirstName, trimmedLastName]
            .filter { !$0.isEmpty }
            .joined(separator: " ")

        let updatedUser = SQUser(
            id: existingUser.id,
            createdAt: existingUser.createdAt,
            name: fullName,
            email: existingUser.email,
            firstName: trimmedFirstName,
            lastName: trimmedLastName.isEmpty ? nil : trimmedLastName,
            dateOfBirth: includesDateOfBirth ? selectedDateOfBirth : nil,
            heightCentimeters: canonicalHeightCentimeters,
            weightKilograms: canonicalWeightKilograms,
            unitSystem: selectedUnitSystem,
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
            SQUserDefaults.shared.setPreferredUnitSystem(savedUser.unitSystem)
            SQUserDefaults.shared.clearPendingOnboarding(for: savedUser.id)
            userState.updateLoggedInUser(
                savedUser,
                hasLoadedProfile: true,
                emailVerificationRequirement: userState.emailVerificationRequirement
            )

            switch mode {
            case .setup:
                SQAnalyticsManager.shared.track(.onboardingCompleted(
                    unitSystem: selectedUnitSystem,
                    includesDateOfBirth: includesDateOfBirth
                ))
                hub.domainEvents.send(.dismissDashboardNavStack)
                hub.toastEvents.send(.present(.init(title: "Setup complete", style: .success)))
            case .editProfile:
                SQAnalyticsManager.shared.track(.profileUpdated(source: "onboarding_edit_profile"))
                hub.domainEvents.send(.popDashboardRoute)
                hub.toastEvents.send(.present(.init(title: "Profile updated", style: .success)))
            }

            await Task.yield()
            hub.userEvents.send(.profileUpdated)
        } catch {
            hub.alertEvents.send(.present(.init(error as? SQUserFacingError ?? SQError.standard)))
        }
    }

    func updateUnitSystem(_ newValue: SQUnitSystem) {
        guard newValue != selectedUnitSystem else { return }

        let currentCanonicalHeight = canonicalHeightCentimeters
        let currentCanonicalWeight = canonicalWeightKilograms

        selectedUnitSystem = newValue
        applyMeasurementFieldPlaceholders()
        populateMeasurementFields(
            heightCentimeters: currentCanonicalHeight,
            weightKilograms: currentCanonicalWeight
        )
        SQUserDefaults.shared.setPreferredUnitSystem(newValue)
    }

    private func configureKeyboardReturnChain() {
        firstNameField.onReturn = { [weak lastNameField] in
            lastNameField?.focus()
        }
        lastNameField.onReturn = { [weak heightFeetField] in
            heightFeetField?.focus()
        }
        heightFeetField.onReturn = { [weak self] in
            guard let self else { return }
            if self.showsHeightSecondaryField {
                self.heightInchesField.focus()
            } else {
                self.weightField.focus()
            }
        }
        heightInchesField.onReturn = { [weak weightField] in
            weightField?.focus()
        }
        weightField.onReturn = { [weak self] in
            Task { @MainActor in
                await self?.completeTapped()
            }
        }
    }

    private func configureFieldDelegates() {
        [
            firstNameField,
            lastNameField,
            heightFeetField,
            heightInchesField,
            weightField
        ].forEach { $0.delegate = self }
    }

    private func applyMeasurementFieldPlaceholders() {
        switch selectedUnitSystem {
        case .imperial:
            heightFeetField.setPlaceholder("5")
            heightInchesField.setPlaceholder("0")
            weightField.setPlaceholder("Weight in pounds")
        case .metric:
            heightFeetField.setPlaceholder("175")
            heightInchesField.setPlaceholder("")
            weightField.setPlaceholder("Weight in kilograms")
        }
    }

    private func populateMeasurementFields(
        heightCentimeters: Double?,
        weightKilograms: Double?
    ) {
        heightFeetField.setText(selectedUnitSystem.displayHeightPrimary(fromCentimeters: heightCentimeters))
        heightInchesField.setText(selectedUnitSystem.displayHeightSecondary(fromCentimeters: heightCentimeters))
        weightField.setText(
            selectedUnitSystem
                .displayWeight(fromKilograms: weightKilograms)
                .map(Self.format) ?? ""
        )
    }

    private static func format(_ value: Double) -> String {
        if value.rounded() == value {
            return "\(Int(value))"
        }
        return String(format: "%.1f", value)
    }

    func squiTextFieldFocused(_ viewModel: SQUITextFieldViewModel) {}

    func squiTextFieldTextChanged(_ viewModel: SQUITextFieldViewModel, text: String) {
        validationRevision += 1
    }

    func squiTextFieldStateChanged(_ viewModel: SQUITextFieldViewModel, state: SQUITextFieldViewModel.TextFieldState) {
        validationRevision += 1
    }
}

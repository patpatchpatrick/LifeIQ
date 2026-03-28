//
//  SQMetricFormViewModel.swift
//  BeastFitness
//

import Foundation
import UIKit
import SwiftData

// MARK: - Navigation Target

enum SQMetricNavTarget: Hashable {
    case create
    case edit(String)   // metric ID
}

// MARK: - Form View Model

@Observable @MainActor
final class SQMetricFormViewModel {

    // MARK: - Mode

    enum Mode {
        case create
        case edit(SQMetricDefinition)
    }

    let mode: Mode

    // MARK: - Validation Row Models

    final class RowViewModel: Identifiable {
        let id = UUID()
        private(set) var isValid: Bool
        var validationStatusChanged: (() -> Void)?
        let isActive: () -> Bool
        let validator: () -> Bool
        let errorMessage: () -> String?

        init(
            isActive: @escaping () -> Bool,
            validator: @escaping () -> Bool,
            errorMessage: @escaping () -> String?
        ) {
            self.isActive = isActive
            self.validator = validator
            self.errorMessage = errorMessage
            self.isValid = validator()
        }

        func updateValidity() {
            setValidity(validator(), notify: true)
        }

        func setValidity(_ newValue: Bool, notify: Bool) {
            guard newValue != isValid else { return }
            isValid = newValue
            if notify {
                validationStatusChanged?()
            }
        }
    }

    // MARK: - Fields

    let titleField: SQUITextFieldViewModel
    let emojiField: SQUITextFieldViewModel

    var selectedKind: SQMetricKind = .scale {
        didSet {
            updateKindMenuSelection()
            kindChanged()
        }
    }
    var selectedUnit: SQMetricUnit = .none {
        didSet {
            updateUnitMenuSelection()
            calculateValidity()
        }
    }
    var selectedGroup: String = SQDefaultGroup.general.rawValue {
        didSet {
            updateGroupMenuSelection()
            calculateValidity()
        }
    }
    var selectedGoalStyle: SQMetricGoalStyle = .justTrack {
        didSet {
            updateGoalMenuSelection()
            calculateValidity()
        }
    }
    var selectedBodyBatteryEffect: SQMetricBodyBatteryEffect = .none {
        didSet {
            updateBodyBatteryMenuSelection()
            calculateValidity()
        }
    }
    /// Which check-in screen(s) this metric appears on. Only configurable in create mode.
    var selectedPeriods: Set<SQMetricPeriod> = [.morning]
    /// When both periods are selected, whether this is a single shared daily value or independent per-session.
    var isSingleDailyValue: Bool = false {
        didSet {
            updateTrackingMenuSelection()
            calculateValidity()
        }
    }
    var isAddingNewGroup: Bool = false

    let newGroupField: SQUITextFieldViewModel
    let minField: SQUITextFieldViewModel
    let maxField: SQUITextFieldViewModel
    let stepField: SQUITextFieldViewModel
    let goalTargetField: SQUITextFieldViewModel
    let goalRangeMinField: SQUITextFieldViewModel
    let goalRangeMaxField: SQUITextFieldViewModel

    var groupMenuViewModel: SQDropDownMenuViewModel
    var unitMenuViewModel: SQDropDownMenuViewModel
    var kindMenuViewModel: SQDropDownMenuViewModel
    var goalMenuViewModel: SQDropDownMenuViewModel
    var bodyBatteryMenuViewModel: SQDropDownMenuViewModel
    var trackingMenuViewModel: SQDropDownMenuViewModel
    let periodMultiSelectViewModel: SQMultiSelectViewModel

    private var rowViewModels: [RowViewModel] = []
    private var titleRowViewModel: RowViewModel?
    private var minRowViewModel: RowViewModel?
    private var maxRowViewModel: RowViewModel?
    private var stepRowViewModel: RowViewModel?

    // MARK: - State

    var isLoading = false
    private(set) var isFormValid = false
    private(set) var saveDisabledMessage: String? = nil

    // MARK: - Dependencies

    private let metricsManager: SQMetricsManaging

    // MARK: - Init

    init(mode: Mode, metricsManager: SQMetricsManaging) {
        self.mode = mode
        self.metricsManager = metricsManager

        var initialSelectedKind: SQMetricKind = .scale
        var initialSelectedUnit: SQMetricUnit = .none
        var initialSelectedGroup: String = SQDefaultGroup.general.rawValue
        var initialSelectedGoalStyle: SQMetricGoalStyle = .justTrack
        var initialSelectedBodyBatteryEffect: SQMetricBodyBatteryEffect = .none
        var initialSelectedPeriods: Set<SQMetricPeriod> = [.morning]
        var initialIsSingleDailyValue: Bool = false

        // Title field
        self.titleField = SQUITextFieldViewModel(
            placeholder: "Metric name",
            font: UIFont.systemFont(ofSize: 16),
            keyboardType: .default,
            autocapitalizationType: .sentences,
            autocorrectionType: .no,
            selectAllOnFocus: false,
            textChangeFormatter: .maxLength(30),
            validationRule: .length(max: 30),
            errorHandler: { text in
                text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Title is required" : nil
            }
        )

        // Emoji field — single grapheme cluster, select-all on focus so tapping replaces
        self.emojiField = SQUITextFieldViewModel(
            placeholder: "Enter an emoji or single character",
            font: SQFont(type: .body).uiFont,
            keyboardType: .default,
            autocapitalizationType: .none,
            autocorrectionType: .no,
            selectAllOnFocus: true,
            textChangeFormatter: .maxLength(1),
            validationRule: nil,
            errorHandler: { _ in nil }
        )

        // Numeric fields — decimal with 1 decimal place
        self.minField = SQUITextFieldViewModel(
            placeholder: "0",
            font: SQFont(type: .body).uiFont,
            keyboardType: .decimalPad,
            autocapitalizationType: .none,
            autocorrectionType: .no,
            selectAllOnFocus: true,
            textChangeFormatter: .decimal(maxDecimalPlaces: 1),
            validationRule: nil,
            errorHandler: { _ in nil }
        )

        self.maxField = SQUITextFieldViewModel(
            placeholder: "10",
            font: SQFont(type: .body).uiFont,
            keyboardType: .decimalPad,
            autocapitalizationType: .none,
            autocorrectionType: .no,
            selectAllOnFocus: true,
            textChangeFormatter: .decimal(maxDecimalPlaces: 1),
            validationRule: nil,
            errorHandler: { _ in nil }
        )

        self.stepField = SQUITextFieldViewModel(
            placeholder: "1",
            font: SQFont(type: .body).uiFont,
            keyboardType: .decimalPad,
            autocapitalizationType: .none,
            autocorrectionType: .no,
            selectAllOnFocus: true,
            textChangeFormatter: .decimal(maxDecimalPlaces: 1),
            validationRule: nil,
            errorHandler: { _ in nil }
        )

        self.goalTargetField = SQUITextFieldViewModel(
            placeholder: "Value",
            font: SQFont(type: .body).uiFont,
            keyboardType: .decimalPad,
            autocapitalizationType: .none,
            autocorrectionType: .no,
            selectAllOnFocus: true,
            textChangeFormatter: .decimal(maxDecimalPlaces: 1),
            validationRule: nil,
            errorHandler: { _ in nil }
        )

        self.goalRangeMinField = SQUITextFieldViewModel(
            placeholder: "Min",
            font: SQFont(type: .body).uiFont,
            keyboardType: .decimalPad,
            autocapitalizationType: .none,
            autocorrectionType: .no,
            selectAllOnFocus: true,
            textChangeFormatter: .decimal(maxDecimalPlaces: 1),
            validationRule: nil,
            errorHandler: { _ in nil }
        )

        self.goalRangeMaxField = SQUITextFieldViewModel(
            placeholder: "Max",
            font: SQFont(type: .body).uiFont,
            keyboardType: .decimalPad,
            autocapitalizationType: .none,
            autocorrectionType: .no,
            selectAllOnFocus: true,
            textChangeFormatter: .decimal(maxDecimalPlaces: 1),
            validationRule: nil,
            errorHandler: { _ in nil }
        )

        // New group text input
        self.newGroupField = SQUITextFieldViewModel(
            placeholder: "Group name",
            font: SQFont(type: .body).uiFont,
            keyboardType: .default,
            autocapitalizationType: .sentences,
            autocorrectionType: .no,
            selectAllOnFocus: true,
            textChangeFormatter: .maxLength(20),
            validationRule: nil,
            errorHandler: { _ in nil }
        )

        // Populate from existing definition in edit mode
        if case .edit(let existing) = mode {
            titleField.setText(existing.title)
            emojiField.setText(existing.emoji ?? "")
            initialSelectedKind = existing.kind
            initialSelectedUnit = existing.unit
            initialSelectedGroup = existing.group
            initialSelectedGoalStyle = existing.goalStyle
            initialSelectedBodyBatteryEffect = existing.bodyBatteryEffect
            initialSelectedPeriods = existing.periods
            initialIsSingleDailyValue = existing.isSingleDailyValue
            minField.setText(existing.min.map { Self.formatFloat($0) } ?? "")
            maxField.setText(existing.max.map { Self.formatFloat($0) } ?? "")
            stepField.setText(existing.step.map { Self.formatFloat($0) } ?? "")
            goalTargetField.setText(existing.targetValue.map { Self.formatFloat($0) } ?? "")
            goalRangeMinField.setText(existing.targetRangeMin.map { Self.formatFloat($0) } ?? "")
            goalRangeMaxField.setText(existing.targetRangeMax.map { Self.formatFloat($0) } ?? "")
        } else {
            // Default values for create
            minField.setText("0")
            maxField.setText("10")
            stepField.setText("1")
        }

        selectedKind = initialSelectedKind
        selectedUnit = initialSelectedUnit
        selectedGroup = initialSelectedGroup
        selectedGoalStyle = initialSelectedGoalStyle
        selectedBodyBatteryEffect = initialSelectedBodyBatteryEffect
        selectedPeriods = initialSelectedPeriods
        isSingleDailyValue = initialIsSingleDailyValue

        let initialGroupItems = Self.computeAvailableGroups(metricsManager: metricsManager, selectedGroup: initialSelectedGroup)
            .map { SQDropDownMenuViewModel.Item(title: $0) }
        self.groupMenuViewModel = SQDropDownMenuViewModel(
            defaultItem: .init(title: initialSelectedGroup),
            items: initialGroupItems
        ) { _ in }

        let unitItems = Self.unitDisplayItems
        self.unitMenuViewModel = SQDropDownMenuViewModel(
            defaultItem: .init(title: Self.displayName(for: initialSelectedUnit)),
            items: unitItems
        ) { _ in }

        let kindItems = Self.kindDisplayItems
        self.kindMenuViewModel = SQDropDownMenuViewModel(
            defaultItem: .init(title: Self.displayName(for: initialSelectedKind)),
            items: kindItems
        ) { _ in }

        let goalItems = Self.goalDisplayItems
        self.goalMenuViewModel = SQDropDownMenuViewModel(
            defaultItem: .init(title: Self.displayName(for: initialSelectedGoalStyle)),
            items: goalItems
        ) { _ in }

        let bodyBatteryItems = Self.bodyBatteryDisplayItems
        self.bodyBatteryMenuViewModel = SQDropDownMenuViewModel(
            defaultItem: .init(title: Self.displayName(for: initialSelectedBodyBatteryEffect)),
            items: bodyBatteryItems
        ) { _ in }

        self.trackingMenuViewModel = SQDropDownMenuViewModel(
            defaultItem: .init(title: Self.displayName(forTrackingShared: initialIsSingleDailyValue)),
            items: Self.trackingDisplayItems
        ) { _ in }

        let periodItems = Self.periodDisplayItems
        let selectedPeriodIds = Set(initialSelectedPeriods.map { $0.rawValue })
        self.periodMultiSelectViewModel = SQMultiSelectViewModel(
            items: periodItems,
            selectedIds: selectedPeriodIds
        )

        configureAfterInit()
    }

    // MARK: - Computed

    var isStructurallyEditable: Bool {
        if case .create = mode { return true }
        return false
    }

    var navigationTitle: String {
        if case .create = mode { return "New Metric" }
        return "Edit Metric"
    }

    /// Whether min/max/step fields should be visible based on current kind
    var showNumericRange: Bool {
        selectedKind == .scale || selectedKind == .number
    }

    /// Whether unit picker should be visible
    var showUnit: Bool {
        selectedKind == .number
    }

    var showGoalTargetField: Bool {
        selectedGoalStyle == .buildUp || selectedGoalStyle == .keepLow
    }

    var showGoalRangeFields: Bool {
        selectedGoalStyle == .stayInRange
    }

    var showsBodyBatteryControls: Bool {
        switch mode {
        case .create:
            return true
        case .edit(let def):
            return !def.isPreset
        }
    }

    var goalTargetLabel: String {
        switch selectedGoalStyle {
        case .buildUp:
            return "At Least"
        case .keepLow:
            return "At Most"
        default:
            return "Target"
        }
    }

    var goalHelperText: String {
        switch selectedGoalStyle {
        case .justTrack:
            return "Shows trend and consistency data without treating any value as a success or failure."
        case .buildUp:
            return "A successful day counts when this metric is at or above the value below."
        case .keepLow:
            return "A successful day counts when this metric is at or below the value below."
        case .avoidIt:
            return "A successful day counts when this metric is exactly 0."
        case .stayInRange:
            return "A successful day counts when this metric stays inside the target range."
        case .unknown:
            return ""
        }
    }

    var bodyBatteryHelperText: String {
        switch selectedBodyBatteryEffect {
        case .none:
            return "Optional. Leave this off unless the metric should meaningfully nudge daily energy or recovery."
        case .boostsWhenHigh:
            return "Higher values will lift Body Battery. The impact is normalized to this metric’s range and aggressively capped."
        case .drainsWhenHigh:
            return "Higher values will drain Body Battery. The impact is normalized to this metric’s range and aggressively capped."
        case .unknown:
            return ""
        }
    }

    var bodyBatterySummary: String? {
        let title = titleField.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? "This metric"
            : titleField.text

        switch selectedBodyBatteryEffect {
        case .none:
            return nil
        case .boostsWhenHigh:
            return "\(title) will help Body Battery when you log higher values."
        case .drainsWhenHigh:
            return "\(title) will lower Body Battery when you log higher values."
        case .unknown:
            return nil
        }
    }

    var goalSuccessSummary: String? {
        let title = titleField.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? "this metric"
            : titleField.text

        switch selectedGoalStyle {
        case .justTrack:
            return nil
        case .buildUp:
            guard let target = parsedGoalTargetValue else { return nil }
            return "Successful day: \(title) >= \(Self.formatFloat(target))"
        case .keepLow:
            guard let target = parsedGoalTargetValue else { return nil }
            return "Successful day: \(title) <= \(Self.formatFloat(target))"
        case .avoidIt:
            return "Successful day: \(title) = 0"
        case .stayInRange:
            guard let min = parsedGoalRangeMin, let max = parsedGoalRangeMax else { return nil }
            return "Successful day: \(title) between \(Self.formatFloat(min)) and \(Self.formatFloat(max))"
        case .unknown:
            return nil
        }
    }

    /// All unique groups currently in use, plus well-known defaults, sorted alphabetically.
    /// Excludes legacy and unknown groups so they don't appear in the picker.
    var availableGroups: [String] {
        Self.computeAvailableGroups(metricsManager: metricsManager, selectedGroup: selectedGroup)
    }

    /// Metric kinds available to users when creating a metric.
    /// `.binary` is retired (all metrics use scale 0–10); `.unknown` is a decode fallback only.
    var selectableKinds: [SQMetricKind] {
        [.scale, .number]
    }

    var canSave: Bool {
        isFormValid
    }

    var periodDisplayValue: String {
        let periods = selectedPeriods
        if periods.contains(.morning) && periods.contains(.evening) {
            return isSingleDailyValue ? "Morning & Evening (Shared)" : "Morning & Evening"
        } else if periods.contains(.evening) {
            return "Evening"
        } else if periods.contains(.morning) {
            return "Morning"
        } else {
            return "None"
        }
    }

    var trackingHelperText: String {
        isSingleDailyValue
            ? "Shared means both check-ins edit the same daily value. Use this for things like weight or last night’s sleep."
            : "Independent means morning and evening each keep their own value. Use this for signals that can change through the day."
    }

    var currentKind: SQMetricKind {
        if case .edit(let def) = mode { return def.kind }
        return selectedKind
    }

    var currentUnit: SQMetricUnit {
        if case .edit(let def) = mode { return def.unit }
        return selectedUnit
    }

    var currentMin: String {
        if case .edit(let def) = mode { return def.min.map { Self.formatFloat($0) } ?? "—" }
        return minField.text
    }

    var currentMax: String {
        if case .edit(let def) = mode { return def.max.map { Self.formatFloat($0) } ?? "—" }
        return maxField.text
    }

    var currentStep: String {
        if case .edit(let def) = mode { return def.step.map { Self.formatFloat($0) } ?? "—" }
        return stepField.text
    }

    // MARK: - Actions

    func saveTapped(using context: ModelContext) async {
        isLoading = true
        defer { isLoading = false }

        do {
            switch mode {
            case .create:
                let definition = buildDefinition()
                try metricsManager.createMetric(definition: definition, using: context)

            case .edit(let existing):
                let emoji = emojiField.text.isEmpty ? nil : emojiField.text
                try metricsManager.updateMetric(
                    id: existing.id,
                    title: titleField.text,
                    emoji: emoji,
                    group: selectedGroup,
                    goalStyle: selectedGoalStyle,
                    targetValue: resolvedGoalTargetValue,
                    targetRangeMin: resolvedGoalRangeMin,
                    targetRangeMax: resolvedGoalRangeMax,
                    bodyBatteryEffect: selectedBodyBatteryEffect,
                    using: context
                )
            }
        } catch {
            // Error handling — caller can observe isLoading reset
        }
    }

    // MARK: - Delete

    var canDelete: Bool {
        if case .edit = mode { return true }
        return false
    }

    func deleteTapped(using context: ModelContext) {
        guard case .edit(let existing) = mode else { return }
        do {
            try metricsManager.archiveMetric(id: existing.id, using: context)
        } catch {}
    }

    // MARK: - Private

    private func setupRowViewModels() {
        let titleRow = RowViewModel(
            isActive: { true },
            validator: { [weak self] in
                guard let self else { return false }
                return !self.titleField.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            },
            errorMessage: { "Title is required." }
        )

        let minRow = RowViewModel(
            isActive: { [weak self] in
                guard let self else { return false }
                return self.isStructurallyEditable && self.showNumericRange
            },
            validator: { [weak self] in
                guard let self else { return false }
                return self.validateMinField()
            },
            errorMessage: { [weak self] in
                self?.minFieldErrorMessage()
            }
        )

        let maxRow = RowViewModel(
            isActive: { [weak self] in
                guard let self else { return false }
                return self.isStructurallyEditable && self.showNumericRange
            },
            validator: { [weak self] in
                guard let self else { return false }
                return self.validateMaxField()
            },
            errorMessage: { [weak self] in
                self?.maxFieldErrorMessage()
            }
        )

        let stepRow = RowViewModel(
            isActive: { [weak self] in
                guard let self else { return false }
                return self.isStructurallyEditable && self.showNumericRange
            },
            validator: { [weak self] in
                guard let self else { return false }
                return self.validateStepField()
            },
            errorMessage: { [weak self] in
                self?.stepFieldErrorMessage()
            }
        )

        rowViewModels = [titleRow, minRow, maxRow, stepRow]
        titleRowViewModel = titleRow
        minRowViewModel = minRow
        maxRowViewModel = maxRow
        stepRowViewModel = stepRow

        rowViewModels.forEach { row in
            row.validationStatusChanged = { [weak self] in
                self?.calculateValidity()
            }
        }
    }

    private func calculateValidity() {
        let activeRows = rowViewModels.filter { $0.isActive() }
        activeRows.forEach { $0.setValidity($0.validator(), notify: false) }

        var firstError: String? = activeRows.first(where: { !$0.isValid })?.errorMessage()

        if firstError == nil, case .create = mode {
            if selectedPeriods.isEmpty {
                firstError = "Select at least one check-in period."
            }
        }

        if firstError == nil, case .create = mode {
            switch selectedKind {
            case .scale:
                let result = validateScaleFieldsDetailed()
                if !result.isValid { firstError = result.message }
            case .number:
                let result = validateNumberFieldsDetailed()
                if !result.isValid { firstError = result.message }
            default:
                firstError = "Metric type is invalid."
            }
        }

        if firstError == nil {
            let result = validateGoalFieldsDetailed()
            if !result.isValid { firstError = result.message }
        }

        if firstError == nil {
            let result = validateBodyBatteryFieldsDetailed()
            if !result.isValid { firstError = result.message }
        }

        isFormValid = firstError == nil
        saveDisabledMessage = isFormValid ? nil : (firstError ?? "Please fix the errors above.")
    }

    private func configureAfterInit() {
        // Wire delegates for validation updates
        titleField.delegate = self
        minField.delegate = self
        maxField.delegate = self
        stepField.delegate = self
        goalTargetField.delegate = self
        goalRangeMinField.delegate = self
        goalRangeMaxField.delegate = self
        newGroupField.delegate = self

        groupMenuViewModel = SQDropDownMenuViewModel(
            defaultItem: .init(title: selectedGroup),
            items: availableGroups.map { SQDropDownMenuViewModel.Item(title: $0) }
        ) { [weak self] title in
            self?.selectedGroup = title
        }

        unitMenuViewModel = SQDropDownMenuViewModel(
            defaultItem: .init(title: Self.displayName(for: selectedUnit)),
            items: Self.unitDisplayItems
        ) { [weak self] title in
            self?.selectedUnit = Self.unit(fromDisplayName: title)
        }

        kindMenuViewModel = SQDropDownMenuViewModel(
            defaultItem: .init(title: Self.displayName(for: selectedKind)),
            items: Self.kindDisplayItems
        ) { [weak self] title in
            self?.selectedKind = Self.kind(fromDisplayName: title)
        }

        goalMenuViewModel = SQDropDownMenuViewModel(
            defaultItem: .init(title: Self.displayName(for: selectedGoalStyle)),
            items: Self.goalDisplayItems
        ) { [weak self] title in
            self?.selectedGoalStyle = Self.goalStyle(fromDisplayName: title)
        }

        bodyBatteryMenuViewModel = SQDropDownMenuViewModel(
            defaultItem: .init(title: Self.displayName(for: selectedBodyBatteryEffect)),
            items: Self.bodyBatteryDisplayItems
        ) { [weak self] title in
            self?.selectedBodyBatteryEffect = Self.bodyBatteryEffect(fromDisplayName: title)
        }

        trackingMenuViewModel = SQDropDownMenuViewModel(
            defaultItem: .init(title: Self.displayName(forTrackingShared: isSingleDailyValue)),
            items: Self.trackingDisplayItems
        ) { [weak self] title in
            self?.isSingleDailyValue = Self.isTrackingShared(fromDisplayName: title)
        }

        periodMultiSelectViewModel.selectionChanged = { [weak self] selectedIds in
            guard let self else { return }
            let periods = Set(selectedIds.compactMap { SQMetricPeriod(rawValue: $0) })
            self.selectedPeriods = periods
            if self.selectedPeriods.count < 2 {
                self.isSingleDailyValue = false
                self.updateTrackingMenuSelection()
            }
            self.calculateValidity()
        }

        setupRowViewModels()
        calculateValidity()
    }

    private static func computeAvailableGroups(metricsManager: SQMetricsManaging, selectedGroup: String) -> [String] {
        let legacyAndUnknown: Set<String> = [
            SQDefaultGroup.unknown.rawValue,
            SQDefaultGroup.habit.rawValue,
            SQDefaultGroup.personal.rawValue,
        ]

        let fromMetrics = metricsManager.allMetrics(includeArchived: false)
            .map(\.group)
            .filter { !legacyAndUnknown.contains($0) }

        let wellKnown = SQDefaultGroup.allCases
            .map(\.rawValue)
            .filter { !legacyAndUnknown.contains($0) }

        var unique = Array(Set(fromMetrics + wellKnown + [selectedGroup]))
        unique = unique.filter { !legacyAndUnknown.contains($0) }
        return unique.sorted()
    }

    private func updateGroupMenuSelection() {
        let title = selectedGroup
        if groupMenuViewModel.mainButton.title != title {
            groupMenuViewModel.defaultItem = .init(title: title)
        }
    }

    private func refreshGroupMenuViewModel() {
        let items = availableGroups.map { SQDropDownMenuViewModel.Item(title: $0) }
        groupMenuViewModel = SQDropDownMenuViewModel(
            defaultItem: .init(title: selectedGroup),
            items: items
        ) { [weak self] title in
            self?.selectedGroup = title
        }
    }

    private func updateUnitMenuSelection() {
        let title = Self.displayName(for: selectedUnit)
        if unitMenuViewModel.mainButton.title != title {
            unitMenuViewModel.defaultItem = .init(title: title)
        }
    }

    private func updateKindMenuSelection() {
        let title = Self.displayName(for: selectedKind)
        if kindMenuViewModel.mainButton.title != title {
            kindMenuViewModel.defaultItem = .init(title: title)
        }
    }

    private func updateGoalMenuSelection() {
        let title = Self.displayName(for: selectedGoalStyle)
        if goalMenuViewModel.mainButton.title != title {
            goalMenuViewModel.defaultItem = .init(title: title)
        }
    }

    private func updateBodyBatteryMenuSelection() {
        let title = Self.displayName(for: selectedBodyBatteryEffect)
        if bodyBatteryMenuViewModel.mainButton.title != title {
            bodyBatteryMenuViewModel.defaultItem = .init(title: title)
        }
    }

    private func updateTrackingMenuSelection() {
        let title = Self.displayName(forTrackingShared: isSingleDailyValue)
        if trackingMenuViewModel.mainButton.title != title {
            trackingMenuViewModel.defaultItem = .init(title: title)
        }
    }

    private func buildDefinition() -> SQMetricDefinition {
        let emoji = emojiField.text.isEmpty ? nil : emojiField.text

        switch selectedKind {
        case .scale:
            return .init(
                id: SQMetricId.custom(),
                title: titleField.text,
                kind: .scale,
                unit: .none,
                group: selectedGroup,
                min: Float(minField.text),
                max: Float(maxField.text),
                step: Float(stepField.text),
                isPreset: false,
                isEnabled: true,
                sortOrder: 0,
                isArchived: false,
                emoji: emoji,
                periods: selectedPeriods,
                isSingleDailyValue: isSingleDailyValue,
                goalStyle: selectedGoalStyle,
                targetValue: resolvedGoalTargetValue,
                targetRangeMin: resolvedGoalRangeMin,
                targetRangeMax: resolvedGoalRangeMax,
                bodyBatteryEffect: selectedBodyBatteryEffect
            )

        case .number:
            return .init(
                id: SQMetricId.custom(),
                title: titleField.text,
                kind: .number,
                unit: selectedUnit,
                group: selectedGroup,
                min: minField.text.isEmpty ? nil : Float(minField.text),
                max: maxField.text.isEmpty ? nil : Float(maxField.text),
                step: stepField.text.isEmpty ? nil : Float(stepField.text),
                isPreset: false,
                isEnabled: true,
                sortOrder: 0,
                isArchived: false,
                emoji: emoji,
                periods: selectedPeriods,
                isSingleDailyValue: isSingleDailyValue,
                goalStyle: selectedGoalStyle,
                targetValue: resolvedGoalTargetValue,
                targetRangeMin: resolvedGoalRangeMin,
                targetRangeMax: resolvedGoalRangeMax,
                bodyBatteryEffect: selectedBodyBatteryEffect
            )

        default:
            // .binary and .unknown should never be user-created; fall back to scale
            return .init(
                id: SQMetricId.custom(),
                title: titleField.text,
                kind: .scale,
                unit: .none,
                group: selectedGroup,
                min: 0, max: 10, step: 1,
                isPreset: false,
                isEnabled: true,
                sortOrder: 0,
                isArchived: false,
                emoji: emoji,
                periods: selectedPeriods,
                isSingleDailyValue: isSingleDailyValue,
                goalStyle: selectedGoalStyle,
                targetValue: resolvedGoalTargetValue,
                targetRangeMin: resolvedGoalRangeMin,
                targetRangeMax: resolvedGoalRangeMax,
                bodyBatteryEffect: selectedBodyBatteryEffect
            )
        }
    }

    private func validateScaleFieldsDetailed() -> (isValid: Bool, message: String?) {
        guard let min = Float(minField.text), !minField.text.isEmpty else {
            return (false, "Min is required for scale.")
        }
        guard let max = Float(maxField.text), !maxField.text.isEmpty else {
            return (false, "Max is required for scale.")
        }
        guard let step = Float(stepField.text), !stepField.text.isEmpty else {
            return (false, "Step is required for scale.")
        }
        guard max > min else { return (false, "Max must be greater than Min.") }
        guard step > 0 else { return (false, "Step must be greater than 0.") }
        guard step <= (max - min) else { return (false, "Step must be less than or equal to Max - Min.") }
        return (true, nil)
    }

    private func validateNumberFieldsDetailed() -> (isValid: Bool, message: String?) {
        if !minField.text.isEmpty, Float(minField.text) == nil {
            return (false, "Min must be a number.")
        }
        if !maxField.text.isEmpty, Float(maxField.text) == nil {
            return (false, "Max must be a number.")
        }
        if !stepField.text.isEmpty, Float(stepField.text) == nil {
            return (false, "Step must be a number.")
        }
        if let min = Float(minField.text), let max = Float(maxField.text) {
            guard max > min else { return (false, "Max must be greater than Min.") }
        }
        if let step = Float(stepField.text) {
            guard step > 0 else { return (false, "Step must be greater than 0.") }
        }
        return (true, nil)
    }

    private func validateGoalFieldsDetailed() -> (isValid: Bool, message: String?) {
        switch selectedGoalStyle {
        case .justTrack, .avoidIt:
            return (true, nil)
        case .buildUp, .keepLow:
            guard let value = parsedGoalTargetValue else {
                return (false, "Enter a value for the selected goal.")
            }
            return validateGoalValueWithinBounds(value, label: "Goal")
        case .stayInRange:
            guard let min = parsedGoalRangeMin else {
                return (false, "Enter a minimum value for the goal range.")
            }
            guard let max = parsedGoalRangeMax else {
                return (false, "Enter a maximum value for the goal range.")
            }
            guard max >= min else {
                return (false, "Goal max must be greater than or equal to goal min.")
            }
            let minValidation = validateGoalValueWithinBounds(min, label: "Goal min")
            if !minValidation.isValid { return minValidation }
            let maxValidation = validateGoalValueWithinBounds(max, label: "Goal max")
            if !maxValidation.isValid { return maxValidation }
            return (true, nil)
        case .unknown:
            return (false, "Select a valid goal.")
        }
    }

    private func validateGoalValueWithinBounds(_ value: Float, label: String) -> (isValid: Bool, message: String?) {
        if let min = metricLowerBound, value < min {
            return (false, "\(label) must be at least \(Self.formatFloat(min)).")
        }
        if let max = metricUpperBound, value > max {
            return (false, "\(label) must be at most \(Self.formatFloat(max)).")
        }
        return (true, nil)
    }

    private func validateBodyBatteryFieldsDetailed() -> (isValid: Bool, message: String?) {
        guard showsBodyBatteryControls else { return (true, nil) }
        guard selectedBodyBatteryEffect != .none else { return (true, nil) }

        guard let min = metricLowerBound, let max = metricUpperBound else {
            return (false, "Body Battery metrics need both Min and Max values so their impact can be normalized.")
        }

        guard max > min else {
            return (false, "Body Battery metrics need Max to be greater than Min.")
        }

        return (true, nil)
    }

    private func validateMinField() -> Bool {
        switch selectedKind {
        case .scale:
            return !minField.text.isEmpty && Float(minField.text) != nil
        case .number:
            return minField.text.isEmpty || Float(minField.text) != nil
        default:
            return true
        }
    }

    private func minFieldErrorMessage() -> String? {
        switch selectedKind {
        case .scale:
            return "Min is required for scale."
        case .number:
            return "Min must be a number."
        default:
            return nil
        }
    }

    private func validateMaxField() -> Bool {
        switch selectedKind {
        case .scale:
            return !maxField.text.isEmpty && Float(maxField.text) != nil
        case .number:
            return maxField.text.isEmpty || Float(maxField.text) != nil
        default:
            return true
        }
    }

    private func maxFieldErrorMessage() -> String? {
        switch selectedKind {
        case .scale:
            return "Max is required for scale."
        case .number:
            return "Max must be a number."
        default:
            return nil
        }
    }

    private func validateStepField() -> Bool {
        switch selectedKind {
        case .scale:
            return !stepField.text.isEmpty && Float(stepField.text) != nil
        case .number:
            return stepField.text.isEmpty || Float(stepField.text) != nil
        default:
            return true
        }
    }

    private func stepFieldErrorMessage() -> String? {
        switch selectedKind {
        case .scale:
            return "Step is required for scale."
        case .number:
            return "Step must be a number."
        default:
            return nil
        }
    }

    // MARK: - Group Management

    func confirmNewGroup() {
        let trimmed = newGroupField.text.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            selectedGroup = trimmed
        }
        isAddingNewGroup = false
        refreshGroupMenuViewModel()
        calculateValidity()
    }

    func cancelNewGroup() {
        isAddingNewGroup = false
        calculateValidity()
    }

    /// Reset numeric defaults when kind changes in create mode
    private func kindChanged() {
        guard isStructurallyEditable else { return }
        switch selectedKind {
        case .scale:
            minField.setText("0")
            maxField.setText("10")
            stepField.setText("1")
        case .number:
            minField.setText("")
            maxField.setText("")
            stepField.setText("")
        default:
            break
        }
        calculateValidity()
    }

    private var metricLowerBound: Float? {
        if case .edit(let def) = mode { return def.min }
        return Float(minField.text)
    }

    private var metricUpperBound: Float? {
        if case .edit(let def) = mode { return def.max }
        return Float(maxField.text)
    }

    private var parsedGoalTargetValue: Float? {
        goalTargetField.text.isEmpty ? nil : Float(goalTargetField.text)
    }

    private var parsedGoalRangeMin: Float? {
        goalRangeMinField.text.isEmpty ? nil : Float(goalRangeMinField.text)
    }

    private var parsedGoalRangeMax: Float? {
        goalRangeMaxField.text.isEmpty ? nil : Float(goalRangeMaxField.text)
    }

    private var resolvedGoalTargetValue: Float? {
        switch selectedGoalStyle {
        case .buildUp, .keepLow:
            return parsedGoalTargetValue
        default:
            return nil
        }
    }

    private var resolvedGoalRangeMin: Float? {
        selectedGoalStyle == .stayInRange ? parsedGoalRangeMin : nil
    }

    private var resolvedGoalRangeMax: Float? {
        selectedGoalStyle == .stayInRange ? parsedGoalRangeMax : nil
    }

    private static func formatFloat(_ value: Float) -> String {
        if value.rounded() == value { return "\(Int(value))" }
        return String(format: "%.1f", Double(value))
    }

    private static var unitDisplayItems: [SQDropDownMenuViewModel.Item] {
        SQMetricUnit.allCases
            .filter { $0 != .unknown }
            .map { SQDropDownMenuViewModel.Item(title: displayName(for: $0)) }
    }

    private static var kindDisplayItems: [SQDropDownMenuViewModel.Item] {
        selectableKindsStatic
            .map { SQDropDownMenuViewModel.Item(title: displayName(for: $0)) }
    }

    private static var goalDisplayItems: [SQDropDownMenuViewModel.Item] {
        [
            .init(title: displayName(for: .justTrack)),
            .init(title: displayName(for: .buildUp)),
            .init(title: displayName(for: .keepLow)),
            .init(title: displayName(for: .avoidIt)),
            .init(title: displayName(for: .stayInRange)),
        ]
    }

    private static var bodyBatteryDisplayItems: [SQDropDownMenuViewModel.Item] {
        [
            .init(title: displayName(for: SQMetricBodyBatteryEffect.none)),
            .init(title: displayName(for: SQMetricBodyBatteryEffect.boostsWhenHigh)),
            .init(title: displayName(for: SQMetricBodyBatteryEffect.drainsWhenHigh)),
        ]
    }

    private static var trackingDisplayItems: [SQDropDownMenuViewModel.Item] {
        [
            .init(title: "Independent"),
            .init(title: "Shared")
        ]
    }

    private static var periodDisplayItems: [SQMultiSelectViewModel.Item] {
        [
            .init(id: SQMetricPeriod.morning.rawValue, title: "Morning"),
            .init(id: SQMetricPeriod.evening.rawValue, title: "Evening")
        ]
    }

    private static var selectableKindsStatic: [SQMetricKind] {
        [.scale, .number]
    }

    private static func displayName(for unit: SQMetricUnit) -> String {
        switch unit {
        case .none:
            return "None"
        case .unknown:
            return "Unknown"
        default:
            return unit.rawValue.capitalized
        }
    }

    private static func displayName(for kind: SQMetricKind) -> String {
        kind.rawValue.capitalized
    }

    private static func displayName(for goalStyle: SQMetricGoalStyle) -> String {
        switch goalStyle {
        case .justTrack:
            return "Just Track It"
        case .buildUp:
            return "Build This Up"
        case .keepLow:
            return "Keep This Low"
        case .avoidIt:
            return "Avoid It"
        case .stayInRange:
            return "Stay In A Range"
        case .unknown:
            return "Unknown"
        }
    }

    private static func displayName(for effect: SQMetricBodyBatteryEffect) -> String {
        switch effect {
        case .none:
            return "No Effect"
        case .boostsWhenHigh:
            return "Higher Values Help"
        case .drainsWhenHigh:
            return "Higher Values Hurt"
        case .unknown:
            return "Unknown"
        }
    }

    private static func displayName(forTrackingShared isShared: Bool) -> String {
        isShared ? "Shared" : "Independent"
    }

    private static func unit(fromDisplayName title: String) -> SQMetricUnit {
        if title == "None" { return .none }
        if title == "Unknown" { return .unknown }
        return SQMetricUnit.allCases.first(where: { displayName(for: $0) == title }) ?? .none
    }

    private static func kind(fromDisplayName title: String) -> SQMetricKind {
        selectableKindsStatic.first(where: { displayName(for: $0) == title }) ?? .scale
    }

    private static func goalStyle(fromDisplayName title: String) -> SQMetricGoalStyle {
        [
            SQMetricGoalStyle.justTrack,
            .buildUp,
            .keepLow,
            .avoidIt,
            .stayInRange,
        ].first(where: { displayName(for: $0) == title }) ?? .justTrack
    }

    private static func bodyBatteryEffect(fromDisplayName title: String) -> SQMetricBodyBatteryEffect {
        [
            SQMetricBodyBatteryEffect.none,
            .boostsWhenHigh,
            .drainsWhenHigh,
        ].first(where: { displayName(for: $0) == title }) ?? .none
    }

    private static func isTrackingShared(fromDisplayName title: String) -> Bool {
        title == "Shared"
    }
}

// MARK: - SQUITextFieldViewModelDelegate

extension SQMetricFormViewModel: SQUITextFieldViewModelDelegate {
    func squiTextFieldFocused(_ viewModel: SQUITextFieldViewModel) {
        // No-op
    }

    func squiTextFieldTextChanged(_ viewModel: SQUITextFieldViewModel, text: String) {
        handleFieldChanged(viewModel)
    }

    func squiTextFieldStateChanged(_ viewModel: SQUITextFieldViewModel, state: SQUITextFieldViewModel.TextFieldState) {
        handleFieldChanged(viewModel)
    }

    private func handleFieldChanged(_ viewModel: SQUITextFieldViewModel) {
        if viewModel === titleField {
            titleRowViewModel?.updateValidity()
        } else if viewModel === minField {
            minRowViewModel?.updateValidity()
        } else if viewModel === maxField {
            maxRowViewModel?.updateValidity()
        } else if viewModel === stepField {
            stepRowViewModel?.updateValidity()
        }
        calculateValidity()
    }
}

//
//  SQMetricFormViewModel.swift
//  BeastFitness
//

import Foundation
import UIKit
import SwiftData
import BeastFitnessCore

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

    enum ValidationTarget {
        case title
        case periods
        case tracking
        case kind
        case unit
        case min
        case max
        case step
        case scaleQuantityMax
        case goalTarget
        case goalRangeMin
        case goalRangeMax
        case bodyBattery
        case signalRole
        case healthKitType
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
    var emojiPreviewText: String = ""

    var selectedKind: SQMetricKind = .scale {
        didSet {
            updateKindMenuSelection()
            kindChanged(from: oldValue)
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
    var selectedSignalRole: SQMetricSignalRole = .outcome {
        didSet {
            updateSignalRoleMenuSelection()
            calculateValidity()
        }
    }
    var selectedLifeScoreImpact: SQMetricLifeScoreImpact = .none {
        didSet {
            updateLifeScoreImpactMenuSelection()
            applyLifeScoreImpactDefaultsIfNeeded(from: oldValue)
            calculateValidity()
        }
    }
    private var selectedInsightMode: SQMetricInsightMode = .exploratoryRelationships {
        didSet {
            isInsightsEnabled = selectedInsightMode != .off
            calculateValidity()
        }
    }
    var selectedSensitivity: SQMetricSensitivity = .normal {
        didSet {
            updateSensitivityMenuSelection()
            applySensitivityDefaultsIfNeeded(from: oldValue)
            calculateValidity()
        }
    }
    var isInsightsEnabled: Bool = true {
        didSet {
            guard isInsightsEnabled != oldValue else { return }
            if hasFinishedInitialSetup {
                hasUserChangedInsightsEnabled = true
            }
            selectedInsightMode = isInsightsEnabled
                ? recommendedInsightMode
                : .off
            calculateValidity()
        }
    }
    var selectedHealthKitType: SQMetricHealthKitType = .none {
        didSet {
            updateHealthKitMenuSelection()
            applyHealthKitTypeDefaultsIfNeeded(from: oldValue)
            calculateValidity()
        }
    }
    var isHealthKitReadEnabled: Bool = false {
        didSet {
            calculateValidity()
        }
    }
    var isHealthKitWriteEnabled: Bool = false {
        didSet {
            calculateValidity()
        }
    }
    /// Which check-in screen(s) this metric appears on. Only configurable in create mode.
    var selectedPeriods: Set<SQMetricPeriod> = [.morning, .evening]
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
    let scaleQuantityMaxField: SQUITextFieldViewModel
    let quantityLabelOverrideField: SQUITextFieldViewModel
    let goalTargetField: SQUITextFieldViewModel
    let goalRangeMinField: SQUITextFieldViewModel
    let goalRangeMaxField: SQUITextFieldViewModel

    var isScaleQuantityMappingEnabled: Bool = false {
        didSet {
            calculateValidity()
        }
    }

    var groupMenuViewModel: SQDropDownMenuViewModel
    var unitMenuViewModel: SQDropDownMenuViewModel
    var kindMenuViewModel: SQDropDownMenuViewModel
    var goalMenuViewModel: SQDropDownMenuViewModel
    var bodyBatteryMenuViewModel: SQDropDownMenuViewModel
    var signalRoleMenuViewModel: SQDropDownMenuViewModel
    var lifeScoreImpactMenuViewModel: SQDropDownMenuViewModel
    var sensitivityMenuViewModel: SQDropDownMenuViewModel
    var healthKitMenuViewModel: SQDropDownMenuViewModel
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
    private(set) var validationTarget: ValidationTarget? = nil
    private(set) var scaleQuantityHelperTextDisplay: String = ""
    private(set) var formContentRevision: Int = 0
    private var hasFinishedInitialSetup = false
    private var hasUserChangedInsightsEnabled = false

    // MARK: - Dependencies

    private let metricsManager: SQMetricDefinitionManaging

    // MARK: - Init

    init(mode: Mode, metricsManager: SQMetricDefinitionManaging) {
        self.mode = mode
        self.metricsManager = metricsManager

        var initialSelectedKind: SQMetricKind = .scale
        var initialSelectedUnit: SQMetricUnit = .none
        var initialSelectedGroup: String = SQDefaultGroup.general.rawValue
        var initialSelectedGoalStyle: SQMetricGoalStyle = .justTrack
        var initialSelectedBodyBatteryEffect: SQMetricBodyBatteryEffect = .none
        var initialSelectedSignalRole: SQMetricSignalRole = .outcome
        var initialSelectedLifeScoreImpact: SQMetricLifeScoreImpact = .none
        var initialSelectedInsightMode: SQMetricInsightMode = .exploratoryRelationships
        var initialSelectedSensitivity: SQMetricSensitivity = .normal
        var initialSelectedHealthKitType: SQMetricHealthKitType = .none
        var initialHealthKitReadEnabled = false
        var initialHealthKitWriteEnabled = false
        var initialSelectedPeriods: Set<SQMetricPeriod> = [.morning, .evening]
        var initialIsSingleDailyValue: Bool = false
        var initialScaleQuantityMapping: SQMetricScaleQuantityMapping? = nil

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

        self.scaleQuantityMaxField = SQUITextFieldViewModel(
            placeholder: "200",
            font: SQFont(type: .body).uiFont,
            keyboardType: .decimalPad,
            autocapitalizationType: .none,
            autocorrectionType: .no,
            selectAllOnFocus: true,
            textChangeFormatter: .decimal(maxDecimalPlaces: 1),
            validationRule: nil,
            errorHandler: { _ in nil }
        )

        self.quantityLabelOverrideField = SQUITextFieldViewModel(
            placeholder: "Optional visual label",
            font: SQFont(type: .body).uiFont,
            keyboardType: .default,
            autocapitalizationType: .sentences,
            autocorrectionType: .no,
            selectAllOnFocus: true,
            textChangeFormatter: .maxLength(24),
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
            emojiPreviewText = existing.emoji ?? ""
            initialSelectedKind = existing.kind
            initialSelectedUnit = existing.scaleQuantityMapping?.quantityUnit ?? existing.unit
            initialSelectedGroup = existing.group
            initialSelectedGoalStyle = existing.goalStyle
            initialSelectedBodyBatteryEffect = existing.bodyBatteryEffect
            initialSelectedSignalRole = existing.signalRole == .automatic || existing.signalRole == .unknown
                ? SQMetricSemanticResolver().signalRole(for: existing)
                : existing.signalRole
            initialSelectedLifeScoreImpact = existing.lifeScoreImpact == .automatic || existing.lifeScoreImpact == .unknown
                ? SQMetricSemanticResolver().lifeScoreImpact(for: existing)
                : existing.lifeScoreImpact
            initialSelectedInsightMode = existing.insightMode == .automatic || existing.insightMode == .unknown
                ? SQMetricSemanticResolver().insightMode(for: existing)
                : existing.insightMode
            initialSelectedSensitivity = SQMetricSemanticResolver().sensitivity(for: existing)
            initialSelectedHealthKitType = existing.healthKitType
            initialHealthKitReadEnabled = existing.healthKitReadEnabled
            initialHealthKitWriteEnabled = existing.healthKitWriteEnabled
            initialSelectedPeriods = existing.periods
            initialIsSingleDailyValue = existing.isSingleDailyValue
            initialScaleQuantityMapping = existing.scaleQuantityMapping
            minField.setText(existing.min.map { Self.formatFloat($0) } ?? "")
            maxField.setText(existing.max.map { Self.formatFloat($0) } ?? "")
            stepField.setText(existing.step.map { Self.formatFloat($0) } ?? "")
            scaleQuantityMaxField.setText(existing.scaleQuantityMapping.map { Self.formatFloat($0.maxQuantityValue) } ?? "")
            quantityLabelOverrideField.setText(existing.scaleQuantityMapping?.quantityLabelOverride ?? "")
            goalTargetField.setText(existing.targetValue.map { Self.formatFloat($0) } ?? "")
            goalRangeMinField.setText(existing.targetRangeMin.map { Self.formatFloat($0) } ?? "")
            goalRangeMaxField.setText(existing.targetRangeMax.map { Self.formatFloat($0) } ?? "")
        } else {
            // Default values for create
            minField.setText("0")
            maxField.setText("10")
            stepField.setText("1")
            initialSelectedUnit = .count
        }

        selectedKind = initialSelectedKind
        selectedUnit = initialSelectedUnit
        selectedGroup = initialSelectedGroup
        selectedGoalStyle = initialSelectedGoalStyle
        selectedBodyBatteryEffect = initialSelectedBodyBatteryEffect
        selectedSignalRole = initialSelectedSignalRole
        selectedLifeScoreImpact = initialSelectedLifeScoreImpact
        selectedInsightMode = initialSelectedInsightMode
        selectedSensitivity = initialSelectedSensitivity
        isInsightsEnabled = initialSelectedInsightMode != .off
        selectedHealthKitType = initialSelectedHealthKitType
        isHealthKitReadEnabled = initialHealthKitReadEnabled
        isHealthKitWriteEnabled = initialHealthKitWriteEnabled
        selectedPeriods = initialSelectedPeriods
        isSingleDailyValue = initialIsSingleDailyValue
        switch mode {
        case .create:
            isScaleQuantityMappingEnabled = initialSelectedKind == .scale
        case .edit:
            isScaleQuantityMappingEnabled = initialScaleQuantityMapping != nil
        }

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

        self.signalRoleMenuViewModel = SQDropDownMenuViewModel(
            defaultItem: .init(title: Self.displayName(for: initialSelectedSignalRole)),
            items: Self.signalRoleDisplayItems
        ) { _ in }

        self.lifeScoreImpactMenuViewModel = SQDropDownMenuViewModel(
            defaultItem: .init(title: Self.displayName(for: initialSelectedLifeScoreImpact)),
            items: Self.lifeScoreImpactDisplayItems(
                includeAutomatic: Self.allowsLifeScoreAutomaticOption(for: mode)
            )
        ) { _ in }

        self.sensitivityMenuViewModel = SQDropDownMenuViewModel(
            defaultItem: .init(title: Self.displayName(for: initialSelectedSensitivity)),
            items: Self.sensitivityDisplayItems
        ) { _ in }

        self.healthKitMenuViewModel = SQDropDownMenuViewModel(
            defaultItem: .init(title: Self.displayName(for: initialSelectedHealthKitType)),
            items: Self.healthKitDisplayItems
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
        hasFinishedInitialSetup = true
    }

    // MARK: - Computed

    var isStructurallyEditable: Bool {
        switch mode {
        case .create:
            return true
        case .edit(let existing):
            return !existing.isPreset
        }
    }

    var canCustomizeScaleQuantityMapping: Bool {
        switch mode {
        case .create:
            return true
        case .edit(let existing):
            return !existing.isPreset || existing.scaleQuantityMapping != nil
        }
    }

    var navigationTitle: String {
        if case .create = mode { return "New Metric" }
        return "Edit Metric"
    }

    var showsScaleRangeFields: Bool {
        selectedKind == .scale
    }

    var showsRecoveryScoreRangeFields: Bool {
        isStructurallyEditable && selectedKind == .number && selectedBodyBatteryEffect != .none
    }

    /// Whether unit picker should be visible
    var showUnit: Bool {
        selectedKind == .number
    }

    private var supportsScaleQuantitySection: Bool {
        canCustomizeScaleQuantityMapping && (selectedKind == .scale || selectedKind == .number)
    }

    var showsRequiredScaleConversionSection: Bool {
        guard supportsScaleQuantitySection, selectedKind == .number else { return false }
        guard case .edit(let existing) = mode else { return false }
        return existing.kind == .scale
    }

    var showsScaleQuantityMappingSection: Bool {
        switch selectedKind {
        case .scale:
            return supportsScaleQuantitySection
        case .number:
            return showsRequiredScaleConversionSection
        default:
            return false
        }
    }

    var showsScaleQuantityToggle: Bool {
        selectedKind == .scale && isStructurallyEditable && showsScaleQuantityMappingSection
    }

    var showsScaleQuantityFields: Bool {
        if selectedKind == .scale {
            return showsScaleQuantityMappingSection && isScaleQuantityMappingEnabled
        }

        return showsRequiredScaleConversionSection
    }

    var canEditScaleQuantityUnit: Bool {
        isStructurallyEditable
    }

    var canEditScaleQuantityLabelOverride: Bool {
        isStructurallyEditable
    }

    var scaleQuantitySectionTitle: String {
        switch selectedKind {
        case .number:
            return "Scale Conversion"
        case .scale:
            return "Map Scale to Unit"
        default:
            return "Alternate Input"
        }
    }

    var scaleQuantityMaxFieldLabel: String {
        if selectedKind == .number, let topScaleValue = resolvedScaleConversionUpperBound {
            return "Value at \(Self.formatFloat(topScaleValue)) on Scale"
        }
        return "Top Scale Value"
    }

    private func buildScaleQuantityHelperText() -> String {
        switch selectedKind {
        case .scale:
            if !isScaleQuantityMappingEnabled {
                return "Maps the scale value to a numeric value for more accurate data."
            }

            if let topScaleValue = resolvedScaleUpperBound,
               let maxQuantityValue = resolvedScaleQuantityMaxValue,
               selectedUnit != .none,
               selectedUnit != .unknown {
                let midpointScaleValue = topScaleValue / 2
                let midpointQuantityValue = maxQuantityValue / 2
                return "Add a numeric value that maps to the top scale value. For example, if \(Self.formatFloat(topScaleValue)) = \(Self.formatFloat(maxQuantityValue)) \(selectedUnit.shortDisplayName), then \(Self.formatFloat(midpointScaleValue)) = \(Self.formatFloat(midpointQuantityValue)) \(selectedUnit.shortDisplayName)."
            }

            return "Maps the scale value to a numeric value for more accurate data."

        case .number:
            if let topScaleValue = resolvedScaleConversionUpperBound,
               let maxQuantityValue = resolvedScaleQuantityMaxValue,
               selectedUnit != .none,
               selectedUnit != .unknown {
                let midpointScaleValue = topScaleValue / 2
                let midpointQuantityValue = maxQuantityValue / 2
                return "Enter the real amount that should match the top of the old scale. For example, if \(Self.formatFloat(topScaleValue)) = \(Self.formatFloat(maxQuantityValue)) \(selectedUnit.shortDisplayName), then \(Self.formatFloat(midpointScaleValue)) = \(Self.formatFloat(midpointQuantityValue)) \(selectedUnit.shortDisplayName)."
            }

            if let topScaleValue = resolvedScaleConversionUpperBound {
                return "Enter the real amount that should match the top of the old \(Self.formatFloat(topScaleValue))-point scale so older scale entries stay aligned."
            }

            return "Enter the real amount that should match the top of the old scale so older scale entries stay aligned."

        default:
            return "Optional alternate input configuration."
        }
    }

    var showGoalTargetField: Bool {
        selectedGoalStyle == .buildUp || selectedGoalStyle == .keepLow
    }

    var showGoalRangeFields: Bool {
        selectedGoalStyle == .stayInRange
    }

    var showsBodyBatteryControls: Bool {
        true
    }

    var showsAlgorithmSettings: Bool {
        true
    }

    var canEditMetricTypeSettings: Bool {
        !isPresetEditMode
    }

    var canEditGoalSettings: Bool {
        !isPresetEditMode
    }

    var canEditPrivacySafetySettings: Bool {
        !isPresetEditMode
    }

    var showsLifeScoreImpactControl: Bool {
        true
    }

    var showsInsightsControl: Bool {
        true
    }

    private var isPresetEditMode: Bool {
        switch mode {
        case .create:
            return false
        case .edit(let def):
            return def.isPreset
        }
    }

    var showsLifeIQUseSection: Bool {
        true
    }

    private var recommendedInsightMode: SQMetricInsightMode {
        if let existingDefinition, existingDefinition.isPreset {
            let presetDefault = SQMetricSemanticDefaults.insightMode(
                forMetricId: existingDefinition.id,
                isPreset: true
            )
            if presetDefault != .automatic,
               presetDefault != .unknown,
               presetDefault != .off {
                return presetDefault
            }
        }

        return selectedSensitivity == .medicationLike
            ? SQMetricInsightMode.trendsOnly
            : SQMetricInsightMode.exploratoryRelationships
    }

    var currentHealthKitType: SQMetricHealthKitType {
        if case .edit(let def) = mode {
            return def.healthKitType
        }
        return selectedHealthKitType
    }

    var canEditHealthKitType: Bool {
        false
    }

    private var supportsHealthKitSection: Bool {
        guard case .edit(let existing) = mode else { return false }
        return existing.isPreset && existing.hasHealthKitLink
    }

    var showsHealthKitSection: Bool {
        supportsHealthKitSection
    }

    var showsHealthKitReadToggle: Bool {
        currentHealthKitType != .none && currentHealthKitType != .unknown
    }

    var showsHealthKitWriteToggle: Bool {
        currentHealthKitType.supportsWrite
    }

    var healthKitHelperText: String {
        switch currentHealthKitType {
        case .bodyMass:
            return "Reads daily weight samples from Apple Health when LifeIQ does not have a value. If write is on, LifeIQ also syncs your saved weight back to Apple Health."
        case .dietaryWater:
            return "Reads daily water totals from Apple Health when you have not logged Hydration in LifeIQ. If write is on, LifeIQ also keeps its daily total in sync."
        case .dietaryCaffeine:
            return "Reads daily caffeine totals from Apple Health when LifeIQ does not have a value. If write is on, LifeIQ updates its Apple Health sample for that day."
        case .numberOfAlcoholicBeverages:
            return "Uses Apple Health standard drink totals as a fallback when LifeIQ is missing a value. Write keeps the LifeIQ total mirrored back to Apple Health."
        case .none:
            return "Optional. Link a supported Apple Health metric so missing LifeIQ days can fall back to Health data."
        case .unknown:
            return ""
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

    var recoveryScoreRangeHelperText: String {
        "Number metrics need a typical low and high only when they affect Recovery Score."
    }

    var metricTypeDisplayValue: String {
        Self.displayName(for: selectedSignalRole)
    }

    var goalDisplayValue: String {
        Self.displayName(for: selectedGoalStyle)
    }

    var privacySafetyDisplayValue: String {
        Self.displayName(for: selectedSensitivity)
    }

    var goalSuccessSummary: String? {
        _ = formContentRevision

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

    var shouldPreventInteractiveDismiss: Bool {
        if case .create = mode { return true }
        return false
    }

    func shouldHighlight(_ target: ValidationTarget) -> Bool {
        saveDisabledMessage != nil && validationTarget == target
    }

    private var metricWriteDisabledMessage: String? {
        guard SQAppState.shared.userState.isLoggedIn else {
            return "Sign in to create or edit metrics."
        }

        let remoteConfigSnapshot = SQRemoteConfigManager.shared.snapshot
        guard !remoteConfigSnapshot.writesDisabled else {
            return remoteConfigSnapshot.writesDisabledMessage
        }

        return nil
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

    var currentKind: SQMetricKind {
        if isStructurallyEditable {
            return selectedKind
        }
        if case .edit(let def) = mode { return def.kind }
        return selectedKind
    }

    var currentUnit: SQMetricUnit {
        if isStructurallyEditable {
            return selectedUnit
        }
        if case .edit(let def) = mode { return def.scaleQuantityMapping?.quantityUnit ?? def.unit }
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

    private var existingDefinition: SQMetricDefinition? {
        if case .edit(let def) = mode {
            return def
        }

        return nil
    }

    // MARK: - Actions

    @discardableResult
    func saveTapped(using context: ModelContext) async -> Bool {
        if let metricWriteDisabledMessage {
            calculateValidity()
            presentError(metricWriteDisabledMessage)
            return false
        }

        isLoading = true
        defer { isLoading = false }

        do {
            switch mode {
            case .create:
                let definition = buildDefinition()
                try metricsManager.createMetric(definition: definition, using: context)

            case .edit(let existing):
                let definition = buildDefinition(existingId: existing.id, isPreset: existing.isPreset, isEnabled: existing.isEnabled, sortOrder: existing.sortOrder, isArchived: existing.isArchived)
                try metricsManager.updateMetric(definition: definition, using: context)
            }

            return true
        } catch {
            SQLogger.shared.log(
                "Failed to save metric: \(error.localizedDescription)",
                .error,
                context: .dailyCheckIn
            )
            presentError("Error saving metric: \(error.localizedDescription)")
            return false
        }
    }

    // MARK: - Delete

    var canDelete: Bool {
        guard metricWriteDisabledMessage == nil else { return false }
        if case .edit(let existing) = mode {
            return !existing.isPreset
        }
        return false
    }

    @discardableResult
    func deleteTapped(using context: ModelContext) -> Bool {
        guard case .edit(let existing) = mode else { return false }
        do {
            try metricsManager.archiveMetric(id: existing.id, using: context)
            return true
        } catch {
            SQLogger.shared.log(
                "Failed to delete metric: \(error.localizedDescription)",
                .error,
                context: .dailyCheckIn
            )
            presentError("Error deleting metric: \(error.localizedDescription)")
            return false
        }
    }

    // MARK: - Private

    private func presentError(_ message: String) {
        SQAppState.shared.hub.alertEvents.send(
            .present(.init(SQError.standard(withDescription: message)))
        )
    }

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
                return self.isStructurallyEditable && (self.showsScaleRangeFields || self.showsRecoveryScoreRangeFields)
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
                return self.isStructurallyEditable && (self.showsScaleRangeFields || self.showsRecoveryScoreRangeFields)
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
                return self.isStructurallyEditable && self.showsScaleRangeFields
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
        scaleQuantityHelperTextDisplay = buildScaleQuantityHelperText()

        let activeRows = rowViewModels.filter { $0.isActive() }
        activeRows.forEach { $0.setValidity($0.validator(), notify: false) }

        var firstError: String? = activeRows.first(where: { !$0.isValid })?.errorMessage()
        var firstTarget = validationTarget(for: firstError)

        if firstError == nil {
            firstError = metricWriteDisabledMessage
            firstTarget = nil
        }

        if firstError == nil, isStructurallyEditable {
            if selectedPeriods.isEmpty {
                firstError = "Select at least one check-in period."
                firstTarget = .periods
            }
        }

        if firstError == nil, isStructurallyEditable {
            switch selectedKind {
            case .scale:
                let result = validateScaleFieldsDetailed()
                if !result.isValid {
                    firstError = result.message
                    firstTarget = validationTarget(for: result.message)
                }
            case .number:
                let result = validateNumberFieldsDetailed()
                if !result.isValid {
                    firstError = result.message
                    firstTarget = validationTarget(for: result.message)
                }
            default:
                firstError = "Metric type is invalid."
                firstTarget = .kind
            }
        }

        if firstError == nil {
            let result = validateScaleQuantityMappingDetailed()
            if !result.isValid {
                firstError = result.message
                firstTarget = validationTarget(for: result.message)
            }
        }

        if firstError == nil {
            let result = validateHealthKitFieldsDetailed()
            if !result.isValid {
                firstError = result.message
                firstTarget = validationTarget(for: result.message)
            }
        }

        if firstError == nil, canEditGoalSettings {
            let result = validateGoalFieldsDetailed()
            if !result.isValid {
                firstError = result.message
                firstTarget = validationTarget(for: result.message)
            }
        }

        if firstError == nil {
            let result = validateBodyBatteryFieldsDetailed()
            if !result.isValid {
                firstError = result.message
                firstTarget = validationTarget(for: result.message)
            }
        }

        if firstError == nil {
            let result = validateAlgorithmSettingsDetailed()
            if !result.isValid {
                firstError = result.message
                firstTarget = validationTarget(for: result.message)
            }
        }

        isFormValid = firstError == nil
        saveDisabledMessage = isFormValid ? nil : (firstError ?? "Please fix the errors above.")
        validationTarget = isFormValid ? nil : firstTarget
    }

    private func validationTarget(for message: String?) -> ValidationTarget? {
        guard let message else { return nil }

        if message == "Title is required." { return .title }
        if message == "Select at least one check-in period." { return .periods }
        if message.contains("Shared tracking") { return .tracking }
        if message.contains("Metric type") { return .kind }
        if message.contains("Choose a unit") || message.contains(" uses ") { return .unit }
        if message.contains("Min is required") || message.contains("Typical low") { return .min }
        if message.contains("Max is required") || message.contains("Max must") || message.contains("Typical high") { return .max }
        if message.contains("Step") { return .step }
        if message.contains("top of the scale") || message.contains("Max quantity") || message.contains("scale-to-unit mapping") { return .scaleQuantityMax }
        if message.contains("selected goal") || message.contains("Goal must") { return .goalTarget }
        if message.contains("minimum value") || message.contains("Goal min") { return .goalRangeMin }
        if message.contains("maximum value") || message.contains("Goal max") { return .goalRangeMax }
        if message.contains("Recovery Score") { return .bodyBattery }
        if message.contains("Metric Type") || message.contains("signal role") { return .signalRole }
        if message.contains("HealthKit") { return .healthKitType }

        return nil
    }

    private func configureAfterInit() {
        // Wire delegates for validation updates
        titleField.delegate = self
        emojiField.delegate = self
        minField.delegate = self
        maxField.delegate = self
        stepField.delegate = self
        goalTargetField.delegate = self
        goalRangeMinField.delegate = self
        goalRangeMaxField.delegate = self
        scaleQuantityMaxField.delegate = self
        quantityLabelOverrideField.delegate = self
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

        signalRoleMenuViewModel = SQDropDownMenuViewModel(
            defaultItem: .init(title: Self.displayName(for: selectedSignalRole)),
            items: Self.signalRoleDisplayItems
        ) { [weak self] title in
            self?.selectedSignalRole = Self.signalRole(fromDisplayName: title)
        }

        lifeScoreImpactMenuViewModel = SQDropDownMenuViewModel(
            defaultItem: .init(title: Self.displayName(for: selectedLifeScoreImpact)),
            items: Self.lifeScoreImpactDisplayItems(
                includeAutomatic: Self.allowsLifeScoreAutomaticOption(for: mode)
            )
        ) { [weak self] title in
            self?.selectedLifeScoreImpact = Self.lifeScoreImpact(fromDisplayName: title)
        }

        sensitivityMenuViewModel = SQDropDownMenuViewModel(
            defaultItem: .init(title: Self.displayName(for: selectedSensitivity)),
            items: Self.sensitivityDisplayItems
        ) { [weak self] title in
            self?.selectedSensitivity = Self.sensitivity(fromDisplayName: title)
        }

        healthKitMenuViewModel = SQDropDownMenuViewModel(
            defaultItem: .init(title: Self.displayName(for: selectedHealthKitType)),
            items: Self.healthKitDisplayItems
        ) { [weak self] title in
            self?.selectedHealthKitType = Self.healthKitType(fromDisplayName: title)
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
            } else if self.selectedHealthKitType.requiresSingleDailyValue {
                self.isSingleDailyValue = true
                self.updateTrackingMenuSelection()
            }
            self.calculateValidity()
        }

        setupRowViewModels()
        calculateValidity()
    }

    private static func computeAvailableGroups(metricsManager: SQMetricDefinitionManaging, selectedGroup: String) -> [String] {
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

    private func updateSignalRoleMenuSelection() {
        let title = Self.displayName(for: selectedSignalRole)
        if signalRoleMenuViewModel.mainButton.title != title {
            signalRoleMenuViewModel.defaultItem = .init(title: title)
        }
    }

    private func updateLifeScoreImpactMenuSelection() {
        let title = Self.displayName(for: selectedLifeScoreImpact)
        if lifeScoreImpactMenuViewModel.mainButton.title != title {
            lifeScoreImpactMenuViewModel.defaultItem = .init(title: title)
        }
    }

    private func updateSensitivityMenuSelection() {
        let title = Self.displayName(for: selectedSensitivity)
        if sensitivityMenuViewModel.mainButton.title != title {
            sensitivityMenuViewModel.defaultItem = .init(title: title)
        }
    }

    private func updateHealthKitMenuSelection() {
        let title = Self.displayName(for: selectedHealthKitType)
        if healthKitMenuViewModel.mainButton.title != title {
            healthKitMenuViewModel.defaultItem = .init(title: title)
        }
    }

    private func updateTrackingMenuSelection() {
        let title = Self.displayName(forTrackingShared: isSingleDailyValue)
        if trackingMenuViewModel.mainButton.title != title {
            trackingMenuViewModel.defaultItem = .init(title: title)
        }
    }

    private func buildDefinition(
        existingId: String? = nil,
        isPreset: Bool = false,
        isEnabled: Bool = true,
        sortOrder: Int = 0,
        isArchived: Bool = false
    ) -> SQMetricDefinition {
        let title = titleField.text.trimmingCharacters(in: .whitespacesAndNewlines)
        let emoji = emojiField.text.isEmpty ? nil : emojiField.text
        let mapping = resolvedScaleQuantityMapping
        let healthKitType = currentHealthKitType
        let healthKitReadEnabled = healthKitType == .none ? false : isHealthKitReadEnabled
        let healthKitWriteEnabled = healthKitType.supportsWrite ? isHealthKitWriteEnabled : false

        switch selectedKind {
        case .scale:
            return .init(
                id: existingId ?? SQMetricId.custom(),
                title: title,
                kind: .scale,
                unit: .none,
                group: selectedGroup,
                min: Float(minField.text),
                max: Float(maxField.text),
                step: Float(stepField.text),
                isPreset: isPreset,
                isEnabled: isEnabled,
                sortOrder: sortOrder,
                isArchived: isArchived,
                emoji: emoji,
                periods: selectedPeriods,
                isSingleDailyValue: isSingleDailyValue,
                goalStyle: selectedGoalStyle,
                targetValue: resolvedGoalTargetValue,
                targetRangeMin: resolvedGoalRangeMin,
                targetRangeMax: resolvedGoalRangeMax,
                bodyBatteryEffect: selectedBodyBatteryEffect,
                signalRole: resolvedSignalRole,
                lifeScoreImpact: resolvedLifeScoreImpact,
                insightMode: resolvedInsightMode,
                sensitivity: resolvedSensitivity,
                scaleQuantityMapping: mapping,
                healthKitType: healthKitType,
                healthKitReadEnabled: healthKitReadEnabled,
                healthKitWriteEnabled: healthKitWriteEnabled
            )

        case .number:
            return .init(
                id: existingId ?? SQMetricId.custom(),
                title: title,
                kind: .number,
                unit: selectedUnit,
                group: selectedGroup,
                min: minField.text.isEmpty ? nil : Float(minField.text),
                max: maxField.text.isEmpty ? nil : Float(maxField.text),
                step: resolvedNumberStepValue,
                isPreset: isPreset,
                isEnabled: isEnabled,
                sortOrder: sortOrder,
                isArchived: isArchived,
                emoji: emoji,
                periods: selectedPeriods,
                isSingleDailyValue: isSingleDailyValue,
                goalStyle: selectedGoalStyle,
                targetValue: resolvedGoalTargetValue,
                targetRangeMin: resolvedGoalRangeMin,
                targetRangeMax: resolvedGoalRangeMax,
                bodyBatteryEffect: selectedBodyBatteryEffect,
                signalRole: resolvedSignalRole,
                lifeScoreImpact: resolvedLifeScoreImpact,
                insightMode: resolvedInsightMode,
                sensitivity: resolvedSensitivity,
                scaleQuantityMapping: mapping,
                healthKitType: healthKitType,
                healthKitReadEnabled: healthKitReadEnabled,
                healthKitWriteEnabled: healthKitWriteEnabled
            )

        default:
            // .binary and .unknown should never be user-created; fall back to scale
            return .init(
                id: existingId ?? SQMetricId.custom(),
                title: title,
                kind: .scale,
                unit: .none,
                group: selectedGroup,
                min: 0, max: 10, step: 1,
                isPreset: isPreset,
                isEnabled: isEnabled,
                sortOrder: sortOrder,
                isArchived: isArchived,
                emoji: emoji,
                periods: selectedPeriods,
                isSingleDailyValue: isSingleDailyValue,
                goalStyle: selectedGoalStyle,
                targetValue: resolvedGoalTargetValue,
                targetRangeMin: resolvedGoalRangeMin,
                targetRangeMax: resolvedGoalRangeMax,
                bodyBatteryEffect: selectedBodyBatteryEffect,
                signalRole: resolvedSignalRole,
                lifeScoreImpact: resolvedLifeScoreImpact,
                insightMode: resolvedInsightMode,
                sensitivity: resolvedSensitivity,
                scaleQuantityMapping: mapping,
                healthKitType: healthKitType,
                healthKitReadEnabled: healthKitReadEnabled,
                healthKitWriteEnabled: healthKitWriteEnabled
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
        guard showsRecoveryScoreRangeFields else { return (true, nil) }

        if !minField.text.isEmpty, Float(minField.text) == nil {
            return (false, "Typical low must be a number.")
        }
        if !maxField.text.isEmpty, Float(maxField.text) == nil {
            return (false, "Typical high must be a number.")
        }
        if let min = Float(minField.text), let max = Float(maxField.text) {
            guard max > min else { return (false, "Typical high must be greater than typical low.") }
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

    private func validateScaleQuantityMappingDetailed() -> (isValid: Bool, message: String?) {
        guard showsScaleQuantityMappingSection else { return (true, nil) }

        if case .edit(let existing) = mode,
           selectedKind != existing.kind,
           !isScaleQuantityMappingEnabled {
            return (false, "Switching between scale and number requires a mapping so historical entries keep their original mode.")
        }

        let requiresMappingFields = selectedKind == .number
            ? showsRequiredScaleConversionSection
            : isScaleQuantityMappingEnabled

        guard requiresMappingFields else { return (true, nil) }

        guard selectedUnit != .none && selectedUnit != .unknown else {
            return (false, "Choose a unit for the scale conversion.")
        }

        guard let maxQuantityValue = resolvedScaleQuantityMaxValue else {
            return (false, "Enter the numeric value that should map to the top of the scale.")
        }

        guard maxQuantityValue > 0 else {
            return (false, "Max quantity must be greater than 0.")
        }

        return (true, nil)
    }

    private func validateHealthKitFieldsDetailed() -> (isValid: Bool, message: String?) {
        guard currentHealthKitType != .none && currentHealthKitType != .unknown else {
            return (true, nil)
        }

        if currentHealthKitType.requiresSingleDailyValue, selectedPeriods.count > 1, !isSingleDailyValue {
            return (false, "HealthKit-linked daily totals must use Shared tracking.")
        }

        let recommendedUnit = currentHealthKitType.recommendedUnit
        if recommendedUnit != .none, selectedUnit != recommendedUnit {
            return (false, "\(currentHealthKitType.displayName) uses \(recommendedUnit.displayName).")
        }

        if selectedKind == .scale && resolvedScaleQuantityMapping == nil {
            return (false, "HealthKit-linked scale metrics need a scale-to-unit mapping.")
        }

        return (true, nil)
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

        guard selectedKind == .number else { return (true, nil) }

        guard let min = metricLowerBound, let max = metricUpperBound else {
            return (false, "Add a typical low and high for number metrics that affect Recovery Score.")
        }

        guard max > min else {
            return (false, "Typical high must be greater than typical low.")
        }

        return (true, nil)
    }

    private func validateAlgorithmSettingsDetailed() -> (isValid: Bool, message: String?) {
        guard showsAlgorithmSettings else { return (true, nil) }

        if canEditMetricTypeSettings {
            guard selectedSignalRole != .automatic && selectedSignalRole != .unknown else {
                return (false, "Choose what kind of metric this is.")
            }
        }

        if canEditPrivacySafetySettings {
            guard selectedSensitivity != .unknown else {
                return (false, "Choose a privacy and safety setting.")
            }
        }

        guard selectedLifeScoreImpact != .unknown else {
            return (false, "Choose whether this affects Life Score.")
        }

        if !isPresetEditMode, selectedLifeScoreImpact == .automatic {
            return (false, "Choose whether this affects Life Score.")
        }

        guard selectedLifeScoreImpact != .none else { return (true, nil) }
        guard canEditGoalSettings else { return (true, nil) }

        switch selectedGoalStyle {
        case .justTrack:
            return (false, "Change Goal from Just Track It before allowing Life Score impact.")
        case .buildUp, .keepLow:
            guard parsedGoalTargetValue != nil || hasUsableMetricValueRange else {
                return (false, "Add a goal target or usable value range before allowing Life Score impact.")
            }
        case .stayInRange:
            guard parsedGoalRangeMin != nil, parsedGoalRangeMax != nil else {
                return (false, "Add a target range before allowing Life Score impact.")
            }
        case .avoidIt:
            break
        case .unknown:
            return (false, "Choose a valid goal before allowing Life Score impact.")
        }

        return (true, nil)
    }

    private func validateMinField() -> Bool {
        switch selectedKind {
        case .scale:
            return !minField.text.isEmpty && Float(minField.text) != nil
        case .number:
            guard showsRecoveryScoreRangeFields else { return true }
            return !minField.text.isEmpty && Float(minField.text) != nil
        default:
            return true
        }
    }

    private func minFieldErrorMessage() -> String? {
        switch selectedKind {
        case .scale:
            return "Min is required for scale."
        case .number:
            return showsRecoveryScoreRangeFields
                ? "Enter a typical low value."
                : nil
        default:
            return nil
        }
    }

    private func validateMaxField() -> Bool {
        switch selectedKind {
        case .scale:
            return !maxField.text.isEmpty && Float(maxField.text) != nil
        case .number:
            guard showsRecoveryScoreRangeFields else { return true }
            return !maxField.text.isEmpty && Float(maxField.text) != nil
        default:
            return true
        }
    }

    private func maxFieldErrorMessage() -> String? {
        switch selectedKind {
        case .scale:
            return "Max is required for scale."
        case .number:
            return showsRecoveryScoreRangeFields
                ? "Enter a typical high value."
                : nil
        default:
            return nil
        }
    }

    private func validateStepField() -> Bool {
        switch selectedKind {
        case .scale:
            return !stepField.text.isEmpty && Float(stepField.text) != nil
        default:
            return true
        }
    }

    private func stepFieldErrorMessage() -> String? {
        switch selectedKind {
        case .scale:
            return "Step is required for scale."
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
    private func kindChanged(from previousKind: SQMetricKind) {
        guard isStructurallyEditable else { return }
        switch selectedKind {
        case .scale:
            minField.setText("0")
            maxField.setText("10")
            stepField.setText("1")
            if selectedUnit == .none || selectedUnit == .unknown {
                selectedUnit = .count
            }
            if previousKind != .scale {
                isScaleQuantityMappingEnabled = true
            }
        case .number:
            minField.setText("")
            maxField.setText("")
            stepField.setText("")
            if selectedUnit == .none || selectedUnit == .unknown {
                selectedUnit = .count
            }
            if case .edit(let existing) = mode, existing.kind != .number {
                isScaleQuantityMappingEnabled = true
            }
        default:
            break
        }
        applyHealthKitTypeDefaultsIfNeeded(from: selectedHealthKitType)
        calculateValidity()
    }

    private func applyHealthKitTypeDefaultsIfNeeded(from previousType: SQMetricHealthKitType) {
        guard selectedHealthKitType != .unknown else { return }

        if selectedHealthKitType == .none {
            isHealthKitReadEnabled = false
            isHealthKitWriteEnabled = false
            return
        }

        if previousType == .none || previousType == .unknown {
            isHealthKitReadEnabled = true
            isHealthKitWriteEnabled = selectedHealthKitType.supportsWrite
        }

        let recommendedUnit = selectedHealthKitType.recommendedUnit
        if recommendedUnit != .none {
            selectedUnit = recommendedUnit
        }

        if selectedHealthKitType.requiresSingleDailyValue {
            isSingleDailyValue = true
        }

        if selectedKind == .scale {
            isScaleQuantityMappingEnabled = true
        }

        if !selectedHealthKitType.supportsWrite {
            isHealthKitWriteEnabled = false
        }
    }

    private func applySensitivityDefaultsIfNeeded(from previousSensitivity: SQMetricSensitivity) {
        guard canEditPrivacySafetySettings else { return }

        if selectedSensitivity == .medicationLike {
            selectedLifeScoreImpact = .none
            if isInsightsEnabled {
                selectedInsightMode = .trendsOnly
            }
            return
        }

        if selectedSensitivity == .sensitive,
           previousSensitivity == .normal,
           selectedLifeScoreImpact != .none {
            selectedLifeScoreImpact = .none
        }

        if isInsightsEnabled, selectedInsightMode == .trendsOnly, selectedSensitivity != .medicationLike {
            selectedInsightMode = .exploratoryRelationships
        }
    }

    private func applyLifeScoreImpactDefaultsIfNeeded(from previousImpact: SQMetricLifeScoreImpact) {
        guard hasFinishedInitialSetup, canEditGoalSettings else { return }
        guard selectedLifeScoreImpact == .light || selectedLifeScoreImpact == .standard else { return }
        guard previousImpact == .none || previousImpact == .automatic || previousImpact == .unknown else { return }
        guard selectedGoalStyle == .justTrack else { return }

        selectedGoalStyle = recommendedGoalStyleForLifeScoreImpact
    }

    private var recommendedGoalStyleForLifeScoreImpact: SQMetricGoalStyle {
        switch selectedSignalRole {
        case .symptom:
            return .keepLow
        case .behavior, .outcome, .bodyStat, .context, .automatic, .unknown:
            return .buildUp
        }
    }

    private var metricLowerBound: Float? {
        if isStructurallyEditable {
            return Float(minField.text)
        }
        if case .edit(let def) = mode { return def.min }
        return Float(minField.text)
    }

    private var metricUpperBound: Float? {
        if isStructurallyEditable {
            return Float(maxField.text)
        }
        if case .edit(let def) = mode { return def.max }
        return Float(maxField.text)
    }

    private var hasUsableMetricValueRange: Bool {
        guard let min = metricLowerBound, let max = metricUpperBound else { return false }
        return max > min
    }

    private var resolvedNumberStepValue: Float? {
        0.1
    }

    private var parsedGoalTargetValue: Float? {
        goalTargetField.text.isEmpty ? nil : Float(goalTargetField.text)
    }

    private var resolvedScaleQuantityMaxValue: Float? {
        scaleQuantityMaxField.text.isEmpty ? nil : Float(scaleQuantityMaxField.text)
    }

    private var resolvedScaleUpperBound: Float? {
        Float(maxField.text)
    }

    private var resolvedScaleConversionUpperBound: Float? {
        if selectedKind == .number,
           case .edit(let existing) = mode,
           existing.kind == .scale {
            return existing.max
        }
        return resolvedScaleUpperBound
    }

    private var shouldPersistScaleQuantityMapping: Bool {
        switch selectedKind {
        case .scale:
            return isScaleQuantityMappingEnabled
        case .number:
            return showsRequiredScaleConversionSection
        default:
            return false
        }
    }

    private var resolvedScaleQuantityMapping: SQMetricScaleQuantityMapping? {
        guard shouldPersistScaleQuantityMapping, let maxValue = resolvedScaleQuantityMaxValue else { return nil }

        let trimmedLabelOverride = quantityLabelOverrideField.text
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return .init(
            quantityUnit: selectedUnit,
            maxQuantityValue: maxValue,
            quantityLabelOverride: trimmedLabelOverride.isEmpty ? nil : trimmedLabelOverride
        )
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

    private var resolvedSignalRole: SQMetricSignalRole {
        if canEditMetricTypeSettings {
            return selectedSignalRole
        }

        return existingDefinition?.signalRole ?? selectedSignalRole
    }

    private var resolvedLifeScoreImpact: SQMetricLifeScoreImpact {
        showsLifeScoreImpactControl ? selectedLifeScoreImpact : (existingDefinition?.lifeScoreImpact ?? .automatic)
    }

    private var resolvedInsightMode: SQMetricInsightMode {
        guard showsInsightsControl else { return existingDefinition?.insightMode ?? .automatic }
        if isPresetEditMode,
           !hasUserChangedInsightsEnabled,
           let existingMode = existingDefinition?.insightMode,
           existingMode == .automatic || existingMode == .unknown {
            return .automatic
        }

        return isInsightsEnabled ? selectedInsightMode : .off
    }

    private var resolvedSensitivity: SQMetricSensitivity {
        if canEditPrivacySafetySettings {
            return selectedSensitivity
        }

        return existingDefinition?.sensitivity ?? selectedSensitivity
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
            .init(title: displayName(for: .justTrack), subtitle: menuDescription(for: .justTrack)),
            .init(title: displayName(for: .buildUp), subtitle: menuDescription(for: .buildUp)),
            .init(title: displayName(for: .keepLow), subtitle: menuDescription(for: .keepLow)),
            .init(title: displayName(for: .avoidIt), subtitle: menuDescription(for: .avoidIt)),
            .init(title: displayName(for: .stayInRange), subtitle: menuDescription(for: .stayInRange)),
        ]
    }

    private static var bodyBatteryDisplayItems: [SQDropDownMenuViewModel.Item] {
        [
            .init(title: displayName(for: SQMetricBodyBatteryEffect.none), subtitle: menuDescription(for: SQMetricBodyBatteryEffect.none)),
            .init(title: displayName(for: SQMetricBodyBatteryEffect.boostsWhenHigh), subtitle: menuDescription(for: SQMetricBodyBatteryEffect.boostsWhenHigh)),
            .init(title: displayName(for: SQMetricBodyBatteryEffect.drainsWhenHigh), subtitle: menuDescription(for: SQMetricBodyBatteryEffect.drainsWhenHigh)),
        ]
    }

    private static var signalRoleDisplayItems: [SQDropDownMenuViewModel.Item] {
        [
            .init(title: displayName(for: SQMetricSignalRole.behavior), subtitle: menuDescription(for: .behavior)),
            .init(title: displayName(for: SQMetricSignalRole.outcome), subtitle: menuDescription(for: .outcome)),
            .init(title: displayName(for: SQMetricSignalRole.symptom), subtitle: menuDescription(for: .symptom)),
            .init(title: displayName(for: SQMetricSignalRole.bodyStat), subtitle: menuDescription(for: .bodyStat)),
            .init(title: displayName(for: SQMetricSignalRole.context), subtitle: menuDescription(for: .context)),
        ]
    }

    private static func lifeScoreImpactDisplayItems(includeAutomatic: Bool) -> [SQDropDownMenuViewModel.Item] {
        var items: [SQDropDownMenuViewModel.Item] = [
            .init(title: displayName(for: SQMetricLifeScoreImpact.none), subtitle: menuDescription(for: SQMetricLifeScoreImpact.none)),
            .init(title: displayName(for: SQMetricLifeScoreImpact.light), subtitle: menuDescription(for: SQMetricLifeScoreImpact.light)),
            .init(title: displayName(for: SQMetricLifeScoreImpact.standard), subtitle: menuDescription(for: SQMetricLifeScoreImpact.standard)),
        ]

        if includeAutomatic {
            items.insert(
                .init(
                    title: displayName(for: SQMetricLifeScoreImpact.automatic),
                    subtitle: menuDescription(for: SQMetricLifeScoreImpact.automatic)
                ),
                at: 0
            )
        }

        return items
    }

    private static var sensitivityDisplayItems: [SQDropDownMenuViewModel.Item] {
        [
            .init(title: displayName(for: SQMetricSensitivity.normal), subtitle: menuDescription(for: .normal)),
            .init(title: displayName(for: SQMetricSensitivity.sensitive), subtitle: menuDescription(for: .sensitive)),
            .init(title: displayName(for: SQMetricSensitivity.medicationLike), subtitle: menuDescription(for: .medicationLike)),
        ]
    }

    private static var healthKitDisplayItems: [SQDropDownMenuViewModel.Item] {
        [
            .init(title: displayName(for: SQMetricHealthKitType.none)),
            .init(title: displayName(for: SQMetricHealthKitType.bodyMass)),
            .init(title: displayName(for: SQMetricHealthKitType.dietaryWater)),
            .init(title: displayName(for: SQMetricHealthKitType.dietaryCaffeine)),
            .init(title: displayName(for: SQMetricHealthKitType.numberOfAlcoholicBeverages)),
        ]
    }

    private static var trackingDisplayItems: [SQDropDownMenuViewModel.Item] {
        [
            .init(title: "Independent", subtitle: "Separate morning and evening values."),
            .init(title: "Shared", subtitle: "One daily value used by both check-ins.")
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
        unit.displayName
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

    private static func displayName(for role: SQMetricSignalRole) -> String {
        switch role {
        case .behavior:
            return "Something I Do"
        case .outcome:
            return "Something I Feel / Want To Improve"
        case .symptom:
            return "Symptom"
        case .bodyStat:
            return "Body / Stat Measurement"
        case .context:
            return "Context"
        case .automatic:
            return "LifeIQ Automatic"
        case .unknown:
            return "Unknown"
        }
    }

    private static func displayName(for impact: SQMetricLifeScoreImpact) -> String {
        switch impact {
        case .none:
            return "No"
        case .light:
            return "A Little"
        case .standard:
            return "Normally"
        case .automatic:
            return "LifeIQ Default"
        case .unknown:
            return "Unknown"
        }
    }

    private static func displayName(for sensitivity: SQMetricSensitivity) -> String {
        switch sensitivity {
        case .normal:
            return "Standard"
        case .sensitive:
            return "Private / Sensitive"
        case .medicationLike:
            return "Medication / Supplement"
        case .unknown:
            return "Unknown"
        }
    }

    private static func menuDescription(for goalStyle: SQMetricGoalStyle) -> String {
        switch goalStyle {
        case .justTrack:
            return "Track trends only."
        case .buildUp:
            return "Higher values are better."
        case .keepLow:
            return "Lower values are better."
        case .avoidIt:
            return "Zero is the goal."
        case .stayInRange:
            return "A target range is best."
        case .unknown:
            return ""
        }
    }

    private static func menuDescription(for effect: SQMetricBodyBatteryEffect) -> String {
        switch effect {
        case .none:
            return "Recovery Score ignores it."
        case .boostsWhenHigh:
            return "Higher values support recovery."
        case .drainsWhenHigh:
            return "Higher values lower recovery."
        case .unknown:
            return ""
        }
    }

    private static func menuDescription(for role: SQMetricSignalRole) -> String {
        switch role {
        case .behavior:
            return "Examples: caffeine, workouts, meditation."
        case .outcome:
            return "Examples: mood, energy, performance."
        case .symptom:
            return "Examples: pain, headache, flare-up."
        case .bodyStat:
            return "Examples: weight, HRV, blood pressure."
        case .context:
            return "Examples: travel, workday, cycle day."
        case .automatic, .unknown:
            return ""
        }
    }

    private static func menuDescription(for impact: SQMetricLifeScoreImpact) -> String {
        switch impact {
        case .none:
            return "No score effect."
        case .light:
            return "Small daily nudge."
        case .standard:
            return "Normal score effect."
        case .automatic:
            return "Use the built-in preset default."
        case .unknown:
            return ""
        }
    }

    private static func menuDescription(for sensitivity: SQMetricSensitivity) -> String {
        switch sensitivity {
        case .normal:
            return "Normal scoring and insights."
        case .sensitive:
            return "Private topic; score impact stays cautious."
        case .medicationLike:
            return "Track trends only; no usage advice."
        case .unknown:
            return ""
        }
    }

    private static func displayName(for healthKitType: SQMetricHealthKitType) -> String {
        healthKitType.displayName
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

    private static func signalRole(fromDisplayName title: String) -> SQMetricSignalRole {
        [
            SQMetricSignalRole.behavior,
            .outcome,
            .symptom,
            .bodyStat,
            .context,
        ].first(where: { displayName(for: $0) == title }) ?? .outcome
    }

    private static func lifeScoreImpact(fromDisplayName title: String) -> SQMetricLifeScoreImpact {
        [
            SQMetricLifeScoreImpact.automatic,
            .none,
            .light,
            .standard,
        ].first(where: { displayName(for: $0) == title }) ?? .none
    }

    private static func allowsLifeScoreAutomaticOption(for mode: Mode) -> Bool {
        if case .edit(let existing) = mode {
            return existing.isPreset
        }

        return false
    }

    private static func sensitivity(fromDisplayName title: String) -> SQMetricSensitivity {
        [
            SQMetricSensitivity.normal,
            .sensitive,
            .medicationLike,
        ].first(where: { displayName(for: $0) == title }) ?? .normal
    }

    private static func healthKitType(fromDisplayName title: String) -> SQMetricHealthKitType {
        [
            SQMetricHealthKitType.none,
            .bodyMass,
            .dietaryWater,
            .dietaryCaffeine,
            .numberOfAlcoholicBeverages,
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
        formContentRevision += 1

        if viewModel === titleField {
            titleRowViewModel?.updateValidity()
        } else if viewModel === emojiField {
            emojiPreviewText = emojiField.text
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

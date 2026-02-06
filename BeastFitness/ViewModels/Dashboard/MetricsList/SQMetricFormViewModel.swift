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

    // MARK: - Fields

    let titleField: SQUITextFieldViewModel
    let emojiField: SQUITextFieldViewModel

    var selectedKind: SQMetricKind = .scale {
        didSet { kindChanged() }
    }
    var selectedUnit: SQMetricUnit = .none
    var selectedGroup: String = SQDefaultGroup.general.rawValue
    var isAddingNewGroup: Bool = false

    let newGroupField: SQUITextFieldViewModel
    let minField: SQUITextFieldViewModel
    let maxField: SQUITextFieldViewModel
    let stepField: SQUITextFieldViewModel

    // MARK: - State

    var isLoading = false

    // MARK: - Dependencies

    private let metricsManager: SQMetricsManaging

    // MARK: - Init

    init(mode: Mode, metricsManager: SQMetricsManaging) {
        self.mode = mode
        self.metricsManager = metricsManager

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
            placeholder: "👆",
            font: UIFont.systemFont(ofSize: 28),
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
            font: UIFont.systemFont(ofSize: 16),
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
            font: UIFont.systemFont(ofSize: 16),
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
            font: UIFont.systemFont(ofSize: 16),
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
            font: UIFont.systemFont(ofSize: 16),
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
            selectedKind = existing.kind
            selectedUnit = existing.unit
            selectedGroup = existing.group
            minField.setText(existing.min.map { Self.formatFloat($0) } ?? "")
            maxField.setText(existing.max.map { Self.formatFloat($0) } ?? "")
            stepField.setText(existing.step.map { Self.formatFloat($0) } ?? "")
        } else {
            // Default values for create
            minField.setText("0")
            maxField.setText("10")
            stepField.setText("1")
        }
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

    /// All unique groups currently in use, plus defaults and the current selection, sorted alphabetically.
    var availableGroups: [String] {
        let existing = metricsManager.allMetrics(includeArchived: false).map(\.group)
        var unique = Array(Set(existing))
        for g in SQDefaultGroup.allCases.map(\.rawValue) + [selectedGroup] where !unique.contains(g) {
            unique.append(g)
        }
        return unique.sorted()
    }

    var canSave: Bool {
        let titleValid = !titleField.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty

        guard titleValid else { return false }

        if case .create = mode {
            switch selectedKind {
            case .binary:
                return true   // no numeric fields needed
            case .scale:
                return validateScaleFields()
            case .number:
                return validateNumberFields()
            }
        }

        return true   // edit mode: title is the only required editable field
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
                try metricsManager.updateMetric(id: existing.id, title: titleField.text, emoji: emoji, group: selectedGroup, using: context)
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

    private func buildDefinition() -> SQMetricDefinition {
        let emoji = emojiField.text.isEmpty ? nil : emojiField.text

        switch selectedKind {
        case .binary:
            return .init(
                id: SQMetricId.custom(),
                title: titleField.text,
                kind: .binary,
                unit: .none,
                group: selectedGroup,
                min: 0, max: 1, step: 1,
                isPreset: false,
                isEnabled: true,
                sortOrder: 0,   // manager sets actual order
                isArchived: false,
                emoji: emoji
            )

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
                emoji: emoji
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
                emoji: emoji
            )
        }
    }

    private func validateScaleFields() -> Bool {
        guard let min = Float(minField.text),
              let max = Float(maxField.text),
              let step = Float(stepField.text) else { return false }
        return max > min && step > 0 && step <= (max - min)
    }

    private func validateNumberFields() -> Bool {
        // For number type, min/max/step are all optional
        // But if both min and max are provided, max must be > min
        if let min = Float(minField.text), let max = Float(maxField.text) {
            return max > min
        }
        // If step is provided, it must be positive
        if let step = Float(stepField.text) {
            return step > 0
        }
        return true
    }

    // MARK: - Group Management

    func confirmNewGroup() {
        let trimmed = newGroupField.text.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            selectedGroup = trimmed
        }
        isAddingNewGroup = false
    }

    func cancelNewGroup() {
        isAddingNewGroup = false
    }

    /// Reset numeric defaults when kind changes in create mode
    private func kindChanged() {
        guard isStructurallyEditable else { return }
        switch selectedKind {
        case .binary:
            break   // fields will be hidden
        case .scale:
            minField.setText("0")
            maxField.setText("10")
            stepField.setText("1")
        case .number:
            minField.setText("")
            maxField.setText("")
            stepField.setText("")
        }
    }

    private static func formatFloat(_ value: Float) -> String {
        if value.rounded() == value { return "\(Int(value))" }
        return String(format: "%.1f", Double(value))
    }
}

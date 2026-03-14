//
//  SQMetricFormView.swift
//  BeastFitness
//

import SwiftUI
import SwiftData

struct SQMetricFormView: View {
    @State var viewModel: SQMetricFormViewModel
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var isConfirmingDelete = false

    // MARK: - Emoji Circle

    @ViewBuilder
    var emojiCircle: some View {
        ZStack {
            Circle()
                .sqForegroundColor(.backgroundSecondaryLight)
                .frame(width: 72, height: 72)

            if !viewModel.emojiField.text.isEmpty {
                Text(viewModel.emojiField.text)
                    .font(.system(size: 32))
            } else {
                Image(systemName: "smiley")
                    .font(.system(size: 28, weight: .semibold))
                    .sqForegroundColor(.textSecondary)
            }
        }
        .onTapGesture {
            viewModel.emojiField.focus()
        }
    }

    // MARK: - Emoji Input

    /// Compact single-character input row — visually distinct from other fields
    @ViewBuilder
    var emojiInputRow: some View {
        labeledRow(label: "Emoji") {
            HStack(spacing: .SQSpace.m) {
                SQUITextField(viewModel: viewModel.emojiField)
                    .frame(width: 48)

                Text("Tap field, then use emoji keyboard")
                    .sqFont(.bodyExtraSmall)
                    .sqForegroundColor(.textTertiary)
            }
        }
    }

    // MARK: - Title

    @ViewBuilder
    var titleRow: some View {
        labeledRow(label: "Title") {
            SQUITextField(viewModel: viewModel.titleField)
        }
    }

    // MARK: - Group Picker

    @ViewBuilder
    var groupRow: some View {
        labeledRow(label: "Group") {
            if viewModel.isAddingNewGroup {
                HStack(spacing: .SQSpace.s) {
                    SQUITextField(viewModel: viewModel.newGroupField)

                    Button(action: { viewModel.confirmNewGroup() }) {
                        Image(systemName: "checkmark.circle.fill")
                            .sqForegroundColor(.accent(1))
                    }
                    .buttonStyle(.plain)

                    Button(action: { viewModel.cancelNewGroup() }) {
                        Image(systemName: "xmark.circle.fill")
                            .sqForegroundColor(.textTertiary)
                    }
                    .buttonStyle(.plain)
                }
            } else {
                HStack(spacing: .SQSpace.s) {
                    Picker("Group", selection: $viewModel.selectedGroup) {
                        ForEach(viewModel.availableGroups, id: \.self) { group in
                            Text(group).tag(group)
                        }
                    }
                    .pickerStyle(.menu)

                    Button(action: { viewModel.isAddingNewGroup = true }) {
                        Image(systemName: "plus.circle")
                            .sqForegroundColor(.textSecondary)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Period Picker (create only) / Static (edit)

    @ViewBuilder
    var periodRow: some View {
        if viewModel.isStructurallyEditable {
            labeledRow(label: "Check-In") {
                Picker("Check-In", selection: $viewModel.selectedPeriod) {
                    Text("Morning").tag(SQMetricPeriod.morning)
                    Text("Evening").tag(SQMetricPeriod.evening)
                }
                .pickerStyle(.segmented)
            }
        } else {
            staticRow(
                label: "Check-In",
                value: viewModel.selectedPeriod == .morning ? "Morning" : "Evening"
            )
        }
    }

    // MARK: - Kind Picker (create only) / Static (edit)

    @ViewBuilder
    var kindRow: some View {
        if viewModel.isStructurallyEditable {
            labeledRow(label: "Type") {
                Picker("Type", selection: $viewModel.selectedKind) {
                    ForEach(viewModel.selectableKinds, id: \.self) { kind in
                        Text(kind.rawValue.capitalized).tag(kind)
                    }
                }
                .pickerStyle(.segmented)
            }
        } else {
            staticRow(label: "Type", value: viewModel.currentKind.rawValue.capitalized)
        }
    }

    // MARK: - Unit Picker (create + number only) / Static (edit)

    @ViewBuilder
    var unitRow: some View {
        if viewModel.showUnit {
            if viewModel.isStructurallyEditable {
                labeledRow(label: "Unit") {
                    Picker("Unit", selection: $viewModel.selectedUnit) {
                        ForEach(SQMetricUnit.allCases, id: \.self) { unit in
                            Text(unit == .none ? "None" : unit.rawValue.capitalized).tag(unit)
                        }
                    }
                    .pickerStyle(.segmented)
                }
            } else {
                staticRow(label: "Unit", value: viewModel.currentUnit == .none ? "None" : viewModel.currentUnit.rawValue.capitalized)
            }
        }
    }

    // MARK: - Numeric Range Fields

    @ViewBuilder
    var numericRows: some View {
        if viewModel.showNumericRange {
            if viewModel.isStructurallyEditable {
                labeledRow(label: "Min") {
                    SQUITextField(viewModel: viewModel.minField)
                }
                labeledRow(label: "Max") {
                    SQUITextField(viewModel: viewModel.maxField)
                }
                if viewModel.selectedKind == .scale {
                    labeledRow(label: "Step") {
                        SQUITextField(viewModel: viewModel.stepField)
                    }
                } else {
                    labeledRow(label: "Step") {
                        HStack(spacing: .SQSpace.m) {
                            SQUITextField(viewModel: viewModel.stepField)
                                .frame(maxWidth: 80)
                            Text("(decimal precision)")
                                .sqFont(.bodyExtraSmall)
                                .sqForegroundColor(.textTertiary)
                        }
                    }
                }
            } else {
                staticRow(label: "Min", value: viewModel.currentMin)
                staticRow(label: "Max", value: viewModel.currentMax)
                staticRow(label: "Step", value: viewModel.currentStep)
            }
        }
    }

    // MARK: - Save Button

    @ViewBuilder
    var saveButton: some View {
        SQButton(
            shouldHugContent: false,
            title: "Save",
            isDisabled: !viewModel.canSave,
            isLoading: viewModel.isLoading,
            action: {
                Task {
                    await viewModel.saveTapped(using: modelContext)
                    if !viewModel.isLoading {
                        dismiss()
                    }
                }
            }
        )
        .padding(.horizontal, .SQSpace.xl)
        .padding(.bottom, .SQSpace.l)
    }

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: .SQSpace.xl) {
                // Emoji circle at top (centered)
                emojiCircle
                    .frame(maxWidth: .infinity)

                Divider()
                    .sqTintColor(.divider(1))

                titleRow
                emojiInputRow
                groupRow
                periodRow

                Divider()
                    .sqTintColor(.divider(1))

                kindRow
                unitRow
                numericRows
            }
            .padding(.horizontal, .SQSpace.l)
            .padding(.top, .SQSpace.l)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .navigationTitle(viewModel.navigationTitle)
        .navigationBarTitleDisplayMode(.inline)
        .background(SQColor.backgroundSecondary.color)
        .safeAreaInset(edge: .bottom) {
            saveButton
        }
        .toolbar {
            if viewModel.canDelete {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { isConfirmingDelete = true }) {
                        Image(systemName: "trash")
                    }
                }
            }
        }
        .confirmationDialog("Delete Metric", isPresented: $isConfirmingDelete, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                viewModel.deleteTapped(using: modelContext)
                dismiss()
            }
        } message: {
            Text("This will remove the metric from your daily check-in. Past check-in data is preserved.")
        }
    }

    // MARK: - Helpers

    @ViewBuilder
    private func labeledRow(label: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: .SQSpace.s) {
            Text(label)
                .sqFont(.bodySmall)
                .sqForegroundColor(.textSecondary)
            content()
        }
    }

    @ViewBuilder
    private func staticRow(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: .SQSpace.s) {
            Text(label)
                .sqFont(.bodySmall)
                .sqForegroundColor(.textSecondary)
            Text(value)
                .sqFont(.body)
                .sqForegroundColor(.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(10)
                .sqBackgroundColor(.backgroundSecondaryLight)
                .cornerRadius(.SQCornerRadius.m)
        }
    }
}

// MARK: - View Model Accessors for Read-Only Display

private extension SQMetricFormViewModel {
    var currentKind: SQMetricKind {
        if case .edit(let def) = mode { return def.kind }
        return selectedKind
    }

    var currentUnit: SQMetricUnit {
        if case .edit(let def) = mode { return def.unit }
        return selectedUnit
    }

    var currentMin: String {
        if case .edit(let def) = mode { return def.min.map { Self.fmt($0) } ?? "—" }
        return minField.text
    }

    var currentMax: String {
        if case .edit(let def) = mode { return def.max.map { Self.fmt($0) } ?? "—" }
        return maxField.text
    }

    var currentStep: String {
        if case .edit(let def) = mode { return def.step.map { Self.fmt($0) } ?? "—" }
        return stepField.text
    }

    private static func fmt(_ v: Float) -> String {
        if v.rounded() == v { return "\(Int(v))" }
        return String(format: "%.1f", Double(v))
    }
}

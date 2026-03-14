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
            SQUITextField(viewModel: viewModel.emojiField)
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
                    SQDropDownMenu(menuViewModel: viewModel.groupMenuViewModel, isDisabled: false)

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
            labeledRow(label: "Check-In Period") {
                SQMultiSelect(viewModel: viewModel.periodMultiSelectViewModel)
            }
            if viewModel.selectedPeriods.count > 1 {
                labeledRow(label: "Check-In Period Tracking") {
                    SQDropDownMenu(menuViewModel: viewModel.trackingMenuViewModel, isDisabled: false)
                }
            }
        } else {
            staticRow(label: "Check-In Period", value: viewModel.periodDisplayValue)
        }
    }

    // MARK: - Kind Picker (create only) / Static (edit)

    @ViewBuilder
    var kindRow: some View {
        if viewModel.isStructurallyEditable {
            labeledRow(label: "Type") {
                SQDropDownMenu(menuViewModel: viewModel.kindMenuViewModel, isDisabled: false)
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
                    SQDropDownMenu(menuViewModel: viewModel.unitMenuViewModel, isDisabled: false)
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
        VStack(alignment: .leading, spacing: .SQSpace.s) {
            if !viewModel.canSave, let message = viewModel.saveDisabledMessage {
                Text(message)
                    .sqFont(.bodyExtraSmall)
                    .sqForegroundColor(.colorErrorRed)
                    .padding(.horizontal, .SQSpace.xl)
            }

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
        .background(SQColor.backgroundSheet.color)
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
                .opacity(0.5)
                .cornerRadius(.SQCornerRadius.m)
        }
    }
}

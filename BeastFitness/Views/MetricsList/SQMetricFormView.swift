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

    @ViewBuilder
    private var emojiTile: some View {
        Button {
            viewModel.emojiField.focus()
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: .SQCornerRadius.xl, style: .continuous)
                    .fill(SQColor.glassCardTint.color.opacity(SQColor.isDarkMode ? 0.82 : 0.96))
                    .overlay(
                        RoundedRectangle(cornerRadius: .SQCornerRadius.xl, style: .continuous)
                            .stroke(SQColor.glassStroke.color, lineWidth: 1)
                    )
                    .frame(width: 86, height: 86)

                if !viewModel.emojiField.text.isEmpty {
                    Text(viewModel.emojiField.text)
                        .font(.system(size: 32))
                } else {
                    SQImageView(
                        image: .init(
                            symbol: .faceSmiling,
                            symbolStyle: .colorWithFont(.textSecondary, font: .title3)
                        )
                    )
                    .frame(width: 24, height: 24)
                }
            }
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var heroCard: some View {
        VStack(spacing: .SQSpace.m) {
            emojiTile

            Text("Tap to set an icon for this metric.")
                .sqFont(.bodyExtraSmall)
                .sqForegroundColor(.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, .SQSpace.xl)
        .sqGlassSurface(level: .card, cornerRadius: .SQCornerRadius.xl)
    }

    @ViewBuilder
    private func iconActionButton(symbol: SQImageSymbol, foregroundColor: SQColor, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            RoundedRectangle(cornerRadius: .SQCornerRadius.l, style: .continuous)
                .fill(SQColor.glassCardTint.color.opacity(SQColor.isDarkMode ? 0.82 : 0.96))
                .frame(width: 34, height: 34)
                .overlay(
                    RoundedRectangle(cornerRadius: .SQCornerRadius.l, style: .continuous)
                        .stroke(SQColor.glassStroke.color, lineWidth: 1)
                )
                .overlay(
                    SQImageView(
                        image: .init(
                            symbol: symbol,
                            symbolStyle: .colorWithFont(foregroundColor, font: .bodySmall)
                        )
                    )
                    .frame(width: 12, height: 12)
                )
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func toolbarIconButton(symbol: SQImageSymbol, foregroundColor: SQColor, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            SQImageView(
                image: .init(
                    symbol: symbol,
                    symbolStyle: .colorWithFont(foregroundColor, font: .bodySmall)
                )
            )
            .frame(width: 14, height: 14)
        }
        .buttonStyle(.plain)
    }

    private func presentDeleteMetricAlert() {
        let alert = SQAlertViewModel(
            title: "Delete Metric?",
            subtitle: "This will remove the metric from your daily check-in. Past check-in data is preserved.",
            primary: .init(title: "Delete", role: .destructive) { _ in
                viewModel.deleteTapped(using: modelContext)
                dismiss()
            },
            secondary: .init(title: "Cancel", role: .cancel),
            canDismiss: true
        )

        SQAppState.shared.hub.alertEvents.send(.present(alert))
    }

    @ViewBuilder
    private var emojiInputRow: some View {
        labeledRow(label: "Icon") {
            SQUITextField(viewModel: viewModel.emojiField)
        }
    }

    @ViewBuilder
    private var titleRow: some View {
        labeledRow(label: "Title") {
            SQUITextField(viewModel: viewModel.titleField)
        }
    }

    @ViewBuilder
    private var groupRow: some View {
        labeledRow(label: "Group") {
            if viewModel.isAddingNewGroup {
                HStack(spacing: .SQSpace.s) {
                    SQUITextField(viewModel: viewModel.newGroupField)

                    iconActionButton(symbol: .checkmarkCircleFill, foregroundColor: .dashboardGlowBlueForeground) {
                        viewModel.confirmNewGroup()
                    }

                    iconActionButton(symbol: .xmarkCircleFill, foregroundColor: .textSecondary) {
                        viewModel.cancelNewGroup()
                    }
                }
            } else {
                HStack(spacing: .SQSpace.s) {
                    SQDropDownMenu(menuViewModel: viewModel.groupMenuViewModel, isDisabled: false)

                    iconActionButton(symbol: .plusCircle, foregroundColor: .textPrimary) {
                        viewModel.isAddingNewGroup = true
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var periodRow: some View {
        if viewModel.isStructurallyEditable {
            labeledRow(label: "Check-In Period") {
                SQMultiSelect(viewModel: viewModel.periodMultiSelectViewModel)
            }

            if viewModel.selectedPeriods.count > 1 {
                VStack(alignment: .leading, spacing: .SQSpace.xs) {
                    labeledRow(label: "Tracking") {
                        SQDropDownMenu(menuViewModel: viewModel.trackingMenuViewModel, isDisabled: false)
                    }

                    Text(viewModel.trackingHelperText)
                        .sqFont(.bodyExtraSmall)
                        .sqForegroundColor(.textSecondary)
                }
            }
        } else {
            staticRow(label: "Check-In Period", value: viewModel.periodDisplayValue)
        }
    }

    @ViewBuilder
    private var kindRow: some View {
        if viewModel.isStructurallyEditable {
            labeledRow(label: "Type") {
                SQDropDownMenu(menuViewModel: viewModel.kindMenuViewModel, isDisabled: false)
            }
        } else {
            staticRow(label: "Type", value: viewModel.currentKind.rawValue.capitalized)
        }
    }

    @ViewBuilder
    private var unitRow: some View {
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

    @ViewBuilder
    private var numericRows: some View {
        if viewModel.showNumericRange {
            if viewModel.isStructurallyEditable {
                labeledRow(label: "Min") {
                    SQUITextField(viewModel: viewModel.minField)
                }

                labeledRow(label: "Max") {
                    SQUITextField(viewModel: viewModel.maxField)
                }

                labeledRow(label: "Step") {
                    VStack(alignment: .leading, spacing: .SQSpace.xs) {
                        SQUITextField(viewModel: viewModel.stepField)

                        if viewModel.selectedKind == .number {
                            Text("Used as decimal precision.")
                                .sqFont(.bodyExtraSmall)
                                .sqForegroundColor(.textSecondary)
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

    @ViewBuilder
    private var goalRows: some View {
        labeledRow(label: "Goal") {
            SQDropDownMenu(menuViewModel: viewModel.goalMenuViewModel, isDisabled: false)
        }

        Text(viewModel.goalHelperText)
            .sqFont(.bodyExtraSmall)
            .sqForegroundColor(.textSecondary)

        if viewModel.showGoalTargetField {
            labeledRow(label: viewModel.goalTargetLabel) {
                SQUITextField(viewModel: viewModel.goalTargetField)
            }
        }

        if viewModel.showGoalRangeFields {
            labeledRow(label: "Target Min") {
                SQUITextField(viewModel: viewModel.goalRangeMinField)
            }

            labeledRow(label: "Target Max") {
                SQUITextField(viewModel: viewModel.goalRangeMaxField)
            }
        }

        if let summary = viewModel.goalSuccessSummary {
            Text(summary)
                .sqFont(.bodyExtraSmall)
                .sqForegroundColor(.dashboardGlowBlue)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, .SQSpace.xs)
        }
    }

    @ViewBuilder
    private var bodyBatteryRows: some View {
        labeledRow(label: "Effect") {
            SQDropDownMenu(menuViewModel: viewModel.bodyBatteryMenuViewModel, isDisabled: false)
        }

        Text(viewModel.bodyBatteryHelperText)
            .sqFont(.bodyExtraSmall)
            .sqForegroundColor(.textSecondary)

        if let summary = viewModel.bodyBatterySummary {
            Text(summary)
                .sqFont(.bodyExtraSmall)
                .sqForegroundColor(.dashboardGlowBlue)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, .SQSpace.xs)
        }
    }

    @ViewBuilder
    private func formSection(
        title: String,
        subtitle: String? = nil,
        @ViewBuilder content: () -> some View
    ) -> some View {
        VStack(alignment: .leading, spacing: .SQSpace.m) {
            VStack(alignment: .leading, spacing: .SQSpace.xs) {
                Text(title)
                    .sqFont(.title4)
                    .sqForegroundColor(.textPrimary)

                if let subtitle {
                    Text(subtitle)
                        .sqFont(.bodyExtraSmall)
                        .sqForegroundColor(.textSecondary)
                }
            }

            VStack(alignment: .leading, spacing: .SQSpace.m) {
                content()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.SQSpace.l)
        .sqGlassSurface(level: .card, cornerRadius: .SQCornerRadius.xl)
    }

    @ViewBuilder
    private var saveButton: some View {
        VStack(alignment: .leading, spacing: .SQSpace.s) {
            if !viewModel.canSave, let message = viewModel.saveDisabledMessage {
                Text(message)
                    .sqFont(.bodyExtraSmall)
                    .sqForegroundColor(.textError)
                    .padding(.horizontal, .SQSpace.xl)
            }

            SQButton(
                style: .glassPrimary,
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

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: .SQSpace.l) {
                heroCard

                formSection(title: "Basics", subtitle: "Name, icon, and grouping.") {
                    titleRow
                    emojiInputRow
                    groupRow
                }

                formSection(title: "Check-In", subtitle: "Where this metric shows up.") {
                    periodRow
                    goalRows
                }

                formSection(title: "Format", subtitle: "Value type, units, and range.") {
                    kindRow
                    unitRow
                    numericRows
                }

                if viewModel.showsBodyBatteryControls {
                    formSection(title: "Recovery Score", subtitle: "Optional: let this metric nudge the daily score.") {
                        bodyBatteryRows
                    }
                }
            }
            .padding(.horizontal, .SQSpace.l)
            .padding(.top, .SQSpace.l)
            .padding(.bottom, .SQSpace.xxl)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .navigationTitle(viewModel.navigationTitle)
        .navigationBarTitleDisplayMode(.inline)
        .background {
            SQSheetBackground()
        }
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 0) {
                Divider()
                    .sqTintColor(.glassStroke)

                saveButton
            }
            .background(.ultraThinMaterial)
        }
        .toolbar {
            if viewModel.canDelete {
                ToolbarItem(placement: .topBarTrailing) {
                    toolbarIconButton(symbol: .trash, foregroundColor: .textPrimary) {
                        presentDeleteMetricAlert()
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func labeledRow(label: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: .SQSpace.s) {
            Text(label.uppercased())
                .sqFont(.headerSmall)
                .sqForegroundColor(.textSecondary)

            content()
        }
    }

    @ViewBuilder
    private func staticRow(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: .SQSpace.s) {
            Text(label.uppercased())
                .sqFont(.headerSmall)
                .sqForegroundColor(.textSecondary)

            Text(value)
                .sqFont(.body)
                .sqForegroundColor(.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, .SQSpace.m)
                .padding(.vertical, .SQSpace.m)
                .background(
                    RoundedRectangle(cornerRadius: .SQCornerRadius.l, style: .continuous)
                        .fill(SQColor.glassCardTint.color.opacity(SQColor.isDarkMode ? 0.76 : 0.96))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: .SQCornerRadius.l, style: .continuous)
                        .stroke(SQColor.glassStroke.color, lineWidth: 1)
                )
        }
    }
}

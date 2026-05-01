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

                if !viewModel.emojiPreviewText.isEmpty {
                    Text(viewModel.emojiPreviewText)
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
                let didDelete = viewModel.deleteTapped(using: modelContext)
                if didDelete {
                    dismiss()
                }
            },
            secondary: .init(title: "Cancel", role: .cancel),
            canDismiss: true
        )

        SQAppState.shared.hub.alertEvents.send(.present(alert))
    }

    private func presentRecoveryScoreInfoAlert() {
        let alert = SQAlertViewModel(
            title: "Recovery Score Range",
            subtitle: "Typical low and typical high values help LifeIQ understand what a lower day or higher day means for this metric. They are especially important when this metric is allowed to influence Recovery Score.",
            primary: .init(title: "Got It"),
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

                    iconActionButton(symbol: .checkmark, foregroundColor: .dashboardGlowBlueForeground) {
                        viewModel.confirmNewGroup()
                    }

                    iconActionButton(symbol: .xMark, foregroundColor: .textSecondary) {
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
                staticRow(label: "Unit", value: viewModel.currentUnit.displayName)
            }
        }
    }

    @ViewBuilder
    private var numericRows: some View {
        if viewModel.showsScaleRangeFields {
            if viewModel.isStructurallyEditable {
                labeledRow(label: "Min") {
                    SQUITextField(viewModel: viewModel.minField)
                }

                labeledRow(label: "Max") {
                    SQUITextField(viewModel: viewModel.maxField)
                }

                labeledRow(label: "Step") {
                    SQUITextField(viewModel: viewModel.stepField)
                }
            } else {
                staticRow(label: "Min", value: viewModel.currentMin)
                staticRow(label: "Max", value: viewModel.currentMax)
                staticRow(label: "Step", value: viewModel.currentStep)
            }
        }
    }

    @ViewBuilder
    private var alternateInputRows: some View {
        if viewModel.showsScaleQuantityMappingSection {
            VStack(alignment: .leading, spacing: .SQSpace.s) {
                if viewModel.showsScaleQuantityToggle {
                    Toggle(isOn: $viewModel.isScaleQuantityMappingEnabled) {
                        Text(viewModel.scaleQuantitySectionTitle)
                            .sqFont(.body)
                            .sqForegroundColor(.textPrimary)
                    }
                    .tint(SQColor.dashboardGlowBlue.color)
                } else {
                    Text(viewModel.scaleQuantitySectionTitle)
                        .sqFont(.body)
                        .sqForegroundColor(.textPrimary)
                }

                Text(viewModel.scaleQuantityHelperTextDisplay)
                    .sqFont(.bodyExtraSmall)
                    .sqForegroundColor(.textSecondary)
            }

            if viewModel.showsScaleQuantityFields {
                if viewModel.selectedKind == .scale || viewModel.selectedKind == .number {
                    labeledRow(label: viewModel.selectedKind == .scale ? "Mapped Unit" : "Conversion Unit") {
                        if viewModel.canEditScaleQuantityUnit {
                            SQDropDownMenu(menuViewModel: viewModel.unitMenuViewModel, isDisabled: false)
                        } else {
                            Text(viewModel.currentUnit.displayName)
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

                labeledRow(label: viewModel.scaleQuantityMaxFieldLabel) {
                    SQUITextField(viewModel: viewModel.scaleQuantityMaxField)
                }

                if viewModel.canEditScaleQuantityLabelOverride {
                    labeledRow(label: "Visual Label") {
                        VStack(alignment: .leading, spacing: .SQSpace.xs) {
                            SQUITextField(viewModel: viewModel.quantityLabelOverrideField)

                            Text("Optional. Example: use canonical unit Count but show “drink count” in the UI.")
                                .sqFont(.bodyExtraSmall)
                                .sqForegroundColor(.textSecondary)
                        }
                    }
                }
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

        if viewModel.showsRecoveryScoreRangeFields {
            Button(action: presentRecoveryScoreInfoAlert) {
                HStack(spacing: .SQSpace.xs) {
                    SQImageView(
                        image: .init(
                            symbol: .infoCircle,
                            symbolStyle: .colorWithFont(.dashboardGlowBlue, font: .bodyExtraSmall)
                        )
                    )
                    .frame(width: 14, height: 14)

                    Text("Why typical low and high matter")
                        .sqFont(.bodyExtraSmall)
                        .sqForegroundColor(.dashboardGlowBlue)
                }
            }
            .buttonStyle(.plain)

            labeledRow(label: "Typical Low") {
                SQUITextField(viewModel: viewModel.minField)
            }

            labeledRow(label: "Typical High") {
                SQUITextField(viewModel: viewModel.maxField)
            }
        }
    }

    @ViewBuilder
    private var algorithmRows: some View {
        labeledRow(label: "What kind of thing is this?") {
            SQDropDownMenu(menuViewModel: viewModel.signalRoleMenuViewModel, isDisabled: false)
        }

        Toggle(isOn: $viewModel.isInsightsEnabled) {
            Text("Use for insights")
                .sqFont(.body)
                .sqForegroundColor(.textPrimary)
        }
        .tint(SQColor.dashboardGlowBlue.color)

        labeledRow(label: "Affect Life Score?") {
            SQDropDownMenu(menuViewModel: viewModel.lifeScoreImpactMenuViewModel, isDisabled: false)
        }

        labeledRow(label: "Sensitivity") {
            SQDropDownMenu(menuViewModel: viewModel.sensitivityMenuViewModel, isDisabled: false)
        }

        Text(viewModel.algorithmSettingsHelperText)
            .sqFont(.bodyExtraSmall)
            .sqForegroundColor(.textSecondary)
    }

    @ViewBuilder
    private var healthKitRows: some View {
        if viewModel.canEditHealthKitType {
            labeledRow(label: "Linked Type") {
                SQDropDownMenu(menuViewModel: viewModel.healthKitMenuViewModel, isDisabled: false)
            }
        } else {
            staticRow(label: "Linked Type", value: viewModel.currentHealthKitType.displayName)
        }

        Text(viewModel.healthKitHelperText)
            .sqFont(.bodyExtraSmall)
            .sqForegroundColor(.textSecondary)

        if viewModel.showsHealthKitReadToggle {
            Toggle(isOn: $viewModel.isHealthKitReadEnabled) {
                Text("Read From Apple Health")
                    .sqFont(.body)
                    .sqForegroundColor(.textPrimary)
            }
            .tint(SQColor.dashboardGlowBlue.color)
        }

        if viewModel.showsHealthKitWriteToggle {
            Toggle(isOn: $viewModel.isHealthKitWriteEnabled) {
                Text("Write To Apple Health")
                    .sqFont(.body)
                    .sqForegroundColor(.textPrimary)
            }
            .tint(SQColor.dashboardGlowBlue.color)
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
                        let didSave = await viewModel.saveTapped(using: modelContext)
                        if didSave {
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

                formSection(title: "Format", subtitle: "Value type, units, and scale setup.") {
                    kindRow
                    unitRow
                    numericRows
                    alternateInputRows
                }

                if viewModel.showsHealthKitSection {
                    formSection(title: "Health App", subtitle: "Optional Apple Health fallback and sync.") {
                        healthKitRows
                    }
                }

                if viewModel.showsBodyBatteryControls {
                    formSection(title: "Recovery Score", subtitle: "Optional: let this metric nudge the daily score.") {
                        bodyBatteryRows
                    }
                }

                if viewModel.showsAlgorithmSettings {
                    formSection(title: "How should LifeIQ use this?", subtitle: "Insight behavior and optional Life Score impact.") {
                        algorithmRows
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
        .dismissKeyboardOnBackgroundTap()
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

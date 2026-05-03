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

    private func presentLifeScoreInfoAlert() {
        let alert = SQAlertViewModel(
            title: "Life Score",
            subtitle: "Life Score is a daily snapshot of your recent momentum. It looks at signals like sleep, recovery, workouts, habits, and check-ins to estimate whether your life is trending in a healthy direction. It is not a medical score - it is a guide to help you notice what's supporting you and what may need attention.",
            primary: .ok,
            canDismiss: true
        )

        SQAppState.shared.hub.alertEvents.send(.present(alert))
    }

    private func presentRecoveryScoreInfoAlert() {
        let alert = SQAlertViewModel(
            title: "Recovery Score",
            subtitle: "Recovery Score focuses on readiness and physical recovery. Metrics can nudge it when they clearly represent recovery support or strain. Use No Effect to leave this metric out.",
            primary: .ok,
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
        labeledRow(label: "Title", validationTarget: .title) {
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
            labeledRow(label: "Check-In Period", validationTarget: .periods) {
                SQMultiSelect(viewModel: viewModel.periodMultiSelectViewModel)
            }

            if viewModel.selectedPeriods.count > 1 {
                labeledRow(label: "Tracking", validationTarget: .tracking) {
                    SQDropDownMenu(menuViewModel: viewModel.trackingMenuViewModel, isDisabled: false)
                }
            }
        } else {
            staticRow(label: "Check-In Period", value: viewModel.periodDisplayValue)
        }
    }

    @ViewBuilder
    private var kindRow: some View {
        if viewModel.isStructurallyEditable {
            labeledRow(label: "Type", validationTarget: .kind) {
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
                labeledRow(label: "Unit", validationTarget: .unit) {
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
                labeledRow(label: "Min", validationTarget: .min) {
                    SQUITextField(viewModel: viewModel.minField)
                }

                labeledRow(label: "Max", validationTarget: .max) {
                    SQUITextField(viewModel: viewModel.maxField)
                }

                labeledRow(label: "Step", validationTarget: .step) {
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
                    labeledRow(label: viewModel.selectedKind == .scale ? "Mapped Unit" : "Conversion Unit", validationTarget: .unit) {
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

                labeledRow(label: viewModel.scaleQuantityMaxFieldLabel, validationTarget: .scaleQuantityMax) {
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
        if viewModel.canEditGoalSettings {
            labeledRow(label: "Goal", validationTarget: .goalTarget) {
                SQDropDownMenu(menuViewModel: viewModel.goalMenuViewModel, isDisabled: false)
            }

            if viewModel.showGoalTargetField {
                labeledRow(label: viewModel.goalTargetLabel, validationTarget: .goalTarget) {
                    SQUITextField(viewModel: viewModel.goalTargetField)
                }
            }

            if viewModel.showGoalRangeFields {
                labeledRow(label: "Target Min", validationTarget: .goalRangeMin) {
                    SQUITextField(viewModel: viewModel.goalRangeMinField)
                }

                labeledRow(label: "Target Max", validationTarget: .goalRangeMax) {
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
        } else {
            staticRow(label: "Goal", value: viewModel.goalDisplayValue)
        }
    }

    @ViewBuilder
    private var lifeIQUseRows: some View {
        if viewModel.canEditMetricTypeSettings {
            labeledRow(label: "Metric Type", validationTarget: .signalRole) {
                SQDropDownMenu(menuViewModel: viewModel.signalRoleMenuViewModel, isDisabled: false)
            }
        } else {
            staticRow(label: "Metric Type", value: viewModel.metricTypeDisplayValue)
        }

        goalRows

        if viewModel.showsLifeScoreImpactControl {
            labeledRow(label: "Affect Life Score", infoAction: presentLifeScoreInfoAlert) {
                SQDropDownMenu(menuViewModel: viewModel.lifeScoreImpactMenuViewModel, isDisabled: false)
            }
        }

        if viewModel.showsBodyBatteryControls {
            labeledRow(label: "Affect Recovery Score", validationTarget: .bodyBattery, infoAction: presentRecoveryScoreInfoAlert) {
                SQDropDownMenu(menuViewModel: viewModel.bodyBatteryMenuViewModel, isDisabled: false)
            }

            if viewModel.showsRecoveryScoreRangeFields {
                Text(viewModel.recoveryScoreRangeHelperText)
                    .sqFont(.bodyExtraSmall)
                    .sqForegroundColor(.textSecondary)

                labeledRow(label: "Typical Low", validationTarget: .min) {
                    SQUITextField(viewModel: viewModel.minField)
                }

                labeledRow(label: "Typical High", validationTarget: .max) {
                    SQUITextField(viewModel: viewModel.maxField)
                }
            }
        }

        if viewModel.showsInsightsControl {
            Toggle(isOn: $viewModel.isInsightsEnabled) {
                Text("Affect Insights")
                    .sqFont(.body)
                    .sqForegroundColor(.textPrimary)
            }
            .tint(SQColor.dashboardGlowBlue.color)
        }

        if viewModel.canEditPrivacySafetySettings {
            labeledRow(label: "Privacy & Safety") {
                SQDropDownMenu(menuViewModel: viewModel.sensitivityMenuViewModel, isDisabled: false)
            }
        } else {
            staticRow(label: "Privacy & Safety", value: viewModel.privacySafetyDisplayValue)
        }
    }

    @ViewBuilder
    private var healthKitRows: some View {
        if viewModel.canEditHealthKitType {
            labeledRow(label: "Linked Type", validationTarget: .healthKitType) {
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

                formSection(title: "Basics") {
                    titleRow
                    emojiInputRow
                    groupRow
                }

                formSection(title: "Check-In") {
                    periodRow
                }

                formSection(title: "Format") {
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

                if viewModel.showsLifeIQUseSection {
                    formSection(title: "LifeIQ Use") {
                        lifeIQUseRows
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
        .interactiveDismissDisabled(viewModel.shouldPreventInteractiveDismiss)
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
    private func labeledRow(
        label: String,
        validationTarget: SQMetricFormViewModel.ValidationTarget? = nil,
        infoAction: (() -> Void)? = nil,
        @ViewBuilder content: () -> some View
    ) -> some View {
        VStack(alignment: .leading, spacing: .SQSpace.s) {
            HStack(spacing: .SQSpace.xs) {
                Text(label.uppercased())
                    .sqFont(.headerSmall)
                    .sqForegroundColor(isHighlighted(validationTarget) ? .textError : .textSecondary)

                if isHighlighted(validationTarget) {
                    Circle()
                        .fill(SQColor.textError.color)
                        .frame(width: 6, height: 6)
                        .accessibilityHidden(true)
                }

                if let infoAction {
                    Button(action: infoAction) {
                        SQImageView(
                            image: .init(
                                symbol: .infoCircle,
                                symbolStyle: .colorWithFont(.textSecondary, font: .bodyExtraSmall)
                            )
                        )
                        .frame(width: 13, height: 13)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(label) info")
                }
            }

            content()
        }
    }

    private func isHighlighted(_ target: SQMetricFormViewModel.ValidationTarget?) -> Bool {
        guard let target else { return false }
        return viewModel.shouldHighlight(target)
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

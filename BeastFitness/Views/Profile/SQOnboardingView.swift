//
//  SQOnboardingView.swift
//  BeastFitness
//

import SwiftUI

struct SQOnboardingView: View {
    @State var controller: SQOnboardingController

    private var unitSystemBinding: Binding<SQUnitSystem> {
        Binding(
            get: { controller.selectedUnitSystem },
            set: { controller.updateUnitSystem($0) }
        )
    }

    private var dateOfBirthBinding: Binding<Date> {
        Binding(
            get: { controller.selectedDateOfBirth },
            set: { controller.selectedDateOfBirth = $0 }
        )
    }

    private var includesDateOfBirthBinding: Binding<Bool> {
        Binding(
            get: { controller.includesDateOfBirth },
            set: { controller.includesDateOfBirth = $0 }
        )
    }

    private var sleepTimeBinding: Binding<Date> {
        Binding(
            get: { controller.selectedSleepTime },
            set: { controller.selectedSleepTime = $0 }
        )
    }

    private var wakeTimeBinding: Binding<Date> {
        Binding(
            get: { controller.selectedWakeTime },
            set: { controller.selectedWakeTime = $0 }
        )
    }

    @ViewBuilder
    private var heroCard: some View {
        VStack(spacing: .SQSpace.m) {
            ZStack {
                Circle()
                    .fill(SQColor.glassCardTint.color.opacity(SQColor.isDarkMode ? 0.86 : 0.96))
                    .overlay(
                        Circle()
                            .stroke(SQColor.glassStroke.color, lineWidth: 1)
                    )
                    .frame(width: 82, height: 82)

                SQImageView(
                    image: .init(
                        symbol: .personCircleFill,
                        symbolStyle: .colorWithFont(.textPrimary, font: .title2)
                    )
                )
                .frame(width: 34, height: 34)
            }

            VStack(spacing: .SQSpace.xs) {
                Text(controller.heroTitle)
                    .sqFont(.title2)
                    .sqForegroundColor(.textPrimary)

                Text(controller.heroSubtitle)
                    .sqFont(.bodyExtraSmall)
                    .sqForegroundColor(.textSecondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, .SQSpace.xl)
        .sqGlassSurface(level: .card, cornerRadius: .SQCornerRadius.xl)
    }

    @ViewBuilder
    private var unitsCard: some View {
        VStack(alignment: .leading, spacing: .SQSpace.m) {
            Text("Units")
                .sqFont(.title4)
                .sqForegroundColor(.textPrimary)

            Text("Choose how measurements should appear throughout LifeIQ.")
                .sqFont(.bodyExtraSmall)
                .sqForegroundColor(.textSecondary)

            HStack(spacing: .SQSpace.s) {
                ForEach(controller.unitSystemOptions, id: \.rawValue) { option in
                    Button {
                        unitSystemBinding.wrappedValue = option
                    } label: {
                        VStack(spacing: .SQSpace.xs) {
                            Text(option.title)
                                .sqFont(.bodySmallSemiBold)
                                .sqForegroundColor(controller.selectedUnitSystem == option ? .textPrimary : .textSecondary)

                            Text(option == .imperial ? "ft, lb, °F" : "cm, kg, °C")
                                .sqFont(.bodyExtraSmall)
                                .sqForegroundColor(.textTertiary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, .SQSpace.m)
                        .background(
                            RoundedRectangle(cornerRadius: .SQCornerRadius.l, style: .continuous)
                                .fill(
                                    controller.selectedUnitSystem == option
                                    ? SQColor.dashboardGlowBlue.color.opacity(SQColor.isDarkMode ? 0.22 : 0.14)
                                    : SQColor.glassCardTint.color.opacity(SQColor.isDarkMode ? 0.72 : 0.92)
                                )
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: .SQCornerRadius.l, style: .continuous)
                                .stroke(
                                    controller.selectedUnitSystem == option
                                    ? SQColor.dashboardGlowBlue.color.opacity(0.55)
                                    : SQColor.glassStroke.color,
                                    lineWidth: 1
                                )
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.SQSpace.l)
        .sqGlassSurface(level: .card, cornerRadius: .SQCornerRadius.xl)
    }

    @ViewBuilder
    private var profileCard: some View {
        VStack(alignment: .leading, spacing: .SQSpace.m) {
            Text("Profile")
                .sqFont(.title4)
                .sqForegroundColor(.textPrimary)

            VStack(alignment: .leading, spacing: .SQSpace.m) {
                if controller.shouldShowNameFields {
                    labeledRow(label: "First Name (optional)") {
                        SQUITextField(viewModel: controller.firstNameField)
                    }

                    labeledRow(label: "Last Name (optional)") {
                        SQUITextField(viewModel: controller.lastNameField)
                    }
                }

                labeledRow(label: "Height") {
                    if controller.showsHeightSecondaryField {
                        HStack(spacing: .SQSpace.m) {
                            compactHeightField(label: controller.heightPrimaryLabel, viewModel: controller.heightFeetField)
                            compactHeightField(label: controller.heightSecondaryLabel ?? "", viewModel: controller.heightInchesField)
                        }
                    } else {
                        HStack(spacing: .SQSpace.s) {
                            SQUITextField(viewModel: controller.heightFeetField)

                            Text(controller.heightPrimaryLabel.lowercased())
                                .sqFont(.bodySmall)
                                .sqForegroundColor(.textSecondary)
                        }
                    }
                }

                labeledRow(label: controller.weightLabel) {
                    SQUITextField(viewModel: controller.weightField)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.SQSpace.l)
        .sqGlassSurface(level: .card, cornerRadius: .SQCornerRadius.xl)
    }

    @ViewBuilder
    private var optionalInfoCard: some View {
        VStack(alignment: .leading, spacing: .SQSpace.m) {
            Text("Optional")
                .sqFont(.title4)
                .sqForegroundColor(.textPrimary)

            Toggle(isOn: includesDateOfBirthBinding) {
                VStack(alignment: .leading, spacing: .SQSpace.xs) {
                    Text("Add date of birth")
                        .sqFont(.bodySmallSemiBold)
                        .sqForegroundColor(.textPrimary)

                    Text("Optional, but useful for age-aware insights later.")
                        .sqFont(.bodyExtraSmall)
                        .sqForegroundColor(.textSecondary)
                }
            }
            .tint(SQColor.dashboardGlowBlue.color)

            if controller.includesDateOfBirth {
                DatePicker(
                    "Date of Birth",
                    selection: dateOfBirthBinding,
                    in: ...Date(),
                    displayedComponents: .date
                )
                .datePickerStyle(.graphical)
                .labelsHidden()
                .padding(.top, .SQSpace.xs)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.SQSpace.l)
        .sqGlassSurface(level: .card, cornerRadius: .SQCornerRadius.xl)
    }

    @ViewBuilder
    private var sleepScheduleCard: some View {
        VStack(alignment: .leading, spacing: .SQSpace.m) {
            Text("Sleep Schedule")
                .sqFont(.title4)
                .sqForegroundColor(.textPrimary)

            Text("Set your typical sleep and wake times so sleep scoring and check-in timing match your routine.")
                .sqFont(.bodyExtraSmall)
                .sqForegroundColor(.textSecondary)

            labeledRow(label: "Typical Sleep Time") {
                DatePicker(
                    "",
                    selection: sleepTimeBinding,
                    displayedComponents: [.hourAndMinute]
                )
                .labelsHidden()
                .datePickerStyle(.wheel)
                .frame(maxWidth: .infinity)
                .clipped()
            }

            labeledRow(label: "Typical Wake Time") {
                DatePicker(
                    "",
                    selection: wakeTimeBinding,
                    displayedComponents: [.hourAndMinute]
                )
                .labelsHidden()
                .datePickerStyle(.wheel)
                .frame(maxWidth: .infinity)
                .clipped()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.SQSpace.l)
        .sqGlassSurface(level: .card, cornerRadius: .SQCornerRadius.xl)
    }

    @ViewBuilder
    private var bottomAction: some View {
        VStack(alignment: .leading, spacing: .SQSpace.s) {
            if !controller.canSave, let message = controller.saveDisabledMessage {
                Text(message)
                    .sqFont(.bodyExtraSmall)
                    .sqForegroundColor(.textError)
                    .padding(.horizontal, .SQSpace.xl)
            }

            SQButton(
                style: .glassPrimary,
                shouldHugContent: false,
                title: controller.saveButtonTitle,
                isLoading: controller.isLoading
            ) {
                Task {
                    await controller.completeTapped()
                }
            }
            .padding(.horizontal, .SQSpace.xl)
            .padding(.bottom, .SQSpace.l)
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: .SQSpace.l) {
                heroCard
                unitsCard
                profileCard
                sleepScheduleCard
                optionalInfoCard
            }
            .padding(.horizontal, .SQSpace.l)
            .padding(.top, .SQSpace.l)
            .padding(.bottom, .SQSpace.xl)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .navigationTitle(controller.title)
        .navigationBarTitleDisplayMode(.inline)
        .interactiveDismissDisabled(controller.shouldPreventInteractiveDismiss)
        .disabled(controller.isLoading)
        .opacity(controller.isLoading ? 0.6 : 1)
        .background {
            SQSheetBackground()
        }
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 0) {
                Divider()
                    .sqTintColor(.glassStroke)

                bottomAction
            }
            .background(.ultraThinMaterial)
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
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func compactHeightField(label: String, viewModel: SQUITextFieldViewModel) -> some View {
        VStack(alignment: .leading, spacing: .SQSpace.xs) {
            Text(label.uppercased())
                .sqFont(.headerSmall)
                .sqForegroundColor(.textSecondary)

            SQUITextField(viewModel: viewModel)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

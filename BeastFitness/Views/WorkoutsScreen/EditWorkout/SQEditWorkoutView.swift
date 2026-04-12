//
//  SQEditWorkoutView.swift
//  BeastFitness

import SwiftUI

struct SQEditWorkoutView: View {
    @State var controller: SQEditWorkoutController

    @ViewBuilder
    private var heroCard: some View {
        VStack(spacing: .SQSpace.m) {
            ZStack {
                RoundedRectangle(cornerRadius: .SQCornerRadius.xl, style: .continuous)
                    .fill(SQColor.glassCardTint.color.opacity(SQColor.isDarkMode ? 0.84 : 0.96))
                    .overlay(
                        RoundedRectangle(cornerRadius: .SQCornerRadius.xl, style: .continuous)
                            .stroke(SQColor.glassStroke.color, lineWidth: 1)
                    )
                    .frame(width: 78, height: 78)

                SQImageView(
                    image: .init(
                        symbol: .pencil,
                        symbolStyle: .colorWithFont(.textPrimary, font: .title3)
                    )
                )
                .frame(width: 22, height: 22)
            }

            VStack(spacing: .SQSpace.xs) {
                Text("Edit Workout")
                    .sqFont(.title2)
                    .sqForegroundColor(.textPrimary)

                Text("Update the workout title, notes, conditions, and effort details.")
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
    private func questionTitle(title: String) -> some View {
        Text(title.uppercased())
            .sqFont(.headerSmall)
            .sqForegroundColor(.textSecondary)
            .padding(.bottom, .SQSpace.xs)
    }

    @ViewBuilder
    private func ratingRow(
        title: String,
        segments: [SQSegmentedControlSegment],
        selection: Binding<SQSegmentedControlSegment?>,
        scaleMin: String,
        scaleMax: String
    ) -> some View {
        VStack(alignment: .leading, spacing: .SQSpace.m) {
            questionTitle(title: title)

            SQSegmentedControl(segments: segments, selection: selection) { segment in
                Text(segment.title)
                    .sqFont(.title3)
                    .sqForegroundColor(.textPrimary)
            }

            HStack {
                Text(scaleMin)
                    .sqFont(.bodyExtraSmall)
                    .sqForegroundColor(.textSecondary)

                Spacer()

                Text(scaleMax)
                    .sqFont(.bodyExtraSmall)
                    .sqForegroundColor(.textSecondary)
            }
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
        }
        .padding(.SQSpace.l)
        .sqGlassSurface(level: .card, cornerRadius: .SQCornerRadius.xl)
    }

    @ViewBuilder
    private var formContent: some View {
        let bindable = Bindable(controller)

        VStack(alignment: .leading, spacing: .SQSpace.l) {
            heroCard

            if controller.canEditWorkoutMetadata {
                formSection(title: "Details", subtitle: "Name, notes, and weather context.") {
                    SQUITextField(viewModel: controller.titleViewModel)
                    SQTextField(viewModel: controller.notesViewModel)

                    VStack(alignment: .leading, spacing: .SQSpace.s) {
                        questionTitle(title: "Temperature")

                        HStack(spacing: .SQSpace.s) {
                            SQUITextField(viewModel: controller.temperatureViewModel, width: 96)

                            Text(controller.temperatureUnit.unitString ?? "°")
                                .sqFont(.bodySmall)
                                .sqForegroundColor(.textSecondary)

                            Spacer()
                        }
                    }
                }

                formSection(title: "Ratings", subtitle: "Capture performance and effort for future insights.") {
                    ratingRow(
                        title: "How did you perform?",
                        segments: SQEditWorkoutController.performanceSegments,
                        selection: bindable.selectedPerformance,
                        scaleMin: "Very low",
                        scaleMax: "Very high"
                    )

                    ratingRow(
                        title: "How hard was it?",
                        segments: SQEditWorkoutController.difficultySegments,
                        selection: bindable.selectedDifficulty,
                        scaleMin: "Easy",
                        scaleMax: "Max effort"
                    )
                }
            } else {
                SQCallToAction(viewModel: .init(
                    icon: .init(symbol: .personCircle),
                    priority: .standard,
                    badgeTitle: "Login Required",
                    title: "Log in to edit workout details",
                    subtitle: "Sign in to save workout titles, notes, weather, and effort ratings.",
                    actionText: "Tap to log in",
                    onTap: {
                        controller.presentWorkoutEditingLoginFlow()
                    }
                ))
            }
        }
    }

    @ViewBuilder
    private var bottomAction: some View {
        Group {
            if controller.canEditWorkoutMetadata {
                SQButton(
                    style: .glassPrimary,
                    shouldHugContent: false,
                    title: "Done"
                ) {
                    controller.dismiss()
                }
            } else {
                SQButton(
                    style: .glassPrimary,
                    shouldHugContent: false,
                    title: "Log In"
                ) {
                    controller.presentWorkoutEditingLoginFlow()
                }
            }
        }
        .padding(.horizontal, .SQSpace.xl)
        .padding(.top, .SQSpace.m)
        .padding(.bottom, .SQSpace.l)
    }

    var body: some View {
        ScrollView {
            formContent
                .padding(.horizontal, .SQSpace.l)
                .padding(.top, .SQSpace.l)
                .padding(.bottom, .SQSpace.xl)
        }
        .dismissKeyboardOnBackgroundTap()
        .background {
            SQSheetBackground()
        }
        .navigationTitle("Edit Workout")
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 0) {
                Divider()
                    .sqTintColor(.glassStroke)

                bottomAction
            }
            .background(.ultraThinMaterial)
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    if controller.canEditWorkoutMetadata {
                        controller.dismiss()
                    } else {
                        controller.presentWorkoutEditingLoginFlow()
                    }
                } label: {
                    SQImageView(
                        image: .init(
                            symbol: .checkmark,
                            symbolStyle: .colorWithFont(.textPrimary, font: .bodySmall)
                        )
                    )
                    .frame(width: 14, height: 14)
                }
                .buttonStyle(.plain)
            }
        }
        .onAppear {
            controller.onAppear()
        }
        .onChange(of: controller.dismissKeyboard) {
            sqHideKeyboard()
        }
    }
}

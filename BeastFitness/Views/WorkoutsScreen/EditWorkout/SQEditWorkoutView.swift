//
//  SQEditWorkoutView.swift
//  BeastFitness

import SwiftUI

struct SQEditWorkoutView: View {
    @State var controller: SQEditWorkoutController

    // MARK: - Helpers

    @ViewBuilder
    func questionTitle(title: String) -> some View {
        Text(title)
            .sqFont(.body)
            .sqForegroundColor(.textSecondary)
            .padding(.bottom, .SQSpace.s)
    }

    @ViewBuilder
    func ratingRow(
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
                    .sqFont(.bodySmall)
                    .sqForegroundColor(.textSecondary)
                Spacer()
                Text(scaleMax)
                    .sqFont(.bodySmall)
                    .sqForegroundColor(.textSecondary)
            }
        }
    }

    // MARK: - Form

    @ViewBuilder
    var formContent: some View {
        let bindable = Bindable(controller)

        VStack(alignment: .leading, spacing: 0) {

            SQUITextField(viewModel: controller.titleViewModel)
                .padding(.bottom, .SQSpace.xxl)

            SQTextField(viewModel: controller.notesViewModel)
                .padding(.bottom, .SQSpace.xxl)

            HStack(spacing: .SQSpace.s) {
                SQUITextField(viewModel: controller.temperatureViewModel, width: 100)

                Text(SQUnit.degreesFahrenheit.unitString ?? "°F")
                    .sqFont(.body)
                    .sqForegroundColor(.textSecondary)

                Spacer()
            }
            .padding(.bottom, .SQSpace.xxl)

            ratingRow(
                title: "How did you perform?",
                segments: SQEditWorkoutController.performanceSegments,
                selection: bindable.selectedPerformance,
                scaleMin: "Very low",
                scaleMax: "Very high"
            )
            .padding(.bottom, .SQSpace.xxl)

            ratingRow(
                title: "How hard was it?",
                segments: SQEditWorkoutController.difficultySegments,
                selection: bindable.selectedDifficulty,
                scaleMin: "Easy",
                scaleMax: "Max effort"
            )
        }
    }

    // MARK: - Body

    var body: some View {
        ScrollView {
            formContent
                .padding(.SQSpace.xxl)
        }
        .dismissKeyboardOnBackgroundTap()
        .sqBackgroundColor(.background)
        .navigationTitle("Edit Workout")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    controller.dismiss()
                } label: {
                    Image(systemName: SQImageSymbol.checkmark.rawValue)
                }
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

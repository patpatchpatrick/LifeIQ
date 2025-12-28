//
//  SQWorkoutSessionExerciseView.swift
//  BeastFitness
//
//  Created by Patrick Doyle on 12/6/25.
//

import SwiftUI

/// Emits multiple rows into the parent List:
/// - Exercise header
/// - Set rows (with swipe to delete)
/// - "Add Set" row
struct SQWorkoutSessionExerciseRow: View {
    @Bindable var viewModel: SQWorkoutSessionExerciseViewModel

    // MARK: - Styling

    private var headerInsets: EdgeInsets {
        .init(top: .SQSpace.m, leading: .SQSpace.xl, bottom: .SQSpace.s, trailing: .SQSpace.xl)
    }

    private var setInsets: EdgeInsets {
        .init(top: .SQSpace.s, leading: .SQSpace.xl, bottom: .SQSpace.s, trailing: .SQSpace.xl)
    }

    private var addSetInsets: EdgeInsets {
        .init(top: .SQSpace.s, leading: .SQSpace.xl, bottom: .SQSpace.m, trailing: .SQSpace.xl)
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            // Header row
            headerRow
                .listRowInsets(headerInsets)
                .listRowBackground(SQColor.background.color)
                .padding(.bottom, .SQSpace.l)

            // Set rows
            VStack(spacing: .SQSpace.l) {
                ForEach(viewModel.sets) { setVM in
                    setRow(setVM)
                        .listRowInsets(setInsets)
                        .listRowBackground(SQColor.backgroundSecondary.color)
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                withAnimation {
                                    viewModel.removeSet(setVM)
                                }
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                }
            }
            .padding(.bottom, .SQSpace.l)

            // Add set row
            addSetRow
                .listRowInsets(addSetInsets)
                .listRowBackground(SQColor.background.color)
        }
    }

    // MARK: - Rows

    private var headerRow: some View {
        HStack {
            Text(viewModel.name)
                .sqFont(.bodyLarge)
                .sqForegroundColor(.textPrimary)

            Spacer()

            Menu {
                Button(role: .destructive) {
                    viewModel.deleteExercise()
                } label: {
                    Label("Delete exercise", systemImage: SQImageSymbol.minusCircle.rawValue)
                }
            } label: {
                Image(systemName: SQImageSymbol.ellipsisCircle.rawValue)
                    .imageScale(.large)
            }
        }
    }

    private func setRow(_ setVM: SQWorkoutSessionSetViewModel) -> some View {
        HStack(spacing: .SQSpace.s) {
            Text("#\(setVM.setIndex)")
                .sqFont(.bodySmallBold)
                .sqForegroundColor(.textSecondary)
                .frame(width: 28, alignment: .leading)

            // Reps
            SQTextField(viewModel: setVM.repsTextFieldViewModel)
                .frame(width: 60)

            // Weight
            SQTextField(viewModel: setVM.weightTextFieldViewModel)
                .frame(width: 80)

            Text("lbs")
                .sqFont(.bodySmall)
                .sqForegroundColor(.textSecondary)

            Spacer()

            Button {
                setVM.isCompleted.toggle()
            } label: {
                Image(systemName: setVM.isCompleted ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(
                        setVM.isCompleted
                        ? SQColor.colorGreenDarkBorder.color
                        : SQColor.textSecondary.color
                    )
            }
            .buttonStyle(.plain)
        }
        .contentShape(Rectangle()) // keeps swipes + taps reliable around textfields
    }

    private var addSetRow: some View {
        SQButton(
            style: .secondary,
            shouldHugContent: false,
            title: "Add Set",
            icon: .plus
        ) {
            withAnimation {
                viewModel.addSet()
            }
        }
    }
}

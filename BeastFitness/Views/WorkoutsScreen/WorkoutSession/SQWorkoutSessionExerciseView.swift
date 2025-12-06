//
//  SQWorkoutSessionExerciseView.swift
//  BeastFitness
//
//  Created by Patrick Doyle on 12/6/25.
//

import SwiftUI

struct SQWorkoutSessionExerciseRow: View {
    @Bindable var viewModel: SQWorkoutSessionExerciseViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: .SQSpace.m) {
            // Header
            HStack {
                Text(viewModel.name)
                    .sqFont(.title3)
                    .sqForegroundColor(.textPrimary)
                
                Spacer()
                
                if viewModel.isCompleted {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(SQColor.colorGreenDarkBorder.color)
                }
            }
            
            // Sets
            VStack(spacing: .SQSpace.s) {
                ForEach(viewModel.sets) { setVM in
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
                }
            }
            .padding(.SQSpace.m)
            .sqBackgroundColor(.backgroundSecondary)
            .cornerRadius(12)
            
            SQButton(
                style: .secondary,
                shouldHugContent: true,
                title: "Add Set",
                icon: .plus) {
                    viewModel.addSet()
                }
        }
        .padding(.SQSpace.m)
        .sqBackgroundColor(.background)
        .cornerRadius(16)
    }
}


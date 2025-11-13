//
//  SQDashboardWeekSummaryRow.swift
//  BeastFitness
//
//  Created by Patrick Doyle on 11/13/25.
//

import SwiftUI

struct SQDashboardWeekSummaryRow: View {
    @Bindable var viewModel: SQDashboardWeekSummaryRowViewModel
    
    var cardBody: some View {
        LazyVStack(spacing: 0) {
            ForEach(viewModel.workoutViewModels) { workoutViewModel in
               SQDashboardWorkoutView(viewModel: workoutViewModel)
            }
        }
    }
    
    var body: some View {
        Section(header:
                Text(viewModel.sectionTitle)
                    .sqFont(.title2)
                    .sqForegroundColor(.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, .SQSpace.l)
        ) {
            cardBody
                .sqBackgroundColor(.backgroundSecondary)
                .padding(.horizontal, .SQSpace.l)
                .padding(.top, .SQSpace.xl)
                .cornerRadius(.SQSpace.m)
        }
    }
}

struct SQDashboardWorkoutView: View {
    @Bindable var viewModel: SQDashboardWorkoutViewModel
    
    var body: some View {
        Text(viewModel.testTitle)
            .padding(.horizontal, .SQSpace.l)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

//
//  SQWorkoutSummaryView.swift
//  BeastFitness
//
//  Created by Patrick Doyle on 12/6/25.
//

import SwiftUI

struct SQWorkoutSummaryView: View {
    @State var controller: SQWorkoutSummaryController
    
    @ViewBuilder
    var userNameAndDateRow: some View {
        HStack(spacing: .SQSpace.l) {
            
            SQUserIcon(user: controller.state.user ?? .mock)
                .redacted(controller.state.user == nil, reason: .placeholder)
            
            VStack(alignment: .leading, spacing: .SQSpace.xs) {
                Text(controller.state.userFullName ?? SQUser.mock.name)
                    .sqFont(.title3)
                    .sqForegroundColor(.textPrimary)
                    .redacted(controller.state.userFullName == nil, reason: .placeholder)
                
                Text(controller.state.workoutStartDate?.formattedString(with: .full) ?? Date.now.formattedString(with: .full))
                    .sqFont(.body)
                    .sqForegroundColor(.textSecondary)
                    .redacted(controller.state.workoutStartDate == nil, reason: .placeholder)
            }
            
            Spacer()
        }
    }
    
    @ViewBuilder
    var mainStack: some View {
        VStack(alignment: .leading, spacing: 0) {
            userNameAndDateRow
                .padding(.bottom, .SQSpace.xl)
            
            Text(controller.state.workoutTitle ?? "My workout")
                .sqFont(.title3)
                .sqForegroundColor(.textPrimary)
                .redacted(controller.state.workoutTitle == nil, reason: .placeholder)
        }
    }
    
    @ViewBuilder
    var mainScroll: some View {
        ScrollView {
            mainStack
                .padding(.SQSpace.xl)
        }
    }
    var body: some View {
        mainScroll
            .navigationTitle("Workout summary")
    }
}

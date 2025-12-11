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
                .padding(.bottom, .SQSpace.xl)
            
            VStack(spacing: .SQSpace.m) {
                ForEach(controller.state.workoutStatsRows) { row in
                    SQWorkoutSummaryStatsRow(row: row)
                }
            }
            .padding(.horizontal, .SQSpace.xxl)
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
            .background(SQColor.background.color)
            .navigationTitle("Workout summary")
    }
}

struct SQWorkoutSummaryStatsRow: View {
    let row: SQWorkoutSummaryStatRow
    
    @ViewBuilder
    func buildStat(_ stat: SQWorkoutSessionVisibleStat) -> some View {
        VStack(spacing: .SQSpace.s) {
            Text(stat.title)
                .sqFont(.bodyExtraSmall)
                .sqForegroundColor(.textSecondary)
            
            Text(stat.value)
                .sqFont(.bodySmallBold)
                .sqForegroundColor(.textPrimary)
        }
    }
    
    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(row.visibleStats.enumerated()), id: \.1) { (index, visibleStat) in
                
                buildStat(visibleStat)
                
                if index != row.visibleStats.count - 1 {
                    Spacer()
                }
            }
        }
    }
}

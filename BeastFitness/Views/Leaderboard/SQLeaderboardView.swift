//
//  SQLeaderboardView.swift
//  BeastFitness
//
//  Created by Claude on 2/12/26.
//

import SwiftUI

struct SQLeaderboardView: View {
    @Bindable var controller: SQLeaderboardController

    var navView: some View {
        ScrollView {
            VStack(spacing: .SQSpace.xl) {
                // Placeholder content - will be populated with actual leaderboard items
                Text("Leaderboard for \(controller.quantityType.displayTitle)")
                    .sqFont(.bodySmall)
                    .sqForegroundColor(.textSecondary)

                Text("Activity: \(controller.activityType.name)")
                    .sqFont(.bodySmall)
                    .sqForegroundColor(.textSecondary)

                Text("\(controller.workouts.count) workouts")
                    .sqFont(.bodySmall)
                    .sqForegroundColor(.textSecondary)
            }
            .padding(.SQSpace.l)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .navigationTitle("Leaderboard")
        .navigationBarTitleDisplayMode(.inline)
        .background(SQColor.background.color)
    }

    var navStack: some View {
        NavigationStack(path: $controller.navigationPath) {
            navView
        }
    }

    var body: some View {
        navStack
    }
}

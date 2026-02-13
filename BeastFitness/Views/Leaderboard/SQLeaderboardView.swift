//
//  SQLeaderboardView.swift
//  BeastFitness
//
//  Created by Claude on 2/12/26.
//

import SwiftUI

struct SQLeaderboardView: View {
    @Bindable var controller: SQLeaderboardController
    @Environment(\.modelContext) private var modelContext

    var loadingView: some View {
        VStack(spacing: .SQSpace.xl) {
            ProgressView()
                .progressViewStyle(.circular)
                .scaleEffect(1.5)
                .padding(.top, 100)

            Text("Loading leaderboard...")
                .sqFont(.bodySmall)
                .sqForegroundColor(.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    var emptyStateView: some View {
        VStack(spacing: .SQSpace.xl) {
            Text("No workouts found")
                .sqFont(.bodySmall)
                .sqForegroundColor(.textSecondary)

            Text("Complete some \(controller.activityType.name.lowercased()) workouts to see your leaderboard")
                .sqFont(.bodyExtraSmall)
                .sqForegroundColor(.textTertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, .SQSpace.xxl)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.top, 100)
    }

    var leaderboardList: some View {
        List {
            ForEach(Array(controller.rows.enumerated()), id: \.1.id) { index, row in
                VStack(spacing: 0) {
                    SQLeaderboardRowView(viewModel: row)

                    if index != controller.rows.count - 1 {
                        Divider()
                            .sqTintColor(.divider(1))
                            .padding(.top, .SQSpace.l)
                            .padding(.bottom, .SQSpace.l)
                            .background(SQColor.background.color)
                    }
                }
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }

    var contentView: some View {
        Group {
            if controller.isLoading {
                loadingView
            } else if controller.rows.isEmpty {
                emptyStateView
            } else {
                leaderboardList
            }
        }
    }

    var navView: some View {
        contentView
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .navigationTitle(controller.title)
            .navigationBarTitleDisplayMode(.inline)
            .background(SQColor.background.color)
            .task {
                await controller.loadUI(for: modelContext)
            }
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

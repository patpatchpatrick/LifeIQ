//
//  SQExercisesListView.swift
//  BeastFitness
//
//  Created by Patrick Doyle on 12/8/25.
//

import SwiftUI

// MARK: - View

@available(*, deprecated, message: "Only used by SQDeprecatedWorkoutSessionView. Not used in active app flows.")
struct SQExercisesListView: View {
    @State var controller: SQExercisesListController

    @ViewBuilder
    private func rowCell(
        row: SQExercisesListItemViewModel,
        showDivider: Bool,
        topPadding: CGFloat,
        bottomPadding: CGFloat
    ) -> some View {
        VStack(spacing: 0) {
            Button(
                action: { controller.exerciseSelected(row.rawExercise) },
                label: { SQExercisesListItem(viewModel: row) }
            )
            .padding(.top, topPadding)
            .padding(.bottom, bottomPadding)
            .padding(.horizontal, .SQSpace.l)

            if showDivider {
                Divider()
                    .sqTintColor(.divider(1))
                    .padding(.top, .SQSpace.xl)
                    .padding(.bottom, .SQSpace.xl)
                    .background(SQColor.background.color)
            }
        }
        .listRowInsets(EdgeInsets())
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
    }

    @ViewBuilder
    var mainScroll: some View {
        List {
            if !controller.recentRows.isEmpty {
                Section {
                    ForEach(Array(controller.recentRows.enumerated()), id: \.1) { (index, row) in
                        rowCell(
                            row: row,
                            showDivider: index != controller.recentRows.count - 1,
                            topPadding: index == 0 ? .SQSpace.s : 0,
                            bottomPadding: index == controller.recentRows.count - 1 ? .SQSpace.l : 0
                        )
                    }
                } header: {
                    if !controller.recentRows.isEmpty {
                        Text("Recent")
                            .sqFont(.headerSmall)
                            .sqForegroundColor(.textSecondary)
                            .padding(.horizontal, .SQSpace.l)
                            .padding(.top, .SQSpace.m)
                            .textCase(nil)
                    }
                }
            }

            Section {
                ForEach(Array(controller.otherRows.enumerated()), id: \.1) { (index, row) in
                    rowCell(
                        row: row,
                        showDivider: index != controller.otherRows.count - 1,
                        topPadding: (controller.recentRows.isEmpty && index == 0) ? .SQSpace.s : 0,
                        bottomPadding: index == controller.otherRows.count - 1 ? .SQSpace.xl : 0
                    )
                }
            } header: {
                if !controller.otherRows.isEmpty {
                    Text("All Exercises")
                        .sqFont(.headerSmall)
                        .sqForegroundColor(.textSecondary)
                        .padding(.horizontal, .SQSpace.l)
                        .padding(.top, .SQSpace.m)
                        .textCase(nil)
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }

    var navView: some View {
        mainScroll
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .navigationTitle("Add Exercises")
            .navigationBarTitleDisplayMode(.inline)
            .background(SQColor.background.color)
            .searchable(
                text: $controller.searchText,
                placement: .navigationBarDrawer(displayMode: .automatic),
                prompt: "Search exercises"
            )
    }

    @ViewBuilder
    var navStack: some View {
        NavigationStack {
            navView
        }
    }

    var body: some View {
        navStack
    }
}

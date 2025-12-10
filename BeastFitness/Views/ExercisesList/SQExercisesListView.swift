//
//  SQExercisesListView.swift
//  BeastFitness
//
//  Created by Patrick Doyle on 12/8/25.
//

import SwiftUI

struct SQExercisesListView: View {
    @State var controller: SQExercisesListController
    
    @ViewBuilder
    var mainScroll: some View {
        List {
            ForEach(Array(controller.rows.enumerated()), id: \.1) { (index, row) in
                
                VStack(spacing: 0) {
                    Button(
                        action: { controller.exerciseSelected(row.rawExercise) },
                        label: { SQExercisesListItem(viewModel: row) })
                    .padding(.top, index == 0 ? .SQSpace.s : 0)
                    .padding(.bottom, index == controller.rows.count - 1 ? .SQSpace.xl : 0)
                    .padding(.horizontal, .SQSpace.l)
                    
                    if index != controller.rows.count - 1 {
                        Divider()
                            .sqTintColor(.divider)
                            .padding(.top, .SQSpace.xl)
                            .padding(.bottom, .SQSpace.xl)
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
    
    var navView: some View {
        mainScroll
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .navigationTitle("Add Exercises")
            .navigationBarTitleDisplayMode(.inline)
            .background(SQColor.background.color)
            .searchable(text: $controller.searchText,
                        placement: .navigationBarDrawer(displayMode: .automatic),
                        prompt: "Search exercises")
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

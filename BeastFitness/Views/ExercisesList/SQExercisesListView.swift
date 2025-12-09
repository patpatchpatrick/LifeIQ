//
//  SQExercisesListView.swift
//  BeastFitness
//
//  Created by Patrick Doyle on 12/8/25.
//

import SwiftUI

struct SQExercisesListView: View {
    @Bindable var controller: SQExercisesListController
    
    @ViewBuilder
    var mainStack: some View {
        ForEach(controller.rows) { row in
            Button(
                action: { print("PTD Exercise Tapped", row.title) },
                label: { SQExercisesListItem(viewModel: row) })
        }
    }
    
    @ViewBuilder
    var mainScroll: some View {
        List {
            mainStack
                .padding(.SQSpace.xl)
        }
    }
    
    var navView: some View {
        mainScroll
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .navigationTitle("Add Exercises")
            .navigationBarTitleDisplayMode(.inline)
            .background(SQColor.backgroundSecondary.color)
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

//
//  SQWorkoutsListView.swift
//  BeastFitness
//
//  Created by Patrick Doyle on 12/6/25.
//

import SwiftUI

struct SQWorkoutsListView: View {
    @Bindable var controller: SQWorkoutsListController
    
    @ViewBuilder
    var mainStack: some View {
        VStack(alignment: .leading, spacing: .SQSpace.xl) {
            ForEach(controller.rows) { row in
                SQWorkoutsListItem(viewModel: row)
            }
        }
    }
    
    @ViewBuilder
    var mainScroll: some View {
        ScrollView {
            mainStack
                .padding(.SQSpace.xl)
        }
    }
    
    @ViewBuilder
    var navStack: some View {
        NavigationStack {
            mainScroll
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .navigationTitle("Workouts")
                .navigationBarTitleDisplayMode(.inline)
                .background(SQColor.backgroundSecondary.color)
        }
    }

    var body: some View {
        navStack
    }
}

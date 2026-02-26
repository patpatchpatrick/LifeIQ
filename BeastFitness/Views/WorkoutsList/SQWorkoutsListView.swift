//
//  SQWorkoutsListView.swift
//  BeastFitness
//
//  Created by Patrick Doyle on 12/6/25.
//

import SwiftUI

struct SQWorkoutsListView: View {
    @State var controller: SQWorkoutsListController
    
    @ViewBuilder
    var mainStack: some View {
        VStack(alignment: .leading, spacing: .SQSpace.xl) {
            ForEach(controller.rows) { row in
                Button(
                    action: { controller.displayWorkoutSummary(for: row) },
                    label: { SQWorkoutsListItem(viewModel: row) })
            }
        }
    }
    
    @ViewBuilder
    var mainScroll: some View {
        List {
            ForEach(Array(controller.rows.enumerated()), id: \.1) { (index, row) in
                
                VStack(spacing: 0) {
                    Button(
                        action: { controller.displayWorkoutSummary(for: row) },
                        label: { SQWorkoutsListItem(viewModel: row) })
                    
                    if index != controller.rows.count - 1 {
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
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }
 
    var body: some View {
        mainScroll
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .navigationTitle("Workouts")
            .navigationBarTitleDisplayMode(.inline)
            .background(SQColor.background.color)
    }
}

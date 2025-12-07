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
    var mainStack: some View {
        Text("Workout summary")
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

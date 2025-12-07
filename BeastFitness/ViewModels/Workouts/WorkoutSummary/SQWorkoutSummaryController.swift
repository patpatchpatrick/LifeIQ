//
//  SQWorkoutSummaryView.swift
//  BeastFitness
//
//  Created by Patrick Doyle on 12/6/25.
//

import SwiftUI

@MainActor
protocol SQWorkoutSummaryInterface {
}

@Observable @MainActor
final class SQWorkoutSummaryController: SQWorkoutsListInterface {

    init(workout: SQWorkoutSessionable) {
    }
}

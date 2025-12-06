//
//  SQWorkoutSessionViewModel.swift
//  BeastFitness
//
//  Created by Patrick Doyle on 12/5/25.
//

import SwiftUI

@Observable @MainActor
final class SQWorkoutSessionViewModel: Identifiable {
    let id = UUID()
    let interface: SQWorkoutsScreenInterface = SQWorkoutsScreenController.default
}

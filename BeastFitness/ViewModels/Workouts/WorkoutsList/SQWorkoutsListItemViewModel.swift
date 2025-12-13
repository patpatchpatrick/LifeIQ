//
//  SQWorkoutsListItemViewModel.swift
//  BeastFitness
//
//  Created by Patrick Doyle on 12/6/25.
//

import SwiftUI

@Observable @MainActor
final class SQWorkoutsListItemViewModel: Identifiable, Hashable, Equatable {
    let id = UUID()
    let workout: SQWorkoutSessionable
    let title: String
    let subtitle: String?
    let workoutImageSymbol: SQImageSymbol
    
    init(workout: SQWorkoutSessionable) {
        self.workout = workout
        let activityType = workout.activityType
        title = workout.title
        
        let subtitle: String? = {
            var subtitleComponents = [String]()
            
            if let startDate = workout.startDate {
                subtitleComponents.append(startDate.formattedString(with: .fullWithoutDayName))
            }
            
            if let device = workout.device {
                subtitleComponents.append(device.name)
            }
            
            guard !subtitleComponents.isEmpty else { return nil }
            return subtitleComponents.joined(separator: " - ")
        }()
        self.subtitle = subtitle
        
        workoutImageSymbol = activityType.imageSymbol
    }
    
    nonisolated func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    nonisolated static func == (lhs: SQWorkoutsListItemViewModel, rhs: SQWorkoutsListItemViewModel) -> Bool {
        lhs.id == rhs.id
    }
}

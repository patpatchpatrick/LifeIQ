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
    var workout: SQWorkoutSessionable {
        didSet {
            refreshUI(with: workout)
        }
    }
    private(set) var title: String = ""
    private(set) var subtitle: String?
    private(set) var workoutImageSymbol: SQImageSymbol? = nil
    
    init(workout: SQWorkoutSessionable) {
        self.workout = workout
        refreshUI(with: workout)
    }
    
    private func refreshUI(with workout: SQWorkoutSessionable) {
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

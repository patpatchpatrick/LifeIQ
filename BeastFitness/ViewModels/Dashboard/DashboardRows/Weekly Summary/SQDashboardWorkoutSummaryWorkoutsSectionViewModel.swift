//
//  SQDashboardWeekSummaryWorkoutsSectionViewModel.swift
//  BeastFitness
//
//  Created by Patrick Doyle on 11/13/25.
//

import SwiftUI
import HealthKit

@Observable @MainActor
final class SQDashboardWorkoutSummaryWorkoutsSectionViewModel {
    let sectionTitle: String
    let workoutGroupViewModels: [SQDashboardWorkoutGroupViewModel]
    
    init(workouts: [SQWorkoutSessionable]) {
        self.sectionTitle = "Workouts"
        
        var workoutGroupViewModels = [SQDashboardWorkoutGroupViewModel]()
        for (activityType, workouts) in workouts.workoutsByActivityType.sorted(by: { $0.value.count > $1.value.count }) {
            workoutGroupViewModels.append(.init(activityType: activityType, workouts: .init(workouts: workouts)))
        }
        self.workoutGroupViewModels = workoutGroupViewModels
    }
}

@Observable @MainActor
final class SQDashboardWorkoutGroupViewModel: Identifiable, Hashable, Equatable {
    let id = UUID()
    let title: String
    let workoutImageSymbol: SQImageSymbol
    let workoutStatsString: AttributedString
    
    init(activityType: HKWorkoutActivityType, workouts: SQWorkouts) {
        title = "\(workouts.workouts.count) \(activityType.name)"
        workoutImageSymbol = workouts.workouts.compactMap { $0.activityType.imageSymbol }.first ?? .questionmarkCircle
        
        // Assign slightly different neutral colors to each stat’s descriptor
        let outputColor   = SQColor.accentNeutral1.color
        let timeColor     = SQColor.accentNeutral2.color
        let caloriesColor = SQColor.accentNeutral3.color
        let hrColor       = SQColor.accentNeutral4.color
        
        // Format individual stats with those descriptor colors
        let output   = workouts.formattedTotalOutput(valueColor: outputColor, unitColor: outputColor)
        let time     = workouts.formattedTime(valueColor: timeColor, unitColor: timeColor)
        let calories = workouts.formattedCalories(valueColor: caloriesColor, unitColor: caloriesColor)
        let heartRate = workouts.formattedHeartRate(valueColor: hrColor, unitColor: hrColor)
        
        // Combine them with comma separation
        var combined = AttributedString("")
        let stats = [output, time, calories, heartRate].compactMap { $0 }
        
        for (idx, stat) in stats.enumerated() {
            if idx > 0 {
                combined.append(
                    AttributedString.build(with: ", ",
                           font: SQFont(type: .bodySmall).font,
                           color: SQColor.textTertiary.color)
                )
            }
            combined.append(stat)
        }
        
        self.workoutStatsString = combined
    }
    
    nonisolated func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    nonisolated static func == (lhs: SQDashboardWorkoutGroupViewModel, rhs: SQDashboardWorkoutGroupViewModel) -> Bool {
        lhs.id == rhs.id
    }
}

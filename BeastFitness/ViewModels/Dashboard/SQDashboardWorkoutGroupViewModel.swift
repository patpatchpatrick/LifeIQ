//
//  SQDashboardWorkoutGroupViewModel.swift
//  BeastFitness
//
//  Created by Patrick Doyle on 2/7/26.
//

import SwiftUI
import HealthKit

@Observable @MainActor
final class SQDashboardWorkoutGroupViewModel: Identifiable, Hashable, Equatable {
    let dashboardState = SQAppState.shared.dashboardState
    let workouts: SQWorkouts
    let id = UUID()
    let title: String
    let subtitle: String?
    let workoutImageSymbol: SQImageSymbol
    let workoutStatsString: AttributedString

    init(activityType: HKWorkoutActivityType, workouts: SQWorkouts) {
        self.workouts = workouts

        if workouts.workouts.count == 1, let single = workouts.workouts.first {
            title = single.visibleTitle
            subtitle = single.reviewNotes
        } else {
            title = "\(workouts.workouts.count) \(activityType.name)"
            let maxShown = 2
            let titles = workouts.workouts.prefix(maxShown).map(\.visibleTitle)
            let remaining = workouts.workouts.count - maxShown
            if remaining > 0 {
                subtitle = titles.joined(separator: ", ") + " +\(remaining) more"
            } else {
                subtitle = titles.joined(separator: ", ")
            }
        }
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
    
    func displayWorkoutsSheet() {
        dashboardState.navigateToWorkoutView(with: workouts.workouts)
    }
    
    nonisolated func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    nonisolated static func == (lhs: SQDashboardWorkoutGroupViewModel, rhs: SQDashboardWorkoutGroupViewModel) -> Bool {
        lhs.id == rhs.id
    }
}

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
    struct WorkoutStatItem: Identifiable {
        let id: String
        let title: String
        let value: AttributedString
        let isPremiumLocked: Bool
        let accentColor: SQColor?

        init(
            id: String,
            title: String,
            value: AttributedString,
            isPremiumLocked: Bool = false,
            accentColor: SQColor? = nil
        ) {
            self.id = id
            self.title = title
            self.value = value
            self.isPremiumLocked = isPremiumLocked
            self.accentColor = accentColor
        }
    }

    let dashboardState = SQAppState.shared.dashboardState
    let workouts: SQWorkouts
    let id = UUID()
    let title: String
    let subtitle: String?
    let workoutImageSymbol: SQImageSymbol
    let workoutStatsItems: [WorkoutStatItem]

    init(
        activityType: HKWorkoutActivityType,
        workouts: SQWorkouts,
        additionalStatItems: [WorkoutStatItem] = []
    ) {
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

        self.workoutStatsItems = Self.buildWorkoutStatItems(for: workouts) + additionalStatItems
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

private extension SQDashboardWorkoutGroupViewModel {
    static func buildWorkoutStatItems(for workouts: SQWorkouts) -> [WorkoutStatItem] {
        let valueFont = SQFont(type: .bodySmallSemiBold).font
        let unitFont = SQFont(type: .bodyExtraSmall).font
        let valueColor = SQColor.textPrimary.color
        let unitColor = SQColor.textSecondary.color

        let statDefinitions: [(id: String, title: String, value: AttributedString?)] = [
            (
                id: "output",
                title: "Output",
                value: workouts.formattedTotalOutput(
                    valueFont: valueFont,
                    unitFont: unitFont,
                    valueColor: valueColor,
                    unitColor: unitColor
                )
            ),
            (
                id: "time",
                title: "Time",
                value: workouts.formattedTime(
                    valueFont: valueFont,
                    unitFont: unitFont,
                    valueColor: valueColor,
                    unitColor: unitColor
                )
            ),
            (
                id: "calories",
                title: "Calories",
                value: workouts.formattedCalories(
                    valueFont: valueFont,
                    unitFont: unitFont,
                    valueColor: valueColor,
                    unitColor: unitColor
                )
            ),
            (
                id: "heart-rate",
                title: "Avg HR",
                value: workouts.formattedHeartRate(
                    valueFont: valueFont,
                    unitFont: unitFont,
                    valueColor: valueColor,
                    unitColor: unitColor
                )
            )
        ]

        return statDefinitions.compactMap { definition in
            guard let value = definition.value else { return nil }
            return WorkoutStatItem(
                id: definition.id,
                title: definition.title,
                value: value
            )
        }
    }
}

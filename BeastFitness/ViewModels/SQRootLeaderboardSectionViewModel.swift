//
//  SQRootLeaderboardSectionViewModel.swift
//  BeastFitness
//
//  Created by Patrick Doyle on 10/21/24.
//

import Foundation
import HealthKit

@Observable
class SQRootLeaderboardSectionViewModel: NSObject {
    let isPlaceholder: Bool
    let title: String
    var rows: [SQRootLeaderboardSectionRowViewModel]
    
    let workouts: [SQWorkoutSession]?
    
    var activityTypeDropDownMenuViewModel:SQDropDownMenuViewModel?
    var selectedActivityType: HKWorkoutActivityType?
    
    init(isPlaceholder: Bool = false, title: String, workouts: [SQWorkoutSession]?) {
        self.isPlaceholder = isPlaceholder
        self.title = title
        
        self.workouts = workouts
        self.rows = []
        
        super.init()
        
        buildDropDownMenu()
        if let selectedActivityType {
            refreshLeaderboard(selectedActivityType)
        }
    }
    
    private func buildDropDownMenu() {
        let workoutsByType = workouts?.workoutsByActivityType ?? .init()
        let activityTypes = workoutsByType.keys.sorted { $0.name < $1.name }
        
        var mostPopularActivityType: HKWorkoutActivityType?
        var mostPopularCount = 0
        for (activityType, workouts) in workoutsByType {
            if workouts.count >= mostPopularCount {
                mostPopularActivityType = activityType
                mostPopularCount = workouts.count
            }
        }
        
        guard let mostPopularActivityType else { return }
        selectedActivityType = mostPopularActivityType
        
        activityTypeDropDownMenuViewModel = .init(
            defaultItem: .init(title: mostPopularActivityType.name),
            items: activityTypes.map { .init(title: $0.name) })
        { [weak self] selectedMenuItemTitle in
            guard let self, let activityType = activityTypes.first(where: { $0.name == selectedMenuItemTitle }) else { return }
            self.selectedActivityType = activityType
            self.refreshLeaderboard(activityType)
        }
    }
    
    private func refreshLeaderboard(_ activityType: HKWorkoutActivityType) {
        let workoutsByType = workouts?.workoutsByActivityType ?? .init()
        let workoutsForActivityType = (workoutsByType[activityType] ?? []).sorted { $0.coreOutput ?? 0 > $1.coreOutput ?? 0 }
        var rows = [SQRootLeaderboardSectionRowViewModel]()
        for (rank, workout) in workoutsForActivityType.enumerated() {
            rows.append(.init(workout: workout, rank: rank+1))
        }
        self.rows = rows
    }
}

@Observable
class SQRootLeaderboardSectionRowViewModel: Identifiable, Hashable, Equatable {

    let id = UUID()
    let workout: SQWorkoutSession
    
    let rankString: String
    let title: String
    let subtitle: String
    let outputString: String
    
    init(workout: SQWorkoutSession, rank: Int) {
        self.workout = workout
        
        self.rankString = "\(rank)"
        self.title = workout.activityType.name
        if let startDate = workout.startDate {
            subtitle = SQDateFormatters.shared.dateShortFormatter.string(from: startDate)
        } else {
            subtitle = ""
        }
        
        self.outputString = workout.outputString ?? ""
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: SQRootLeaderboardSectionRowViewModel, rhs: SQRootLeaderboardSectionRowViewModel) -> Bool {
        lhs.id == rhs.id
    }
    
}

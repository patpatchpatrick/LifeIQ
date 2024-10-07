//
//  RootActivitySectionViewModel.swift
//  BeastFitness
//
//  Created by Patrick Doyle on 9/30/24.
//

import Foundation
import HealthKit

@Observable
class RootActivitySectionViewModel {
    let isPlaceholder: Bool
    let title: String
    let rows: [RootActivitySectionRowViewModel]
    let columnOrder: [ActivityColumnStatType] = [
        .activityIcon,
        .count,
        .output,
        .time
    ]
    
    init(isPlaceholder: Bool = false, title: String, workouts: [HKWorkout]?) {
        self.isPlaceholder = isPlaceholder
        self.title = title
        
        let workoutsByType = workouts?.workoutsByActivityType ?? .init()
        
        var rows = [RootActivitySectionRowViewModel]()
        for (workoutType, workouts) in workoutsByType {
            rows.append(.init(columnStatTypes: columnOrder, workoutType: workoutType, workouts: workouts))
        }
        self.rows = rows
    }
}

enum ActivityColumnStatType {
    case activityIcon
    case count
    case output
    case time
}

@Observable
class RootActivitySectionRowViewModel: Identifiable {
    let id = UUID()
    let columns: [RootActivitySectionColumnViewModel]
    
    init(columnStatTypes: [ActivityColumnStatType], workoutType: HKWorkoutActivityType, workouts: [HKWorkout]) {
        var subRows = [RootActivitySectionColumnViewModel]()
        for columnStatType in columnStatTypes {
            subRows.append(.init(statType: columnStatType, workouts: workouts))
        }
        for idx in [0, 1, 2, 3, 4, 5, 6, 7, 8 , 9, 10] {
            subRows.append(.init(statType: .activityIcon, workouts: workouts))
        }
        self.columns = subRows
    }
}

@Observable
class RootActivitySectionColumnViewModel: Identifiable {
    let id = UUID()
    let title: String
    
    init(statType: ActivityColumnStatType, workouts: [HKWorkout]) {
        let activityType = workouts.first?.workoutActivityType ?? .other
        
        switch statType {
        case .activityIcon:
            title = "Icon"
        case .count:
            title = "\(workouts.count)"
        case .output:
            title = "TBD"
        case .time:
            title = "TBD"
        }
    }
}

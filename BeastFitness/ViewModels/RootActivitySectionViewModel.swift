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
    let rowTypeOrder: [RootActivitySectionRowViewModel.RowType] = [
        .count,
        .distance
    ]
    
    init(isPlaceholder: Bool = false, title: String, workouts: [HKWorkout]?) {
        self.isPlaceholder = isPlaceholder
        self.title = title
        
        let workoutsByType = workouts?.workoutsByActivityType ?? .init()
        
        var rows = [RootActivitySectionRowViewModel]()
        for rowTypeOrder in rowTypeOrder {
            rows.append(.init(rowType: rowTypeOrder, workoutsByType: workoutsByType))
        }
        self.rows = rows
    }
}

@Observable
class RootActivitySectionRowViewModel: Identifiable {
    enum RowType {
        case count
        case distance
    }
    let id = UUID()
    let rowType: RowType
    let title: String
    let subRows: [RootActivitySectionSubRowViewModel]
    
    init(rowType: RowType, workoutsByType: [HKWorkoutActivityType : [HKWorkout]]) {
        self.rowType = rowType
        
        switch rowType {
        case .count:
            self.title = "Count"
        case .distance:
            self.title = "Distance"
        }
        
        var subRows = [RootActivitySectionSubRowViewModel]()
        for (_ , workouts) in workoutsByType {
            subRows.append(.init(rowType: rowType, workouts: workouts))
        }
        self.subRows = subRows
    }
}

@Observable
class RootActivitySectionSubRowViewModel: Identifiable {
    let id = UUID()
    let rowType: RootActivitySectionRowViewModel.RowType
    let title: String
    
    init(rowType: RootActivitySectionRowViewModel.RowType, workouts: [HKWorkout]) {
        self.rowType = rowType
        let activityType = workouts.first?.workoutActivityType ?? .other
        
        switch rowType {
        case .count:
            self.title = "\(activityType.name) \(workouts.count)"
        case .distance:
            self.title = "PTD TBD"
        }
    }
}

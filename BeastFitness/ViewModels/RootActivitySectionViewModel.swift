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
    let headerRowViewModel: RootActivitySectionHeaderRowViewModel?
    let rows: [RootActivitySectionRowViewModel]
    let columnOrder: [ActivityColumnType] = [
        .count,
        .output,
        .time
    ]
    
    init(isPlaceholder: Bool = false, title: String, workouts: [SQWorkout]?) {
        self.isPlaceholder = isPlaceholder
        self.title = title
        
        let workoutsByType = workouts?.workoutsByActivityType ?? .init()
        
        var rows = [RootActivitySectionRowViewModel]()
        for (workoutType, workouts) in workoutsByType {
            rows.append(.init(columnTypes: columnOrder, workoutType: workoutType, workouts: .init(workouts: workouts)))
        }
        self.rows = rows
        self.headerRowViewModel = .init(columns: columnOrder.map { .init(columnType: $0) } )
    }
}

enum ActivityColumnType: String {
    case count
    case output
    case time
    
    var width: CGFloat {
        switch self {
        case .count, .output, .time:
            return 75
        }
    }
}

@Observable
class RootActivitySectionHeaderRowViewModel: Identifiable {
    let columns: [RootActivitySectionColumnHeaderViewModel]
    
    init(columns: [RootActivitySectionColumnHeaderViewModel]) {
        self.columns = columns
    }
}

@Observable
class RootActivitySectionRowViewModel: Identifiable {
    let id = UUID()
    let columns: [RootActivitySectionColumnViewModel]
    let workoutType: HKWorkoutActivityType?
    
    init(columnTypes: [ActivityColumnType], workoutType: HKWorkoutActivityType, workouts: SQWorkouts) {
        self.workoutType = workoutType
        var subRows = [RootActivitySectionColumnViewModel]()
        for columnType in columnTypes {
            subRows.append(.init(columnType: columnType, workouts: workouts))
        }
        self.columns = subRows
    }
}

@Observable
class RootActivitySectionColumnViewModel: Identifiable {
    let id = UUID()
    let title: String
    let columnType: ActivityColumnType
    
    init(columnType: ActivityColumnType, workouts: SQWorkouts) {
        self.columnType = columnType
        
        switch columnType {
        case .count:
            title = "\(workouts.workouts.count)"
        case .output:
            title = workouts.sumOutputString ?? ""
        case .time:
            title = workouts.timeString ?? ""
        }
    }
}

@Observable
class RootActivitySectionColumnHeaderViewModel: Identifiable {
    let id = UUID()
    let title: String
    let columnType: ActivityColumnType
    
    init(columnType: ActivityColumnType) {
        self.columnType = columnType
        self.title = columnType.rawValue.capitalized
    }
}

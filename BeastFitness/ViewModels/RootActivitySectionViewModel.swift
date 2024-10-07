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
    let columnOrder: [ActivityColumnStatType] = [
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
        self.headerRowViewModel = .init(columns: columnOrder.map { .init(statType: $0) } )
    }
}

enum ActivityColumnStatType: String {
    case count
    case output
    case time
    
    var width: CGFloat {
        switch self {
        case .count:
            return 50
        case .output:
            return 50
        case .time:
            return 50
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
    
    init(columnStatTypes: [ActivityColumnStatType], workoutType: HKWorkoutActivityType, workouts: [HKWorkout]) {
        self.workoutType = workoutType
        var subRows = [RootActivitySectionColumnViewModel]()
        for columnStatType in columnStatTypes {
            subRows.append(.init(statType: columnStatType, workouts: workouts))
        }
        for idx in [0, 1, 2, 3, 4, 5, 6, 7, 8 , 9, 10] {
            subRows.append(.init(statType: .output, workouts: workouts))
        }
        self.columns = subRows
    }
}

@Observable
class RootActivitySectionColumnViewModel: Identifiable {
    let id = UUID()
    let title: String
    let columnType: ActivityColumnStatType
    
    init(statType: ActivityColumnStatType, workouts: [HKWorkout]) {
        self.columnType = statType
        let activityType = workouts.first?.workoutActivityType ?? .other
        
        switch statType {
        case .count:
            title = "\(workouts.count)"
        case .output:
            title = "TBD"
        case .time:
            title = "TBD"
        }
    }
}

@Observable
class RootActivitySectionColumnHeaderViewModel: Identifiable {
    let id = UUID()
    let title: String
    let columnType: ActivityColumnStatType
    
    init(statType: ActivityColumnStatType) {
        self.columnType = statType
        self.title = statType.rawValue.capitalized
    }
}

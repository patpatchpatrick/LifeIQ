//
//  SQRootActivitySectionViewModel.swift
//  BeastFitness
//
//  Created by Patrick Doyle on 9/30/24.
//

import Foundation
import HealthKit

@Observable
class SQRootActivitySectionViewModel {
    let isPlaceholder: Bool
    let title: String
    let headerRowViewModel: SQRootActivitySectionHeaderRowViewModel?
    var rows: [SQRootActivitySectionRowViewModel]
    let columnOrder: [SQActivityColumnType] = [
        .count,
        .output,
        .time,
        .calories,
        .avgHeartRate
    ]
    
    init(isPlaceholder: Bool = false, title: String, workouts: [SQWorkoutSession]?) {
        self.isPlaceholder = isPlaceholder
        self.title = title
        
        let workoutsByType = workouts?.workoutsByActivityType ?? .init()
        
        var rows = [SQRootActivitySectionRowViewModel]()
        for (workoutType, workouts) in workoutsByType {
            rows.append(.init(columnTypes: columnOrder, workoutType: workoutType, workouts: .init(workouts: workouts)))
        }
        self.rows = rows
        self.headerRowViewModel = .init(columns: columnOrder.map { .init(columnType: $0) } )
    }
}

enum SQActivityColumnType: String {
    case count
    case output
    case time
    case calories
    case avgHeartRate
    
    var width: CGFloat {
        switch self {
        case .count:
            return 75
        case .output, .time, .calories, .avgHeartRate:
            return 110
        }
    }
    
    var title: String {
        switch self {
        case .count:
            "Count"
        case .output:
            "Output"
        case .time:
            "Time"
        case .calories:
            "Calories"
        case .avgHeartRate:
            "HR"
        }
    }
}

@Observable
class SQRootActivitySectionHeaderRowViewModel: Identifiable {
    let columns: [SQRootActivitySectionColumnHeaderViewModel]
    
    init(columns: [SQRootActivitySectionColumnHeaderViewModel]) {
        self.columns = columns
    }
}

@Observable
class SQRootActivitySectionRowViewModel: Identifiable, Hashable, Equatable {
    let id = UUID()
    let columns: [SQRootActivitySectionColumnViewModel]
    let workoutType: HKWorkoutActivityType?
    
    init(columnTypes: [SQActivityColumnType], workoutType: HKWorkoutActivityType, workouts: SQWorkouts) {
        self.workoutType = workoutType
        var subRows = [SQRootActivitySectionColumnViewModel]()
        for columnType in columnTypes {
            subRows.append(.init(columnType: columnType, workouts: workouts))
        }
        self.columns = subRows
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: SQRootActivitySectionRowViewModel, rhs: SQRootActivitySectionRowViewModel) -> Bool {
        lhs.id == rhs.id
    }
}

@Observable
class SQRootActivitySectionColumnViewModel: Identifiable {
    let id = UUID()
    let title: String
    let columnType: SQActivityColumnType
    
    init(columnType: SQActivityColumnType, workouts: SQWorkouts) {
        self.columnType = columnType
        
        switch columnType {
        case .count:
            title = "\(workouts.workouts.count)"
        case .output:
            title = ""
        case .time:
            title = ""
        case .calories:
            title = ""
        case .avgHeartRate:
            title = ""
        }
    }
}

@Observable
class SQRootActivitySectionColumnHeaderViewModel: Identifiable {
    let id = UUID()
    let title: String
    let columnType: SQActivityColumnType
    
    init(columnType: SQActivityColumnType) {
        self.columnType = columnType
        self.title = columnType.title
    }
}

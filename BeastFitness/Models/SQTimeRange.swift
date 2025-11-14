//
//  SQTimeRange.swift
//  BeastFitness
//
//  Created by Patrick Doyle on 10/14/24.
//

import Foundation

enum SQTimeRange: String {
    case pastWeek = "Past Week"
    case weekBeforeLast = "Week Before Last"
    case pastMonth = "Past Month"
    case pastYear = "Past Year"
    case allTime = "All Time"
    
    var title: String {
        self.rawValue
    }
    
    var startDate: Date {
        switch self {
        case .allTime:
            return Calendar.current.date(byAdding: .year, value: -20, to: endDate)!
        case .pastMonth:
            return Calendar.current.date(byAdding: .month, value: -11, to: endDate)!
        case .pastYear:
            return Calendar.current.date(byAdding: .year, value: -1, to: endDate)!
        case .weekBeforeLast:
            return Calendar.current.date(byAdding: .day, value: -14, to: endDate)!
        case .pastWeek:
            return Calendar.current.date(byAdding: .day, value: -7, to: endDate)!
        }
    }
    
    var endDate: Date {
        switch self {
        case .pastWeek, .pastMonth, .pastYear, .allTime:
                .now
        case .weekBeforeLast:
            SQTimeRange.pastWeek.startDate
        }
    }
}

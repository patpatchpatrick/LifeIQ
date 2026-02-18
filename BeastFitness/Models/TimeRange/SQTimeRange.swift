//
//  SQTimeRange.swift
//  BeastFitness
//
//  Created by Patrick Doyle on 10/14/24.
//

import Foundation

enum SQTimeRange: String {
    case today = "Today"
    case yesterday = "Yesterday"
    case pastWeek = "Past 7 Days"
    case weekBeforeLast = "Week Before Last"
    case past30Days = "Past 30 Days"
    case thirtyDaysBeforeLast = "30 Days Before Last"
    case pastYear = "Past Year"
    case yearBeforeLast = "Year Before Last"
    case allTime = "All Time"
    
    var title: String {
        self.rawValue
    }
    
    var startDate: Date {
        let calendar = Calendar.current
        let todayStart = calendar.startOfDay(for: Date())

        switch self {
        case .allTime:
            return calendar.date(byAdding: .year, value: -20, to: endDate)!
        case .past30Days:
            return calendar.date(byAdding: .day, value: -30, to: endDate)!
        case .thirtyDaysBeforeLast:
            return calendar.date(byAdding: .day, value: -60, to: endDate)!
        case .pastYear:
            return calendar.date(byAdding: .year, value: -1, to: endDate)!
        case .yearBeforeLast:
            return calendar.date(byAdding: .year, value: -2, to: endDate)!
        case .weekBeforeLast:
            return calendar.date(byAdding: .day, value: -14, to: endDate)!
        case .pastWeek:
            return calendar.date(byAdding: .day, value: -7, to: endDate)! // your existing hack
        case .today:
            return todayStart
        case .yesterday:
            return calendar.date(byAdding: .day, value: -1, to: todayStart)!
        }
    }
    
    var endDate: Date {
        switch self {
        case .pastWeek, .past30Days, .pastYear, .allTime, .today:
                .now
        case .weekBeforeLast:
            SQTimeRange.pastWeek.startDate
        case .yearBeforeLast:
            SQTimeRange.pastYear.startDate
        case .yesterday:
            SQTimeRange.today.startDate
        case .thirtyDaysBeforeLast:
            SQTimeRange.past30Days.startDate
        }
    }
}

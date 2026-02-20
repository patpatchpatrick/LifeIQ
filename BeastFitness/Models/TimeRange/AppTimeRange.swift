//
//  AppTimeRange.swift
//  BeastFitness
//
//  Created by Claude on 2/17/26.
//

import Foundation

enum AppTimeRange: String, CaseIterable {
    case today = "Today"
    case pastSevenDays = "Past 7 Days"
    case past30Days = "Past 30 Days"
    case pastYear = "Past Year"
    case allTime = "All Time"

    /// Maps to the underlying SQTimeRange for data queries
    var sqTimeRange: SQTimeRange {
        switch self {
        case .today: return .today
        case .pastSevenDays: return .pastWeek
        case .past30Days: return .past30Days
        case .pastYear: return .pastYear
        case .allTime: return .allTime
        }
    }

    /// Returns the comparison period for trend calculations (nil for allTime)
    var previousSqTimeRange: SQTimeRange? {
        switch self {
        case .today: return .yesterday
        case .pastSevenDays: return .weekBeforeLast
        case .past30Days: return .thirtyDaysBeforeLast
        case .pastYear: return .yearBeforeLast
        case .allTime: return nil
        }
    }


    /// Comparison time range used for the dashboard change-% column.
    /// For `.today`, compares against the last 7 days (not just yesterday).
    var dashboardChangePctTimeRange: SQTimeRange? {
        switch self {
        case .today:         return .pastWeek
        case .pastSevenDays: return .weekBeforeLast
        case .past30Days:    return .thirtyDaysBeforeLast
        case .pastYear:      return .yearBeforeLast
        case .allTime:       return nil
        }
    }

    /// Column header label for the change-% column in the metrics table.
    var dashboardChangePctHeader: String {
        switch self {
        case .today, .pastSevenDays: return "7d %"
        case .past30Days:            return "30d %"
        case .pastYear:              return "1y %"
        case .allTime:               return "—"
        }
    }

    /// Sort order for display in dropdowns (0 = first)
    var sortOrder: Int {
        switch self {
        case .today: return 0
        case .pastSevenDays: return 1
        case .past30Days: return 2
        case .pastYear: return 3
        case .allTime: return 4
        }
    }
}

//
//  Date+Extensions.swift
//  BeastFitness
//
//  Created by Patrick Doyle on 12/1/25.
//

import Foundation

extension Date {

    var firebaseDailyDateKey: String {
        SQDateFormatters.shared.string(from: self, style: .firebaseDayKey)
    }
    
    func formattedString(with style: SQDateFormatters.FormattedDateStyle) -> String {
        SQDateFormatters.shared.string(from: self, style: style)
    }
}

// MARK: - Day and Time Title

extension Date {
    
    func dayAndTimeTitle() -> String {
        let date = self
        let calendar = Calendar.current
            
        let hour = calendar.component(.hour, from: date)
        let weekday = weekdayName(from: date)
        let timeOfDay = timeOfDay(for: hour)
        
        return "\(weekday) \(timeOfDay.rawValue)"
    }
    
    enum TimeOfDay: String {
        case morning = "Morning"
        case afternoon = "Afternoon"
        case evening = "Evening"
        case night = "Night"
    }

    func timeOfDay(for hour: Int) -> TimeOfDay {
        switch hour {
        case 5..<12:
            return .morning
        case 12..<17:
            return .afternoon
        case 17..<21:
            return .evening
        default:
            return .night
        }
    }
    
    func weekdayName(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = .current
        formatter.dateFormat = "EEEE" // Full weekday name
        return formatter.string(from: date)
    }
}

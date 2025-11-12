//
//  TimeFormatter.swift
//  BeastFitness
//
//  Created by Patrick Doyle on 10/7/24.
//

import Foundation

final class SQDateFormatters {
    static let shared = SQDateFormatters()
    
    lazy var durationFormatter: DateComponentsFormatter = {
        let formatter = DateComponentsFormatter()
        formatter.unitsStyle = .abbreviated
        formatter.zeroFormattingBehavior = .dropAll
        formatter.allowedUnits = [.day, .hour, .minute, .second]
        return formatter
    }()
    
    lazy var iso8601Formatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.timeZone = .current
        return formatter
    }()
    
    lazy var dateShortFormatter: DateFormatter = {
        let df = DateFormatter()
        df.locale = Locale.current
        df.timeZone = .current
        df.timeStyle = .short
        df.dateStyle = .short // 1/28/23
        return df
    }()
}

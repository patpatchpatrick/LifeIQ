//
//  Date+Extensions.swift
//  BeastFitness
//
//  Created by Patrick Doyle on 12/1/25.
//

import Foundation

extension Date {

    var firebaseDailyDateKey: String {
        let dateKey = SQDateFormatters.shared.string(from: self, style: .firebaseDayKey)
        print("PTD Date Key", dateKey)
        return dateKey
    }
}

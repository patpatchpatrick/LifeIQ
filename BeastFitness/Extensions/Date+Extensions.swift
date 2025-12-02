//
//  Date+Extensions.swift
//  BeastFitness
//
//  Created by Patrick Doyle on 12/1/25.
//

import Foundation

extension Date {

    var firebaseKey: String {
        SQDateFormatters.shared.string(from: self, style: .firebaseDayKey)
    }
}

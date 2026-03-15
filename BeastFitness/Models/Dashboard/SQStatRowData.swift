//
//  SQStatRowData.swift
//  BeastFitness
//

import Foundation

struct SQStatRowData: Identifiable {
    let id: String
    let icon: String  // Emoji or SF Symbol name
    let title: String
    let avgValue: String
    let unit: String
    let sparklineData: [Double]
    let changePercent: Double?  // Fractional change; nil = no prior data to compare

    init(
        id: String,
        icon: String,
        title: String,
        avgValue: String,
        unit: String,
        sparklineData: [Double],
        changePercent: Double?
    ) {
        self.id = id
        self.icon = icon
        self.title = title
        self.avgValue = avgValue
        self.unit = unit
        self.sparklineData = sparklineData
        self.changePercent = changePercent
    }
}

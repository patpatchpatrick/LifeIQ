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
    let change14d: Double  // Percentage change

    init(
        id: String,
        icon: String,
        title: String,
        avgValue: String,
        unit: String,
        sparklineData: [Double],
        change14d: Double
    ) {
        self.id = id
        self.icon = icon
        self.title = title
        self.avgValue = avgValue
        self.unit = unit
        self.sparklineData = sparklineData
        self.change14d = change14d
    }
}

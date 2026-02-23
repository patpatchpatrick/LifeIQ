//
//  SQWorkoutSession+VisibleStats.swift
//  BeastFitness
//
//  Created by Patrick Doyle on 12/10/25.
//

import Foundation

struct SQWorkoutSessionVisibleStat: Identifiable, Hashable {
    let id = UUID()
    let icon: String
    let title: String
    let value: String

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

extension SQWorkoutSessionable {

    /// Basic time stats shown in the "Stats" section of the workout summary.
    /// Performance metrics (distance, pace, VO2 max) are loaded separately by the controller with percentile ranks.
    func visibleStats() async -> [SQWorkoutSessionVisibleStat]? {
        var stats = [SQWorkoutSessionVisibleStat]()

        if let activeDuration {
            stats.append(.init(icon: SQImageSymbol.clock.rawValue, title: "Active Time", value: activeDuration.readableTime()))
        }

        if let startDate, let endDate {
            stats.append(.init(icon: SQImageSymbol.clock.rawValue, title: "Time", value: endDate.timeIntervalSince(startDate).readableTime()))
        }

        return stats.isEmpty ? nil : stats
    }
}

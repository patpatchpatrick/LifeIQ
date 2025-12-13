//
//  SQWorkoutSession+VisibleStats.swift
//  BeastFitness
//
//  Created by Patrick Doyle on 12/10/25.
//

import Foundation

struct SQWorkoutSessionVisibleStat: Identifiable, Hashable {
    let id = UUID()
    let title: String
    let value: String
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

extension SQWorkoutSessionable {
    
    var visibleStats: [SQWorkoutSessionVisibleStat]? {
        
        var stats = [SQWorkoutSessionVisibleStat]()
        
        if let activeDuration {
            stats.append(.init(
                title: "Active Time",
                value: activeDuration.readableTime()))
        }
        
        if let startDate, let endDate {
            stats.append(.init(
                title: "Time",
                value: endDate.timeIntervalSince(startDate).readableTime()))
        }
        
        if let coreMetric {
            stats.append(.init(
                title: coreMetric.displayName,
                value: coreMetric.outputAndUnitString))
        }
        
        if let pace = getMetric(for: .sqPaceRunning) {
            stats.append(.init(
                title: pace.displayName,
                value: pace.outputAndUnitString))
        }
        
        return stats.isEmpty ? nil : stats
    }
}

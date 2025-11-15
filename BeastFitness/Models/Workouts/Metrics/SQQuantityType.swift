//
//  SQQuantityType.swift
//  BeastFitness
//
//  Created by Patrick Doyle on 11/14/25.
//

import HealthKit

enum SQQuantityType {
    case distanceWalkingRunning
    case distanceCycling
    case activeKilocaloriesBurned
    case heartRate
    
    var hkQuantityTypeIdentifier: HKQuantityTypeIdentifier? {
        switch self {
        case .distanceWalkingRunning:
            return .distanceWalkingRunning
        case .distanceCycling:
            return .distanceCycling
        case .activeKilocaloriesBurned:
            return .activeEnergyBurned
        case .heartRate:
            return .heartRate
        }
    }
    
    var unit: SQUnit? {
        switch self {
        case .activeKilocaloriesBurned:
            return .kilocalorie
        case .distanceWalkingRunning, .distanceCycling:
            return .mile
        case .heartRate:
            return .countPerMinute
        }
    }
}

// TODO: - Figure out the best place to put this
var SQSupportedQuantityTypes: [HKQuantityTypeIdentifier]  = [
    .distanceWalkingRunning,
    .distanceCycling,
    .activeEnergyBurned,
    .heartRate
]

//
//  SQQuantityType.swift
//  BeastFitness
//
//  Created by Patrick Doyle on 11/14/25.
//

import HealthKit

enum SQQuantityType {
    // Distance types
    case distanceWalkingRunning
    case distanceCycling
    case distanceSwimming
    case distanceRowing
    case distanceDownhillSnowSports
    case distanceCrossCountrySkiing

    // Stairs / elevation
    case flightsClimbed

    // Output / performance
    case activeKilocaloriesBurned

    // Health metrics
    case heartRate
}

extension SQQuantityType {
    var hkQuantityTypeIdentifier: HKQuantityTypeIdentifier? {
        switch self {
        case .distanceWalkingRunning:
            return .distanceWalkingRunning

        case .distanceCycling:
            return .distanceCycling

        case .distanceSwimming:
            return .distanceSwimming

        case .distanceRowing:
            return .distanceRowing

        case .distanceDownhillSnowSports:
            return .distanceDownhillSnowSports

        case .distanceCrossCountrySkiing:
            return .distanceCrossCountrySkiing

        case .flightsClimbed:
            return .flightsClimbed

        case .activeKilocaloriesBurned:
            return .activeEnergyBurned

        case .heartRate:
            return .heartRate
        }
    }

    var unit: SQUnit? {
        switch self {

        // Energy
        case .activeKilocaloriesBurned:
            return .kilocalorie

        // Distance (miles — matches most fitness apps)
        case .distanceWalkingRunning,
             .distanceCycling,
             .distanceSwimming:
            return .mile

        // Rowing is typically measured in meters
        case .distanceRowing:
            return .meter

        // Snow sports also commonly measured in meters
        case .distanceDownhillSnowSports:
            return .meter

        // XC skiing often miles or km; matching your convention → miles
        case .distanceCrossCountrySkiing:
            return .mile

        // Flights climbed
        case .flightsClimbed:
            return .count

        // Heart rate
        case .heartRate:
            return .countPerMinute
        }
    }
}


// TODO: - Figure out the best place to put this
var SQSupportedQuantityTypes: [HKQuantityTypeIdentifier] = [
    .distanceWalkingRunning,
    .distanceCycling,
    .distanceSwimming,
    .distanceRowing,
    .distanceDownhillSnowSports,
    .distanceCrossCountrySkiing,
    .flightsClimbed,
    .activeEnergyBurned,
    .heartRate
]

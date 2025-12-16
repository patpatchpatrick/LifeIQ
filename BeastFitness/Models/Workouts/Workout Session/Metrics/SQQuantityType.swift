//
//  SQQuantityType.swift
//  BeastFitness
//
//  Created by Patrick Doyle on 11/14/25.
//

import HealthKit

enum SQQuantityType: String, Codable, UnfrozenEnum {
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
    case sqPaceRunning
    case sqTotalVolumeLifted

    // Health metrics
    case heartRate
    case unknown
}

enum SQOutputCalculationType {
    case sum
    case average
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
            
        case .sqPaceRunning, .sqTotalVolumeLifted, .unknown:
            /// Custom quantity type
            return nil
            
        }
    }
    
    var outputCalculationType: SQOutputCalculationType {
        switch self {
        case .distanceWalkingRunning, .distanceCycling, .distanceSwimming, .distanceRowing, .distanceDownhillSnowSports, .distanceCrossCountrySkiing, .flightsClimbed, .activeKilocaloriesBurned, .sqTotalVolumeLifted, .unknown:
            return .sum
            
        case .sqPaceRunning, .heartRate:
            return .average
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
            
        case .sqPaceRunning:
            return .secondsPerMile
            
        case .sqTotalVolumeLifted:
            return .pound
            
        case .unknown:
            return .unknown
        }
    }
    
    var displayTitle: String {
            switch self {
            case .distanceWalkingRunning, .distanceCycling, .distanceSwimming, .distanceRowing, .distanceDownhillSnowSports, .distanceCrossCountrySkiing:
                return "Distance"
            case .flightsClimbed:
                return "Flights Climbed" // ← UI-friendly version
            case .activeKilocaloriesBurned:
                return "Calories"
            case .heartRate:
                return "Heart Rate"
            case .sqPaceRunning:
                return "Pace"
            case .sqTotalVolumeLifted:
                return "Volume"
            case .unknown:
                return "Unknown"
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

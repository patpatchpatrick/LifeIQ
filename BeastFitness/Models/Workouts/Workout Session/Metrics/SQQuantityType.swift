//
//  SQQuantityType.swift
//  BeastFitness
//
//  Created by Patrick Doyle on 11/14/25.
//

import HealthKit

enum SQDistance: String, Codable, Hashable {
    case mile
    case kilometer = "1k"
    case fiveK = "5k"
    case tenK = "10k"
    case halfMarathon
    case marathon

    var meters: Double {
        switch self {
        case .mile:
            return 1609.344
        case .kilometer:
            return 1000
        case .fiveK:
            return 5000
        case .tenK:
            return 10000
        case .halfMarathon:
            return 21097.5
        case .marathon:
            return 42195
        }
    }

    var miles: Double {
        meters / 1609.344
    }
}

enum SQQuantityType: Codable, Hashable {
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

    // Parameterized performance metrics
    case sqFastestPace(SQDistance)

    // Health metrics
    case heartRate
    case unknown
}

enum SQOutputCalculationType: Codable, Hashable {
    case sum
    case average
    case fastestPace(SQDistance)
}

enum SQDashboardAggregationType {
    case minimum  // For pace - fastest is best
    case maximum  // For anything where highest is best
    case sum      // For distance, calories, etc.
    case average  // For heart rate, etc.
}

extension SQQuantityType {
    var id: String {
        switch self {
        case .distanceWalkingRunning:
            return "distanceWalkingRunning"
        case .distanceCycling:
            return "distanceCycling"
        case .distanceSwimming:
            return "distanceSwimming"
        case .distanceRowing:
            return "distanceRowing"
        case .distanceDownhillSnowSports:
            return "distanceDownhillSnowSports"
        case .distanceCrossCountrySkiing:
            return "distanceCrossCountrySkiing"
        case .flightsClimbed:
            return "flightsClimbed"
        case .activeKilocaloriesBurned:
            return "activeKilocaloriesBurned"
        case .sqPaceRunning:
            return "sqPaceRunning"
        case .sqFastestPace(let distance):
            return "sqFastestPace-\(distance.rawValue)"
        case .sqTotalVolumeLifted:
            return "sqTotalVolumeLifted"
        case .heartRate:
            return "heartRate"
        case .unknown:
            return "unknown"
        }
    }

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
            
        case .sqFastestPace:
            /// Custom quantity type
            return nil
            
        case .sqPaceRunning, .sqTotalVolumeLifted, .unknown:
            /// Custom quantity type
            return nil
            
        }
    }
    
    var outputCalculationType: SQOutputCalculationType {
        switch self {
        case .sqFastestPace(let distance):
            return .fastestPace(distance)

        case .distanceWalkingRunning, .distanceCycling, .distanceSwimming, .distanceRowing, .distanceDownhillSnowSports, .distanceCrossCountrySkiing, .flightsClimbed, .activeKilocaloriesBurned, .sqTotalVolumeLifted, .unknown:
            return .sum

        case .sqPaceRunning, .heartRate:
            return .average
        }
    }

    var dashboardAggregationType: SQDashboardAggregationType {
        switch self {
        case .sqPaceRunning, .sqFastestPace:
            return .minimum  // Fastest pace (lower is better)

        case .distanceWalkingRunning, .distanceCycling, .distanceSwimming, .distanceRowing, .distanceDownhillSnowSports, .distanceCrossCountrySkiing:
            return .maximum  // Longest single workout distance

        case .flightsClimbed, .activeKilocaloriesBurned, .sqTotalVolumeLifted:
            return .sum  // Total across all workouts

        case .heartRate:
            return .average  // Average heart rate

        case .unknown:
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

        case .sqPaceRunning, .sqFastestPace:
            return .secondsPerMile

        case .sqTotalVolumeLifted:
            return .pound

        case .unknown:
            return .unknown
        }
    }

    var preferredDisplayUnit: SQUnit? {
        preferredDisplayUnit(for: SQUserDefaults.shared.preferredUnitSystem ?? .defaultForCurrentLocale)
    }

    func preferredDisplayUnit(for unitSystem: SQUnitSystem) -> SQUnit? {
        switch self {
        case .distanceWalkingRunning,
             .distanceCycling,
             .distanceSwimming,
             .distanceCrossCountrySkiing:
            return unitSystem == .metric ? .kilometer : .mile

        case .sqPaceRunning, .sqFastestPace:
            return unitSystem == .metric ? .secondsPerKilometer : .secondsPerMile

        case .sqTotalVolumeLifted:
            return unitSystem == .metric ? .kilogram : .pound

        case .distanceRowing,
             .distanceDownhillSnowSports,
             .flightsClimbed,
             .activeKilocaloriesBurned,
             .heartRate,
             .unknown:
            return unit
        }
    }
    
    /// Whether computed results for this metric should be cached in memory.
    ///
    /// Pace metrics are expensive to compute — they require fetching GPS route data
    /// from HealthKit and running a sliding-window algorithm over potentially thousands
    /// of coordinate samples. Caching ensures the work is only done once per workout
    /// per app session rather than on every dashboard or leaderboard reload.
    var shouldCache: Bool {
        switch self {
        case .sqPaceRunning, .sqFastestPace:
            return true
        case .distanceWalkingRunning, .distanceCycling, .distanceSwimming, .distanceRowing,
             .distanceDownhillSnowSports, .distanceCrossCountrySkiing, .flightsClimbed,
             .activeKilocaloriesBurned, .sqTotalVolumeLifted, .heartRate, .unknown:
            return false
        }
    }

    var displayTitle: String {
            switch self {
            case .distanceWalkingRunning, .distanceCycling, .distanceSwimming, .distanceRowing, .distanceDownhillSnowSports, .distanceCrossCountrySkiing:
                return "Distance"
            case .flightsClimbed:
                return "Flights Climbed"
            case .activeKilocaloriesBurned:
                return "Calories"
            case .heartRate:
                return "Heart Rate"
            case .sqPaceRunning:
                return "Pace"
            case .sqFastestPace(let distance):
                return "Fastest \(distance.rawValue.capitalized)"
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

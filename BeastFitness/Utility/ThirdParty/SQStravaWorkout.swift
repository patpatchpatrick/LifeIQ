//
//  SQStravaWorkout.swift
//  BeastFitness
//
//  Created by Patrick Doyle on 10/9/24.
//

import Foundation
import HealthKit

struct SQStravaWorkout: Codable {
    let id: Double?
    let sport_type: SQStravaSportType
    let elapsed_time: Double? // seconds
    let moving_time: Double?
    let average_heartrate: Double?
    let max_heartrate: Double?
    let start_date_local: String?
    let start_date: String?
    let average_speed: Double? // m/s
    let max_speed: Double?
    let total_elevation_gain: Double?
    let elev_high: Double?
    let distance: Double? // meters
    let map: SQStravaMap?
    
    func sumOutputFor(_ quantityTypeIdentifier: SQQuantityType) -> Double? {
        guard let unit = quantityTypeIdentifier.unit else {
            SQLogger.shared.log("Missing unit for strava workout sum output", .error)
            return nil }
        switch quantityTypeIdentifier {
        case .distanceWalkingRunning, .distanceCycling:
            return SQUnit.convert(distance, from: .meter, to: unit)
        case .activeEnergyBurned:
            return nil
        case .heartRate:
            return nil
        }
    }
    
    func avgOutputFor(_ quantityTypeIdentifier: SQQuantityType) -> Double? {
        guard let unit = quantityTypeIdentifier.unit else {
            SQLogger.shared.log("Missing unit for strava workout avg output", .error)
            return nil }
        switch quantityTypeIdentifier {
        case .heartRate:
            return SQUnit.convert(average_heartrate, from: .countPerMinute, to: unit)
        case .distanceCycling, .distanceWalkingRunning, .activeEnergyBurned:
            return nil
        }
    }
    
    var activeDuration: Double? {
        moving_time
    }
}

/// https://developers.strava.com/docs/reference/#api-models-SportType
enum SQStravaSportType: String, Codable {
    case run = "Run"
    case virtualRun = "VirtualRun"
    case weightTraining = "WeightTraining"
    case pickleball = "Pickleball"
    case ride = "Ride"
    case alpineSki = "AlpineSki"
    case hike = "Hike"
    case snowboard = "Snowboard"
    case virtualRide = "VirtualRide"
    case walk = "Walk"
    case workout = "Workout"
    case yoga = "Yoga"
    case trailRun = "TrailRun"
    
    var activityType: HKWorkoutActivityType {
        switch self {
        case .run, .virtualRun, .trailRun:
                .running
        case .weightTraining:
                .traditionalStrengthTraining
        case .pickleball:
                .pickleball
        case .ride, .virtualRide:
                .cycling
        case .alpineSki:
                .downhillSkiing
        case .hike:
                .hiking
        case .snowboard:
                .snowboarding
        case .walk:
                .walking
        case .workout:
                .functionalStrengthTraining
        case .yoga:
                .yoga
        }
    }
}

struct SQStravaMap: Codable {
    let id: String?
    let summary_polyline: String?
}

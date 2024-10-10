//
//  SQStravaActivity.swift
//  BeastFitness
//
//  Created by Patrick Doyle on 10/9/24.
//

import Foundation
import HealthKit

struct SQStravaActivity: Decodable {
    let id: Double?
    let sport_type: SQStravaSportType
    let elapsed_time: Double? // seconds
    let moving_time: Double?
    let average_heartrate: Double?
    let max_heartrate: Double?
    let start_date_local: Date?
    let start_date: Date?
    let average_speed: Double? // m/s
    let max_speed: Double?
    let total_elevation_gain: Double?
    let elev_high: Double?
    let distance: Double? // meters
    let map: SQStravaMap?
}

/// https://developers.strava.com/docs/reference/#api-models-SportType
enum SQStravaSportType: String, Decodable {
    case run = "Run"
    case weightTraining = "WeightTraining"
    case pickleball = "Pickleball"
    case ride = "Ride"
    
    var activityType: HKWorkoutActivityType {
        switch self {
        case .run:
                .running
        case .weightTraining:
                .traditionalStrengthTraining
        case .pickleball:
                .pickleball
        case .ride:
                .cycling
        }
    }
}

struct SQStravaMap: Decodable {
    let id: String?
    let summary_polyline: String?
}

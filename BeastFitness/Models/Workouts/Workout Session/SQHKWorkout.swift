//
//  SQHKWorkout.swift
//  BeastFitness
//
//  Created by Patrick Doyle on 10/14/24.
//

import Foundation
import HealthKit

struct SQHKWorkout: SQWorkoutSourcable {
    let sourceId: String
    let hkWorkout: HKWorkout
    
    init(hkWorkout: HKWorkout) {
        self.sourceId = hkWorkout.uuid.uuidString
        self.hkWorkout = hkWorkout
    }
    
    var activityType: HKWorkoutActivityType {
        hkWorkout.workoutActivityType
    }
    
    func sumOutputFor(_ quantityTypeIdentifier: SQQuantityType) -> Double? {

        switch quantityTypeIdentifier {
        case .sqPaceRunning, .sqFastestPace, .sqTotalVolumeLifted, .unknown:
            return nil

        case .distanceWalkingRunning, .distanceCycling, .distanceSwimming, .distanceRowing, .distanceDownhillSnowSports, .distanceCrossCountrySkiing, .flightsClimbed, .activeKilocaloriesBurned, .heartRate:
            /// Continue below since these are all supported in HealhKit
            break
        }

        return hkWorkout.sumOutputFor(quantityTypeIdentifier)
    }
    
    func avgOutputFor(_ quantityTypeIdentifier: SQQuantityType) -> Double? {

        switch quantityTypeIdentifier {

        case .unknown:
            return nil

        case .sqPaceRunning, .sqTotalVolumeLifted:

            guard  let totalDistance = sumOutputFor(.distanceWalkingRunning), let activeDuration else { return nil }
            return activeDuration / totalDistance

        case .sqFastestPace:
            return nil

        case .distanceWalkingRunning, .distanceCycling, .distanceSwimming, .distanceRowing, .distanceDownhillSnowSports, .distanceCrossCountrySkiing, .flightsClimbed, .activeKilocaloriesBurned, .heartRate:
            /// Continue below since these are all supported in HealhKit
            break
        }

        return hkWorkout.avgOutputFor(quantityTypeIdentifier)
    }

    func fastestPaceFor(_ distance: SQDistance) -> Double? {
        // 1. Get the appropriate distance type for this activity
        guard let distanceType = hkWorkout.workoutActivityType.standardDistanceType else {
            return nil  // Activity doesn't track distance (e.g., strength training)
        }

        // 2. Get the unit used by this distance type
        guard let unit = distanceType.unit else {
            return nil  // No unit defined for this distance type
        }

        // 3. Get total workout distance in the activity's native unit
        guard let totalDistance = sumOutputFor(distanceType) else {
            return nil  // No distance data available
        }

        // 4. Convert requested distance from meters to the activity's unit
        let requestedDistance = SQUnit.convert(distance.meters, from: .meter, to: unit) ?? 0

        // 5. Check if workout is long enough
        guard totalDistance >= requestedDistance else {
            return nil  // Workout too short (e.g., 0.5 mi run can't have fastest mile)
        }

        // TODO: - PTD Implement route-based pace calculation
        // 6. Query HKWorkoutRoute for location samples
        // 7. Calculate rolling windows of target distance
        // 8. Return fastest (minimum) pace in seconds per distance unit
        //
        // This requires:
        // - Querying HKWorkoutRoute asynchronously
        // - Processing location samples into distance/time segments
        // - Finding the fastest rolling window
        //
        // For now, return nil until route query is implemented
        return nil
    }

    var activeDuration: Double? {
        workoutActiveDuration(from: hkWorkout)
    }
    
    var startDate: Date? {
        hkWorkout.startDate
    }
    
    var endDate: Date? {
        hkWorkout.endDate
    }
    
    var device: SQWorkoutDevice? {
        guard let device = hkWorkout.device else { return nil }
        return .init(name: device.friendlyDescription)
    }

    // TODO: - Pass workout details for existing HK workouts if they exist
    var details: SQWorkoutActivityDetails? {
        nil
    }
    
    func workoutActiveDuration(from workout: HKWorkout) -> TimeInterval? {
        // If there are no events, fall back to total duration
        guard let events = workout.workoutEvents, !events.isEmpty else {
            return workout.duration
        }

        var activeTime: TimeInterval = 0
        var lastStart = workout.startDate

        for event in events {
            switch event.type {
            case .pause:
                // Add time from lastStart to this pause
                activeTime += event.dateInterval.start.timeIntervalSince(lastStart)
            case .resume:
                // Resume timer from this point
                lastStart = event.dateInterval.start
            default:
                break
            }
        }

        // Add any remaining time from lastStart to endDate
        activeTime += workout.endDate.timeIntervalSince(lastStart)

        if activeTime > 0 { return activeTime}
        
        return workout.duration
    }
}

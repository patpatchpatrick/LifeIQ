//
//  SQHKWorkout.swift
//  BeastFitness
//
//  Created by Patrick Doyle on 10/14/24.
//

import Foundation
import HealthKit
import CoreLocation
import BeastFitnessCore

enum PaceCalculationMethod: String, Codable {
    case gpsRoute = "GPS route"
    case distanceSamples = "distance samples"
    case averagePace = "average pace"

    var warningText: String? {
        switch self {
        case .gpsRoute:
            return nil // Most accurate, no warning needed
        case .distanceSamples:
            return "GPS route data was not available for this workout. This pace was calculated from distance samples instead and may be less accurate than GPS-based calculations."
        case .averagePace:
            return "GPS route data was not available for this workout. This is the average pace for the entire workout, not the fastest mile pace."
        }
    }
}

struct SQHKWorkout: SQWorkoutSourcable {
    let sourceId: String
    let hkWorkout: HKWorkout

    /// Enable verbose logging for pace calculations (useful for debugging)
    static var isVerbosePaceLoggingEnabled: Bool = false

    init(hkWorkout: HKWorkout) {
        let syncIdentifier = hkWorkout.metadata?[HKMetadataKeySyncIdentifier] as? String
        self.sourceId = syncIdentifier ?? hkWorkout.uuid.uuidString
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
            guard let totalDistance = sumOutputFor(.distanceWalkingRunning), let activeDuration else { return nil }
            return activeDuration / totalDistance

        case .sqFastestPace:
            return nil

        case .distanceWalkingRunning, .distanceCycling, .distanceSwimming, .distanceRowing, .distanceDownhillSnowSports, .distanceCrossCountrySkiing, .flightsClimbed, .activeKilocaloriesBurned, .heartRate:
            /// Continue below since these are all supported in HealhKit
            break
        }

        return hkWorkout.avgOutputFor(quantityTypeIdentifier)
    }

    func fastestPaceFor(_ distance: SQDistance) async -> (pace: Double, calculationMethod: PaceCalculationMethod)? {
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

        // 6) Three-tier approach to compute fastest time (seconds) over that distance
        let calc = WorkoutFastestSplitCalculator(workout: hkWorkout)
        var fastestSeconds: Double?
        var calculationMethod: PaceCalculationMethod?

        // Tier 1: Try GPS route (most accurate)
        fastestSeconds = await calc.fastestTimeSeconds(
            targetMeters: distance.meters,
            timeBasis: .moving,
            accuracyCutoff: 50
        )

        if fastestSeconds != nil {
            calculationMethod = .gpsRoute
        } else {
            if Self.isVerbosePaceLoggingEnabled {
                SQLogger.shared.log(
                    "No GPS route for workout \(hkWorkout.uuid) \(hkWorkout.startDate.formattedString(with: .medium)), trying distance samples...",
                    .debug,
                    context: .healthKit
                )
            }

            // Tier 2: Try distance samples (good approximation)
            fastestSeconds = await calc.fastestTimeSecondsFromDistanceSamples(
                targetMeters: distance.meters,
                distanceType: distanceType
            )

            if fastestSeconds != nil {
                calculationMethod = .distanceSamples
            } else {
                if Self.isVerbosePaceLoggingEnabled {
                    SQLogger.shared.log(
                        "No distance samples for workout \(hkWorkout.uuid), falling back to average pace...",
                        .debug,
                        context: .healthKit
                    )
                }

                // Tier 3: Fall back to average pace (last resort)
                fastestSeconds = averagePaceSeconds(
                    targetDistance: distance.meters,
                    totalDistance: totalDistance,
                    unit: unit,
                    distanceType: distanceType
                )

                if fastestSeconds != nil {
                    calculationMethod = .averagePace
                }
            }
        }

        guard let fastestSeconds = fastestSeconds,
              let calculationMethod = calculationMethod else {
            if Self.isVerbosePaceLoggingEnabled {
                SQLogger.shared.log(
                    "❌ All calculation methods failed for workout \(hkWorkout.uuid)",
                    .error,
                    context: .healthKit
                )
            }
            return nil
        }

        if Self.isVerbosePaceLoggingEnabled {
            SQLogger.shared.log(
                "✅ Calculated fastest mile using: \(calculationMethod.rawValue) for workout \(hkWorkout.startDate.formattedString(with: .medium))",
                .debug,
                context: .healthKit
            )
        }

        guard fastestSeconds > 0 else {
            if Self.isVerbosePaceLoggingEnabled {
                SQLogger.shared.log(
                    "Invalid fastestSeconds (\(fastestSeconds)) for workout \(hkWorkout.uuid)",
                    .error,
                    context: .healthKit
                )
            }
            return nil
        }

        // 7) Convert to pace per mile (seconds per mile)
        // - distance.miles is the distance covered in miles
        // - fastestSeconds is the time it took
        // - Pace = time / distance in miles
        guard distance.miles > 0 else {
            if Self.isVerbosePaceLoggingEnabled {
                SQLogger.shared.log(
                    "Invalid distance.miles (\(distance.miles)) for distance \(distance)",
                    .error,
                    context: .healthKit
                )
            }
            return nil
        }

        let pacePerMile = fastestSeconds / distance.miles

        // Validate the result is reasonable based on activity type
        let paceRange = reasonablePaceRange(for: hkWorkout.workoutActivityType)
        guard pacePerMile >= paceRange.min && pacePerMile <= paceRange.max else {
            if Self.isVerbosePaceLoggingEnabled {
                SQLogger.shared.log(
                    "Unreasonable pace (\(pacePerMile) sec/mile = \(pacePerMile.timeCode())) for \(hkWorkout.workoutActivityType.name) workout \(hkWorkout.uuid). Expected range: \(paceRange.min.timeCode())-\(paceRange.max.timeCode()). FastestSeconds: \(fastestSeconds), distance.miles: \(distance.miles)",
                    .error,
                    context: .healthKit
                )
            }
            return nil
        }

        if Self.isVerbosePaceLoggingEnabled {
            SQLogger.shared.log(
                "Calculated pace: \(pacePerMile.timeCode()) per mile for \(hkWorkout.workoutActivityType.name) workout \(hkWorkout.uuid) calculation method: \(calculationMethod.rawValue)",
                .debug,
                context: .healthKit
            )
        }

        return (pace: pacePerMile, calculationMethod: calculationMethod)
    }

    /// Tier 3 fallback: Calculate average pace over target distance
    /// This is used when neither GPS route nor distance samples are available
    private func averagePaceSeconds(
        targetDistance: Double,
        totalDistance: Double,
        unit: SQUnit,
        distanceType: SQQuantityType
    ) -> Double? {
        // Get total workout duration
        guard let duration = hkWorkout.duration, duration > 0 else {
            return nil
        }

        // Convert total distance to meters
        let totalDistanceMeters = SQUnit.convert(totalDistance, from: unit, to: .meter) ?? 0
        guard totalDistanceMeters > 0 else {
            return nil
        }

        // Calculate average pace (seconds per meter)
        let avgPaceSecondsPerMeter = duration / totalDistanceMeters

        // Calculate time for target distance
        let secondsForTargetDistance = avgPaceSecondsPerMeter * targetDistance

        return secondsForTargetDistance
    }

    /// Returns reasonable pace range (in seconds per mile) for a given activity type
    /// These ranges are extremely lenient to avoid filtering out any legitimate data
    private func reasonablePaceRange(for activityType: HKWorkoutActivityType) -> (min: Double, max: Double) {
        switch activityType {
        case .running:
            // 2 min/mile (30 mph sprint) to 10 hours/mile (0.1 mph crawl)
            return (180, 500000)
            
        case .walking, .hiking:
            // 2 min/mile (30 mph sprint) to 10 hours/mile (0.1 mph crawl)
            return (1, 500000)

        case .cycling, .handCycling:
            // 18 sec/mile (200 mph) to 10 hours/mile (0.1 mph uphill/stopped)
            return (1, 500000)

        case .swimming:
            // 5 min/mile (12 mph) to 10 hours/mile (0.1 mph)
            return (1, 500000)

        case .rowing:
            // 1 min/mile (60 mph) to 10 hours/mile (0.1 mph)
            return (1, 500000)

        case .crossCountrySkiing:
            // 1 min/mile (60 mph) to 10 hours/mile (0.1 mph)
            return (1, 500000)

        case .downhillSkiing, .snowboarding:
            // 10 sec/mile (360 mph) to 10 hours/mile (0.1 mph)
            return (1, 500000)

        default:
            // Generic fallback: catch only obviously corrupt data
            return (1, 500000)
        }
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
    
    func workoutActiveDuration(from workout: HKWorkout) -> TimeInterval {
        // Use a non-optional for calculations
        let totalDuration: TimeInterval = workout.duration ?? 0

        // Optional only for logging if you want the nil behavior
        let totalDurationForLog: TimeInterval? = workout.duration   // change this if your "nil" total comes from elsewhere

        guard var events = workout.workoutEvents, !events.isEmpty else {
            SQLogger.shared.log(
                "⚠️ No workout events found - using total duration: \(totalDurationForLog?.timeCode() ?? "nil")",
                .debug,
                context: .healthKit
            )
            return totalDuration
        }

        events.sort { $0.dateInterval.start < $1.dateInterval.start }

        let pauseCount = events.filter { $0.type == .pause }.count
        let resumeCount = events.filter { $0.type == .resume }.count
        let motionPausedCount = events.filter { $0.type == .motionPaused }.count
        let motionResumedCount = events.filter { $0.type == .motionResumed }.count

        SQLogger.shared.log(
            "📊 Workout events: manual pause/resume: \(pauseCount)/\(resumeCount), motion pause/resume: \(motionPausedCount)/\(motionResumedCount)",
            .debug,
            context: .healthKit
        )

        var activeTime: TimeInterval = 0
        var lastStart = workout.startDate

        var isPaused = false
        var pauseStart: Date? = nil
        var totalPausedTime: TimeInterval = 0

        for event in events {
            let t = event.dateInterval.start

            switch event.type {
            case .pause, .motionPaused:
                // Ignore redundant pauses
                guard !isPaused else { break }

                let seg = t.timeIntervalSince(lastStart)
                if seg > 0 { activeTime += seg }

                isPaused = true
                pauseStart = t

            case .resume, .motionResumed:
                // Ignore redundant resumes
                guard isPaused else { break }

                if let ps = pauseStart {
                    let pausedSeg = t.timeIntervalSince(ps)
                    if pausedSeg > 0 { totalPausedTime += pausedSeg }
                }

                lastStart = t
                isPaused = false
                pauseStart = nil

            default:
                break
            }
        }

        // Only add tail if we ended unpaused
        if !isPaused {
            let tail = workout.endDate.timeIntervalSince(lastStart)
            if tail > 0 { activeTime += tail }
        }

        SQLogger.shared.log(
            "⏱️ Duration calc: Total: \(totalDurationForLog?.timeCode() ?? "nil"), Active: \(activeTime.timeCode()), Paused: \(totalPausedTime.timeCode()), EndedPaused: \(isPaused)",
            .debug,
            context: .healthKit,
            isPriority: true
        )

        // Fallback sanity checks
        if activeTime <= 0 { return totalDuration }

        // Don’t let active exceed total by more than a small tolerance (clock jitter)
        if activeTime > totalDuration + 5 {
            return totalDuration
        }

        return activeTime
    }


}

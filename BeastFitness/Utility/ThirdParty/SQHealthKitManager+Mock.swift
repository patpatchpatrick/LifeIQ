//
//  SQHealthKitManager+Mock.swift
//  BeastFitness
//
//  Created by OpenAI Codex on 4/21/26.
//

import Foundation
import HealthKit
import CoreLocation

extension SQHealthKitManager {
    var shouldUseMockHealthData: Bool {
        SQBuildOverrides.useMockHealthData
    }

    var mockHealthData: SQMockHealthData {
        .shared
    }
}

final class SQMockHealthData {
    static let shared = SQMockHealthData(referenceDate: .now)

    struct WorkoutRecord {
        let sourceId: String
        let title: String
        let hkWorkout: HKWorkout
        let averageHeartRate: Double
        let weatherTemperatureCelsius: Double?
        let routeLocations: [CLLocation]
        let heartRateIntervals: [SQHeartRateIntervalSummary]

        var hkWorkoutId: String {
            hkWorkout.uuid.uuidString
        }

        func makeSession() -> SQWorkoutSession {
            SQWorkoutSession(
                id: sourceId,
                title: title,
                hkWorkoutId: hkWorkoutId,
                workoutSource: .hkWorkout(.init(hkWorkout: hkWorkout)),
                device: SQWorkoutDevice(name: hkWorkout.device?.name ?? "Mock Apple Watch"),
                activityType: hkWorkout.workoutActivityType,
                activeDuration: hkWorkout.duration,
                startDate: hkWorkout.startDate,
                endDate: hkWorkout.endDate,
                totalCalories: hkWorkout.totalEnergyBurned?.doubleValue(for: .kilocalorie()),
                averageHeartRate: averageHeartRate,
                details: nil,
                updateMetadata: nil
            )
        }
    }

    private let calendar = Calendar.current
    private let workoutRecords: [WorkoutRecord]
    private let sleepSegmentsStore: [SQSleepStageSegment]
    private let dailyHeartRateStore: [SQHeartRateDailySummary]
    private let dailyRestingHeartRateStore: [SQHeartRateDailySummary]
    private let vo2MaxStore: [SQVO2MaxSample]

    private init(referenceDate: Date) {
        workoutRecords = Self.buildWorkoutRecords(referenceDate: referenceDate)
        sleepSegmentsStore = Self.buildSleepSegments(referenceDate: referenceDate)
        dailyHeartRateStore = Self.buildDailyHeartSummaries(referenceDate: referenceDate, isResting: false)
        dailyRestingHeartRateStore = Self.buildDailyHeartSummaries(referenceDate: referenceDate, isResting: true)
        vo2MaxStore = Self.buildVO2MaxSamples(referenceDate: referenceDate)
    }

    func workouts(for timeRange: SQTimeRange) -> [HKWorkout] {
        workoutRecords
            .filter {
                $0.hkWorkout.endDate >= timeRange.startDate &&
                $0.hkWorkout.startDate <= timeRange.endDate
            }
            .map(\.hkWorkout)
            .sorted { $0.startDate > $1.startDate }
    }

    func workoutSessions(for timeRange: SQTimeRange) -> [SQWorkoutSessionable] {
        workoutRecords
            .filter {
                $0.hkWorkout.endDate >= timeRange.startDate &&
                $0.hkWorkout.startDate <= timeRange.endDate
            }
            .map { $0.makeSession() }
            .sorted { ($0.startDate ?? .distantPast) > ($1.startDate ?? .distantPast) }
    }

    func workoutSession(withHkWorkoutId healthKitId: String?) -> SQWorkoutSessionable? {
        guard let healthKitId else { return nil }
        return workoutRecords.first(where: { $0.hkWorkoutId == healthKitId })?.makeSession()
    }

    func workoutSession(sourceId: String) -> SQWorkoutSessionable? {
        workoutRecords.first(where: { $0.sourceId == sourceId })?.makeSession()
    }

    func routeLocations(for healthKitId: String) -> [CLLocation] {
        workoutRecords.first(where: { $0.hkWorkoutId == healthKitId })?.routeLocations ?? []
    }

    func workoutHeartRateIntervals(for healthKitId: String) -> [SQHeartRateIntervalSummary] {
        workoutRecords.first(where: { $0.hkWorkoutId == healthKitId })?.heartRateIntervals ?? []
    }

    func weatherTemperatureCelsius(for healthKitId: String) -> Double? {
        workoutRecords.first(where: { $0.hkWorkoutId == healthKitId })?.weatherTemperatureCelsius
    }

    func sleepSegments(from startDate: Date, to endDate: Date) -> [SQSleepStageSegment] {
        sleepSegmentsStore.filter { segment in
            segment.endDate > startDate && segment.startDate < endDate
        }
    }

    func dailyHeartRateSummaries(for timeRange: SQTimeRange) -> [SQHeartRateDailySummary] {
        filterDailySummaries(dailyHeartRateStore, for: timeRange)
    }

    func dailyRestingHeartRateSummaries(for timeRange: SQTimeRange) -> [SQHeartRateDailySummary] {
        filterDailySummaries(dailyRestingHeartRateStore, for: timeRange)
    }

    func latestVO2Max() -> SQVO2MaxSample? {
        vo2MaxStore.max(by: { $0.endDate < $1.endDate })
    }

    func vo2MaxSamples(for timeRange: SQTimeRange) -> [SQVO2MaxSample] {
        vo2MaxStore
            .filter { $0.endDate >= timeRange.startDate && $0.endDate <= timeRange.endDate }
            .sorted { $0.startDate < $1.startDate }
    }

    func vo2MaxSamples(upTo date: Date, limit: Int) -> [SQVO2MaxSample] {
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: date)) ?? date
        return vo2MaxStore
            .filter { $0.endDate < endOfDay }
            .sorted { $0.endDate > $1.endDate }
            .prefix(limit)
            .map { $0 }
    }

    func latestVO2MaxSample(strictlyBefore date: Date) -> SQVO2MaxSample? {
        vo2MaxStore
            .filter { $0.endDate < date }
            .max(by: { $0.endDate < $1.endDate })
    }

    func latestVO2MaxSample(onOrAfter date: Date, throughEndOfDay endOfDay: Date) -> SQVO2MaxSample? {
        let endBoundary = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: endOfDay)) ?? endOfDay
        return vo2MaxStore
            .filter { $0.startDate >= date && $0.startDate < endBoundary }
            .max(by: { $0.startDate < $1.startDate })
    }

    private func filterDailySummaries(
        _ summaries: [SQHeartRateDailySummary],
        for timeRange: SQTimeRange
    ) -> [SQHeartRateDailySummary] {
        summaries
            .filter { $0.date >= timeRange.startDate && $0.date <= timeRange.endDate }
            .sorted { $0.date < $1.date }
    }

    private static func buildWorkoutRecords(referenceDate: Date) -> [WorkoutRecord] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: referenceDate)

        return [
            buildWorkoutRecord(
                sourceId: "mock-workout-run-today",
                title: "Morning Run",
                activityType: .running,
                startDate: calendar.date(byAdding: .minute, value: 390, to: today) ?? referenceDate,
                durationMinutes: 44,
                distanceMeters: 8_050,
                calories: 620,
                averageHeartRate: 151,
                weatherTemperatureCelsius: 18,
                coordinateStart: CLLocationCoordinate2D(latitude: 33.4484, longitude: -112.0740),
                coordinateDelta: (0.018, 0.021)
            ),
            buildWorkoutRecord(
                sourceId: "mock-workout-ride-recent",
                title: "Tempo Ride",
                activityType: .cycling,
                startDate: calendar.date(byAdding: .day, value: -2, to: today)?.addingTimeInterval(60 * 60 * 7.5) ?? referenceDate,
                durationMinutes: 72,
                distanceMeters: 31_400,
                calories: 860,
                averageHeartRate: 144,
                weatherTemperatureCelsius: 22,
                coordinateStart: CLLocationCoordinate2D(latitude: 33.503, longitude: -111.927),
                coordinateDelta: (0.044, 0.061)
            ),
            buildWorkoutRecord(
                sourceId: "mock-workout-walk",
                title: "Neighborhood Walk",
                activityType: .walking,
                startDate: calendar.date(byAdding: .day, value: -4, to: today)?.addingTimeInterval(60 * 60 * 18.0) ?? referenceDate,
                durationMinutes: 36,
                distanceMeters: 3_250,
                calories: 210,
                averageHeartRate: 108,
                weatherTemperatureCelsius: 25,
                coordinateStart: CLLocationCoordinate2D(latitude: 33.470, longitude: -112.010),
                coordinateDelta: (0.010, 0.012)
            ),
            buildWorkoutRecord(
                sourceId: "mock-workout-run-lastweek",
                title: "Long Run",
                activityType: .running,
                startDate: calendar.date(byAdding: .day, value: -8, to: today)?.addingTimeInterval(60 * 60 * 6.75) ?? referenceDate,
                durationMinutes: 58,
                distanceMeters: 10_900,
                calories: 790,
                averageHeartRate: 148,
                weatherTemperatureCelsius: 17,
                coordinateStart: CLLocationCoordinate2D(latitude: 33.420, longitude: -111.950),
                coordinateDelta: (0.023, 0.027)
            ),
            buildWorkoutRecord(
                sourceId: "mock-workout-ride-older",
                title: "Weekend Ride",
                activityType: .cycling,
                startDate: calendar.date(byAdding: .day, value: -16, to: today)?.addingTimeInterval(60 * 60 * 8.25) ?? referenceDate,
                durationMinutes: 95,
                distanceMeters: 42_200,
                calories: 1_040,
                averageHeartRate: 141,
                weatherTemperatureCelsius: 20,
                coordinateStart: CLLocationCoordinate2D(latitude: 33.610, longitude: -112.180),
                coordinateDelta: (0.061, 0.072)
            )
        ]
    }

    private static func buildWorkoutRecord(
        sourceId: String,
        title: String,
        activityType: HKWorkoutActivityType,
        startDate: Date,
        durationMinutes: Int,
        distanceMeters: Double,
        calories: Double,
        averageHeartRate: Double,
        weatherTemperatureCelsius: Double,
        coordinateStart: CLLocationCoordinate2D,
        coordinateDelta: (lat: Double, lon: Double)
    ) -> WorkoutRecord {
        let duration = Double(durationMinutes * 60)
        let endDate = startDate.addingTimeInterval(duration)
        let metadata: [String: Any] = [
            HKMetadataKeySyncIdentifier: sourceId,
            HKMetadataKeySyncVersion: 1,
            HKMetadataKeyWeatherTemperature: HKQuantity(unit: .degreeCelsius(), doubleValue: weatherTemperatureCelsius)
        ]

        let hkWorkout = HKWorkout(
            activityType: activityType,
            start: startDate,
            end: endDate,
            duration: duration,
            totalEnergyBurned: HKQuantity(unit: .kilocalorie(), doubleValue: calories),
            totalDistance: HKQuantity(unit: .meter(), doubleValue: distanceMeters),
            metadata: metadata
        )

        return WorkoutRecord(
            sourceId: sourceId,
            title: title,
            hkWorkout: hkWorkout,
            averageHeartRate: averageHeartRate,
            weatherTemperatureCelsius: weatherTemperatureCelsius,
            routeLocations: buildRoute(
                startDate: startDate,
                endDate: endDate,
                start: coordinateStart,
                delta: coordinateDelta
            ),
            heartRateIntervals: buildWorkoutHeartRateIntervals(
                startDate: startDate,
                durationMinutes: durationMinutes,
                averageHeartRate: averageHeartRate
            )
        )
    }

    private static func buildRoute(
        startDate: Date,
        endDate: Date,
        start: CLLocationCoordinate2D,
        delta: (lat: Double, lon: Double)
    ) -> [CLLocation] {
        let pointCount = 24
        let duration = endDate.timeIntervalSince(startDate)
        guard pointCount > 1 else { return [] }

        return (0..<pointCount).map { index in
            let progress = Double(index) / Double(pointCount - 1)
            let latJitter = sin(progress * .pi * 4) * 0.0012
            let lonJitter = cos(progress * .pi * 3) * 0.0010
            let coordinate = CLLocationCoordinate2D(
                latitude: start.latitude + (delta.lat * progress) + latJitter,
                longitude: start.longitude + (delta.lon * progress) + lonJitter
            )
            let timestamp = startDate.addingTimeInterval(duration * progress)
            return CLLocation(
                coordinate: coordinate,
                altitude: 350 + (progress * 18),
                horizontalAccuracy: 8,
                verticalAccuracy: 12,
                timestamp: timestamp
            )
        }
    }

    private static func buildWorkoutHeartRateIntervals(
        startDate: Date,
        durationMinutes: Int,
        averageHeartRate: Double
    ) -> [SQHeartRateIntervalSummary] {
        (0..<durationMinutes).map { minute in
            let intervalStart = startDate.addingTimeInterval(Double(minute) * 60)
            let intervalEnd = intervalStart.addingTimeInterval(60)
            let oscillation = sin(Double(minute) / 4.5) * 8
            let ramp = min(Double(minute) / Double(max(durationMinutes, 1)), 1) * 6
            return SQHeartRateIntervalSummary(
                startDate: intervalStart,
                endDate: intervalEnd,
                average: averageHeartRate + oscillation + ramp
            )
        }
    }

    private static func buildSleepSegments(referenceDate: Date) -> [SQSleepStageSegment] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: referenceDate)
        var segments = [SQSleepStageSegment]()

        for dayOffset in 0..<16 {
            let wakeDay = calendar.date(byAdding: .day, value: -dayOffset, to: today) ?? today
            let sleepStart = calendar.date(byAdding: .hour, value: -8, to: wakeDay) ?? wakeDay
            let start = calendar.date(byAdding: .minute, value: -10 - (dayOffset % 4) * 7, to: sleepStart) ?? sleepStart

            let phaseMinutes: [(SQSleepPhase, Int)] = [
                (.core, 92),
                (.deep, 56 - (dayOffset % 2) * 4),
                (.core, 84),
                (.rem, 38 + (dayOffset % 3) * 4),
                (.awake, 7 + (dayOffset % 2) * 3),
                (.core, 73),
                (.rem, 44 + (dayOffset % 4) * 3),
                (.awake, 6)
            ]

            var cursor = start
            for (phase, minutes) in phaseMinutes {
                let end = calendar.date(byAdding: .minute, value: minutes, to: cursor) ?? cursor
                segments.append(
                    SQSleepStageSegment(
                        phase: phase,
                        startDate: cursor,
                        endDate: end
                    )
                )
                cursor = end
            }
        }

        return segments.sorted { $0.startDate < $1.startDate }
    }

    private static func buildDailyHeartSummaries(
        referenceDate: Date,
        isResting: Bool
    ) -> [SQHeartRateDailySummary] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: referenceDate)

        return (0..<40).compactMap { dayOffset in
            guard let date = calendar.date(byAdding: .day, value: -dayOffset, to: today) else {
                return nil
            }

            if isResting {
                let average = 55 + Double(dayOffset % 4)
                return SQHeartRateDailySummary(
                    date: date,
                    average: average,
                    minimum: nil,
                    maximum: nil
                )
            }

            let average = 74 + Double((dayOffset * 3) % 9)
            let minimum = 47 + Double(dayOffset % 5)
            let maximum = 152 - Double(dayOffset % 7) + Double((dayOffset % 3) * 4)
            return SQHeartRateDailySummary(
                date: date,
                average: average,
                minimum: minimum,
                maximum: maximum
            )
        }
    }

    private static func buildVO2MaxSamples(referenceDate: Date) -> [SQVO2MaxSample] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: referenceDate)

        return (0..<12).compactMap { index in
            guard let date = calendar.date(byAdding: .day, value: -(index * 12 + 4), to: today) else {
                return nil
            }

            return SQVO2MaxSample(
                value: 45.5 + Double(index % 5) * 0.6,
                startDate: date,
                endDate: date.addingTimeInterval(60 * 30),
                healthKitId: "mock-vo2-\(index)",
                sourceName: "LifeIQ Mock"
            )
        }
        .sorted { $0.startDate < $1.startDate }
    }
}

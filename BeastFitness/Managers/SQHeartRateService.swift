//
//  SQHeartRateService.swift
//  BeastFitness
//

import Foundation
import HealthKit
import BeastFitnessCore

enum SQHeartRateZone: Int, CaseIterable, Identifiable, Sendable {
    case zone1
    case zone2
    case zone3
    case zone4
    case zone5

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .zone1: return "Zone 1"
        case .zone2: return "Zone 2"
        case .zone3: return "Zone 3"
        case .zone4: return "Zone 4"
        case .zone5: return "Zone 5"
        }
    }

    var subtitle: String {
        switch self {
        case .zone1: return "Recovery"
        case .zone2: return "Aerobic"
        case .zone3: return "Tempo"
        case .zone4: return "Threshold"
        case .zone5: return "Peak"
        }
    }

    var lowerPercentOfMax: Double {
        switch self {
        case .zone1: return 0.50
        case .zone2: return 0.60
        case .zone3: return 0.70
        case .zone4: return 0.80
        case .zone5: return 0.90
        }
    }

    var upperPercentOfMax: Double? {
        switch self {
        case .zone1: return 0.60
        case .zone2: return 0.70
        case .zone3: return 0.80
        case .zone4: return 0.90
        case .zone5: return nil
        }
    }

    var loadMultiplier: Double {
        switch self {
        case .zone1: return 1
        case .zone2: return 2
        case .zone3: return 4
        case .zone4: return 7
        case .zone5: return 10
        }
    }
}

struct SQHeartRateZoneRange: Sendable {
    let zone: SQHeartRateZone
    let lowerBound: Int
    let upperBound: Int?

    func contains(_ heartRate: Double) -> Bool {
        if let upperBound {
            return heartRate >= Double(lowerBound) && heartRate < Double(upperBound)
        }

        return heartRate >= Double(lowerBound)
    }
}

struct SQHeartRateZoneProfile: Sendable {
    let estimatedMaxHeartRate: Int
    let age: Int?
    let methodDescription: String
    let zones: [SQHeartRateZoneRange]
}

struct SQHeartRateZoneDistribution: Identifiable, Sendable {
    let zone: SQHeartRateZone
    let durationSeconds: Double
    let contribution: Double
    let range: SQHeartRateZoneRange

    var id: SQHeartRateZone { zone }
}

struct SQHeartRateWorkoutZoneSummary: Sendable {
    let profile: SQHeartRateZoneProfile
    let distributions: [SQHeartRateZoneDistribution]
    let weightedLoad: Double
    let averageHeartRate: Double
    let maximumObservedHeartRate: Double
    let recordedDurationSeconds: Double
}

@MainActor
protocol SQHeartRateServicing {
    func buildDashboardRowViewModel(for timeRange: SQTimeRange) async throws -> SQDashboardHeartSummaryRowViewModel?
    func buildWorkoutZoneSummary(for workout: SQWorkoutSessionable) async -> SQHeartRateWorkoutZoneSummary?
}

@MainActor
final class SQHeartRateService: SQHeartRateServicing {
    private let healthKitManager: SQHealthKitManaging
    private let userState: SQUserStating

    init(
        healthKitManager: SQHealthKitManaging = SQHealthKitManager.shared,
        userState: SQUserStating = SQAppState.shared.userState
    ) {
        self.healthKitManager = healthKitManager
        self.userState = userState
    }

    func buildDashboardRowViewModel(for timeRange: SQTimeRange) async throws -> SQDashboardHeartSummaryRowViewModel? {
        async let heartTask = healthKitManager.fetchDailyHeartRateSummaries(timeRange)
        async let restingTask = healthKitManager.fetchDailyRestingHeartRateSummaries(timeRange)

        let heartSummaries = try await heartTask
        let restingSummaries = try await restingTask

        let averageResting = restingSummaries.compactMap(\.average).average
        let lowestHeartRate = heartSummaries.compactMap(\.minimum).min()
        let peakHeartRate = heartSummaries.compactMap(\.maximum).max()

        guard averageResting != nil || lowestHeartRate != nil || peakHeartRate != nil else {
            return nil
        }

        return SQDashboardHeartSummaryRowViewModel(
            items: [
                .init(
                    id: "resting",
                    title: "Resting Avg",
                    value: formatted(averageResting),
                    unit: "bpm",
                    detail: detailText(for: timeRange, defaultText: "Average resting")
                ),
                .init(
                    id: "low",
                    title: "Lowest",
                    value: formatted(lowestHeartRate),
                    unit: "bpm",
                    detail: detailText(for: timeRange, defaultText: "Lowest recorded")
                ),
                .init(
                    id: "high",
                    title: "Highest",
                    value: formatted(peakHeartRate),
                    unit: "bpm",
                    detail: detailText(for: timeRange, defaultText: "Peak recorded")
                )
            ]
        )
    }

    func buildWorkoutZoneSummary(for workout: SQWorkoutSessionable) async -> SQHeartRateWorkoutZoneSummary? {
        if let cached = await SQWorkoutSession.metadataManager.cachedHeartRateZoneSummary(for: workout.id) {
            return cached
        }

        do {
            let intervalSummaries: [SQHeartRateIntervalSummary]

            switch workout.workoutSource {
            case .hkWorkout(let hkWorkout):
                intervalSummaries = try await healthKitManager.fetchWorkoutHeartRateSummaries(for: hkWorkout.hkWorkout)
            case .stravaWorkout(_), .manual(_):
                guard let healthKitId = workout.hkWorkoutId else {
                    return nil
                }
                intervalSummaries = try await healthKitManager.fetchWorkoutHeartRateSummaries(for: healthKitId)
            }

            let validIntervals = intervalSummaries.filter { $0.durationSeconds > 0 }
            guard !validIntervals.isEmpty else {
                return nil
            }

            let maximumObservedHeartRate = validIntervals.map(\.average).max() ?? 0
            guard maximumObservedHeartRate > 0 else {
                return nil
            }

            let profile = makeZoneProfile(
                for: workout,
                maximumObservedHeartRate: maximumObservedHeartRate
            )

            let distributions = profile.zones.map { range -> SQHeartRateZoneDistribution in
                let durationSeconds = validIntervals
                    .filter { range.contains($0.average) }
                    .reduce(0) { $0 + $1.durationSeconds }
                let contribution = (durationSeconds / 60) * range.zone.loadMultiplier
                return .init(
                    zone: range.zone,
                    durationSeconds: durationSeconds,
                    contribution: contribution,
                    range: range
                )
            }

            let recordedDurationSeconds = distributions.reduce(0) { $0 + $1.durationSeconds }
            guard recordedDurationSeconds > 0 else {
                return nil
            }

            let weightedLoad = distributions.reduce(0) { $0 + $1.contribution }
            let weightedHeartRateTotal = validIntervals.reduce(0) { partialResult, sample in
                partialResult + (sample.average * sample.durationSeconds)
            }
            let averageHeartRate = weightedHeartRateTotal / recordedDurationSeconds

            let summary = SQHeartRateWorkoutZoneSummary(
                profile: profile,
                distributions: distributions,
                weightedLoad: weightedLoad,
                averageHeartRate: averageHeartRate,
                maximumObservedHeartRate: maximumObservedHeartRate,
                recordedDurationSeconds: recordedDurationSeconds
            )

            await SQWorkoutSession.metadataManager.cacheHeartRateZoneSummary(summary, for: workout.id)
            return summary
        } catch {
            SQLogger.shared.log(
                "Failed to build workout HR zone summary for \(workout.id): \(error.localizedDescription)",
                .debug,
                context: .healthKit
            )
            return nil
        }
    }

    private func formatted(_ value: Double?) -> String {
        guard let value else { return "--" }
        return Int(value.rounded()).description
    }

    private func detailText(for timeRange: SQTimeRange, defaultText: String) -> String {
        switch timeRange {
        case .today:
            return "\(defaultText) today"
        case .pastWeek:
            return "\(defaultText) in 7 days"
        case .past30Days:
            return "\(defaultText) in 30 days"
        case .pastYear:
            return "\(defaultText) in 1 year"
        case .allTime:
            return "\(defaultText) all time"
        case .yesterday:
            return "\(defaultText) yesterday"
        case .weekBeforeLast:
            return "\(defaultText) in prior week"
        case .thirtyDaysBeforeLast:
            return "\(defaultText) in prior 30 days"
        case .yearBeforeLast:
            return "\(defaultText) in prior year"
        }
    }

    private func makeZoneProfile(
        for workout: SQWorkoutSessionable,
        maximumObservedHeartRate: Double
    ) -> SQHeartRateZoneProfile {
        let referenceDate = workout.startDate ?? .now
        let age = userState.loggedInUser?.dateOfBirth.flatMap {
            Calendar.current.dateComponents([.year], from: $0, to: referenceDate).year
        }

        let estimatedMaxHeartRate = estimatedMaxHeartRate(
            age: age,
            maximumObservedHeartRate: maximumObservedHeartRate
        )
        let zones = SQHeartRateZone.allCases.map { zone -> SQHeartRateZoneRange in
            let lowerBound = Int((Double(estimatedMaxHeartRate) * zone.lowerPercentOfMax).rounded())
            let upperBound = zone.upperPercentOfMax.map {
                Int((Double(estimatedMaxHeartRate) * $0).rounded())
            }
            return .init(zone: zone, lowerBound: lowerBound, upperBound: upperBound)
        }

        let methodDescription: String
        if age != nil {
            methodDescription = "Estimated from your profile age and observed workout heart rate."
        } else {
            methodDescription = "Estimated from observed workout heart rate using standard max-HR defaults."
        }

        return .init(
            estimatedMaxHeartRate: estimatedMaxHeartRate,
            age: age,
            methodDescription: methodDescription,
            zones: zones
        )
    }

    private func estimatedMaxHeartRate(
        age: Int?,
        maximumObservedHeartRate: Double
    ) -> Int {
        let ageEstimate = age.map { 208 - (0.7 * Double($0)) } ?? 190
        let adjustedEstimate = max(ageEstimate, maximumObservedHeartRate * 1.03)
        return Int(clamp(adjustedEstimate.rounded(), min: 155, max: 210))
    }

    private func clamp(_ value: Double, min minimum: Double, max maximum: Double) -> Double {
        Swift.max(minimum, Swift.min(maximum, value))
    }
}

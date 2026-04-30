//
//  SQInsightFeatureBuilder.swift
//  BeastFitness
//
//  Created by Codex on 4/22/26.
//

import Foundation
import HealthKit

protocol SQInsightFeatureBuilding {
    func makeFeatureSnapshots(
        checkIns: [SQDailyCheckInStats],
        workouts: [SQWorkoutSessionable],
        metricDefinitions: [SQMetricDefinition],
        sleepData: SQSleepDashboardData?,
        restingHeartRateSummaries: [SQHeartRateDailySummary]
    ) -> [SQInsightFeatureSnapshot]
}

final class SQInsightFeatureBuilder: SQInsightFeatureBuilding {
    private let sleepAggregationService: SQSleepAggregationService

    init(
        sleepAggregationService: SQSleepAggregationService = .init()
    ) {
        self.sleepAggregationService = sleepAggregationService
    }

    func makeFeatureSnapshots(
        checkIns: [SQDailyCheckInStats],
        workouts: [SQWorkoutSessionable],
        metricDefinitions: [SQMetricDefinition],
        sleepData: SQSleepDashboardData?,
        restingHeartRateSummaries: [SQHeartRateDailySummary]
    ) -> [SQInsightFeatureSnapshot] {
        let definitionsById = Dictionary(
            uniqueKeysWithValues: metricDefinitions.map { ($0.id, $0) }
        )

        var rawValuesByDay = [String: [String: Double]]()
        var normalizedValuesByDay = [String: [String: Double]]()
        var healthKitSleepMetricIdsByDay = [String: Set<String>]()

        for checkIn in checkIns {
            let dayKey = checkIn.uniqueDateKey
            var rawMap = rawValuesByDay[dayKey, default: [:]]
            var normalizedMap = normalizedValuesByDay[dayKey, default: [:]]

            for metricId in Set(checkIn.values.keys).union(checkIn.metricValues.keys) {
                guard let definition = definitionsById[metricId] else { continue }

                let loggedValue = checkIn.metricValues[metricId]
                let analysisRawValue = loggedValue?.quantityValue ?? loggedValue?.displayValue ?? checkIn.values[metricId]
                let scaleValue = loggedValue?.scaleValue

                guard let analysisRawValue else { continue }

                rawMap[metricId] = Double(analysisRawValue)
                normalizedMap[metricId] = Double(
                    SQMetricEntry.normalizedScore(
                        scaleValue: scaleValue,
                        quantityValue: loggedValue?.quantityValue,
                        rawValue: analysisRawValue,
                        definition: definition
                    )
                )

                if Self.sleepSignalIds.contains(metricId),
                   checkIn.healthKitMetricIds.contains(metricId) {
                    healthKitSleepMetricIdsByDay[dayKey, default: []].insert(metricId)
                }
            }

            rawValuesByDay[dayKey] = rawMap
            normalizedValuesByDay[dayKey] = normalizedMap
        }

        for summary in restingHeartRateSummaries {
            guard let averageRestingHeartRate = summary.average else { continue }

            let dayKey = summary.date.anchorDayKey()
            var rawMap = rawValuesByDay[dayKey, default: [:]]
            var normalizedMap = normalizedValuesByDay[dayKey, default: [:]]

            rawMap[SQInsightAnalysisMetricId.restingHeartRate] = averageRestingHeartRate
            normalizedMap[SQInsightAnalysisMetricId.restingHeartRate] = averageRestingHeartRate

            rawValuesByDay[dayKey] = rawMap
            normalizedValuesByDay[dayKey] = normalizedMap
        }

        mergeHealthKitSleepValues(
            from: sleepData,
            definitionsById: definitionsById,
            healthKitSleepMetricIdsByDay: healthKitSleepMetricIdsByDay,
            rawValuesByDay: &rawValuesByDay,
            normalizedValuesByDay: &normalizedValuesByDay
        )

        let workoutsByDay = Dictionary(grouping: workouts) { workout in
            (workout.startDate ?? .now).anchorDayKey()
        }

        let dayKeys = Set(rawValuesByDay.keys)
            .union(normalizedValuesByDay.keys)
            .union(workoutsByDay.keys)
            .sorted()

        return dayKeys.compactMap { dayKey in
            guard let date = SQDateFormatters.shared.date(from: dayKey, preferredStyle: .firebaseDayKey) else {
                return nil
            }

            let dayWorkouts = workoutsByDay[dayKey, default: []]
            let performanceSignal = dominantWorkoutSignal(
                workouts: dayWorkouts,
                value: { $0.ratingUserPerformance.map(Double.init) }
            )
            let difficultySignal = dominantWorkoutSignal(
                workouts: dayWorkouts,
                value: { $0.ratingDifficulty.map(Double.init) }
            )

            return SQInsightFeatureSnapshot(
                date: date,
                anchorDayKey: dayKey,
                rawSignalValues: rawValuesByDay[dayKey, default: [:]],
                normalizedSignalValues: normalizedValuesByDay[dayKey, default: [:]],
                workoutCount: dayWorkouts.count,
                averageWorkoutPerformance: performanceSignal?.averageValue,
                workoutPerformanceActivityTypeRaw: performanceSignal?.activityType.rawValue,
                averageWorkoutDifficulty: difficultySignal?.averageValue,
                workoutDifficultyActivityTypeRaw: difficultySignal?.activityType.rawValue
            )
        }
    }

    private func dominantWorkoutSignal(
        workouts: [SQWorkoutSessionable],
        value: (SQWorkoutSessionable) -> Double?
    ) -> (activityType: HKWorkoutActivityType, averageValue: Double)? {
        let grouped = Dictionary(grouping: workouts.compactMap { workout -> (HKWorkoutActivityType, Double)? in
            guard let ratingValue = value(workout) else { return nil }
            return (workout.activityType, ratingValue)
        }) { $0.0 }

        guard let dominantGroup = grouped.max(by: { lhs, rhs in
            if lhs.value.count == rhs.value.count {
                return lhs.key.rawValue < rhs.key.rawValue
            }
            return lhs.value.count < rhs.value.count
        }) else {
            return nil
        }

        return (
            activityType: dominantGroup.key,
            averageValue: average(of: dominantGroup.value.map(\.1)) ?? 0
        )
    }

    private func average(of values: [Double]) -> Double? {
        guard !values.isEmpty else { return nil }
        return values.reduce(0, +) / Double(values.count)
    }

    private func mergeHealthKitSleepValues(
        from sleepData: SQSleepDashboardData?,
        definitionsById: [String: SQMetricDefinition],
        healthKitSleepMetricIdsByDay: [String: Set<String>],
        rawValuesByDay: inout [String: [String: Double]],
        normalizedValuesByDay: inout [String: [String: Double]]
    ) {
        let nights = ((sleepData?.priorNights ?? []) + (sleepData?.currentNights ?? []))
            .sorted { $0.wakeDay < $1.wakeDay }

        for night in nights {
            let dayKey = night.wakeDay.anchorDayKey()
            let score = sleepAggregationService.score(for: night).totalScore

            writeHealthKitSleepValue(
                metricId: SQMetricId.sleepQuality,
                value: min(max(score / 10.0, 0), 10),
                dayKey: dayKey,
                definitionsById: definitionsById,
                healthKitSleepMetricIdsByDay: healthKitSleepMetricIdsByDay,
                rawValuesByDay: &rawValuesByDay,
                normalizedValuesByDay: &normalizedValuesByDay
            )

            writeHealthKitSleepValue(
                metricId: SQMetricId.sleepHours,
                value: min(max(night.totalSleepDuration / 3600.0, 0), 24),
                dayKey: dayKey,
                definitionsById: definitionsById,
                healthKitSleepMetricIdsByDay: healthKitSleepMetricIdsByDay,
                rawValuesByDay: &rawValuesByDay,
                normalizedValuesByDay: &normalizedValuesByDay
            )
        }
    }

    private func writeHealthKitSleepValue(
        metricId: String,
        value: Double,
        dayKey: String,
        definitionsById: [String: SQMetricDefinition],
        healthKitSleepMetricIdsByDay: [String: Set<String>],
        rawValuesByDay: inout [String: [String: Double]],
        normalizedValuesByDay: inout [String: [String: Double]]
    ) {
        let existingWasHealthKitPrefill = healthKitSleepMetricIdsByDay[dayKey]?.contains(metricId) == true
        guard rawValuesByDay[dayKey]?[metricId] == nil || existingWasHealthKitPrefill else {
            return
        }

        var rawMap = rawValuesByDay[dayKey, default: [:]]
        var normalizedMap = normalizedValuesByDay[dayKey, default: [:]]

        rawMap[metricId] = value

        if let definition = definitionsById[metricId] {
            normalizedMap[metricId] = Double(SQMetricEntry.normalizedScore(
                for: Float(value),
                definition: definition
            ))
        } else {
            normalizedMap[metricId] = value
        }

        rawValuesByDay[dayKey] = rawMap
        normalizedValuesByDay[dayKey] = normalizedMap
    }

    private static let sleepSignalIds: Set<String> = [
        SQMetricId.sleepQuality,
        SQMetricId.sleepHours
    ]
}

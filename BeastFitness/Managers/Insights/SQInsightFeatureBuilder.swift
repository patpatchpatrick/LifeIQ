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
        metricDefinitions: [SQMetricDefinition]
    ) -> [SQInsightFeatureSnapshot]
}

final class SQInsightFeatureBuilder: SQInsightFeatureBuilding {
    func makeFeatureSnapshots(
        checkIns: [SQDailyCheckInStats],
        workouts: [SQWorkoutSessionable],
        metricDefinitions: [SQMetricDefinition]
    ) -> [SQInsightFeatureSnapshot] {
        let definitionsById = Dictionary(
            uniqueKeysWithValues: metricDefinitions.map { ($0.id, $0) }
        )

        var rawValuesByDay = [String: [String: Double]]()
        var normalizedValuesByDay = [String: [String: Double]]()

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
            }

            rawValuesByDay[dayKey] = rawMap
            normalizedValuesByDay[dayKey] = normalizedMap
        }

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
}

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
    private let goalEvaluator = SQMetricGoalEvaluator()
    private let semanticResolver = SQMetricSemanticResolver()

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
        let avoidItMetricIdsWithObservedValues = Set(
            checkIns
                .flatMap { Set($0.values.keys).union($0.metricValues.keys) }
                .filter { metricId in
                    definitionsById[metricId]?.goalStyle == .avoidIt
                }
        )

        var rawValuesByDay = [String: [String: Double]]()
        var normalizedValuesByDay = [String: [String: Double]]()
        var signalFeaturesByDay = [String: [String: SQInsightSignalFeature]]()
        var healthKitSleepMetricIdsByDay = [String: Set<String>]()

        for checkIn in checkIns {
            let dayKey = checkIn.uniqueDateKey
            var rawMap = rawValuesByDay[dayKey, default: [:]]
            var normalizedMap = normalizedValuesByDay[dayKey, default: [:]]
            var featureMap = signalFeaturesByDay[dayKey, default: [:]]

            for metricId in Set(checkIn.values.keys).union(checkIn.metricValues.keys) {
                guard let definition = definitionsById[metricId] else { continue }

                let loggedValue = checkIn.metricValues[metricId]
                let analysisRawValue = loggedValue?.quantityValue ?? loggedValue?.displayValue ?? checkIn.values[metricId]
                let scaleValue = loggedValue?.scaleValue

                guard let analysisRawValue else { continue }

                let rawValue = Double(analysisRawValue)
                rawMap[metricId] = rawValue
                normalizedMap[metricId] = Double(
                    SQMetricEntry.normalizedScore(
                        scaleValue: scaleValue,
                        quantityValue: loggedValue?.quantityValue,
                        rawValue: analysisRawValue,
                        definition: definition
                    )
                )
                featureMap[metricId] = metricSignalFeature(
                    metricId: metricId,
                    rawValue: rawValue,
                    definition: definition,
                    source: checkIn.healthKitMetricIds.contains(metricId) ? .healthKitFallback : .userLogged
                )

                if Self.sleepSignalIds.contains(metricId),
                   checkIn.healthKitMetricIds.contains(metricId) {
                    healthKitSleepMetricIdsByDay[dayKey, default: []].insert(metricId)
                }
            }

            for metricId in avoidItMetricIdsWithObservedValues where rawMap[metricId] == nil {
                guard let definition = definitionsById[metricId] else { continue }
                rawMap[metricId] = 0
                normalizedMap[metricId] = 0
                featureMap[metricId] = metricSignalFeature(
                    metricId: metricId,
                    rawValue: 0,
                    definition: definition,
                    source: .userLogged
                )
            }

            rawValuesByDay[dayKey] = rawMap
            normalizedValuesByDay[dayKey] = normalizedMap
            signalFeaturesByDay[dayKey] = featureMap
        }

        for summary in restingHeartRateSummaries {
            guard let averageRestingHeartRate = summary.average else { continue }

            let dayKey = summary.date.anchorDayKey()
            var rawMap = rawValuesByDay[dayKey, default: [:]]
            var normalizedMap = normalizedValuesByDay[dayKey, default: [:]]
            var featureMap = signalFeaturesByDay[dayKey, default: [:]]

            rawMap[SQInsightAnalysisMetricId.restingHeartRate] = averageRestingHeartRate
            normalizedMap[SQInsightAnalysisMetricId.restingHeartRate] = averageRestingHeartRate
            featureMap[SQInsightAnalysisMetricId.restingHeartRate] = derivedSignalFeature(
                signalId: SQInsightAnalysisMetricId.restingHeartRate,
                title: "Resting Heart Rate",
                rawValue: averageRestingHeartRate,
                normalizedValue: nil,
                goalUtilityScore: nil,
                signalRole: .bodyStat,
                source: .healthKitDerived
            )

            rawValuesByDay[dayKey] = rawMap
            normalizedValuesByDay[dayKey] = normalizedMap
            signalFeaturesByDay[dayKey] = featureMap
        }

        mergeDerivedSleepValues(
            from: sleepData,
            rawValuesByDay: &rawValuesByDay,
            normalizedValuesByDay: &normalizedValuesByDay,
            signalFeaturesByDay: &signalFeaturesByDay
        )
        mergeHealthKitSleepValues(
            from: sleepData,
            definitionsById: definitionsById,
            healthKitSleepMetricIdsByDay: healthKitSleepMetricIdsByDay,
            rawValuesByDay: &rawValuesByDay,
            normalizedValuesByDay: &normalizedValuesByDay,
            signalFeaturesByDay: &signalFeaturesByDay
        )

        let workoutsByDay = Dictionary(grouping: workouts) { workout in
            (workout.startDate ?? .now).anchorDayKey()
        }

        let dayKeys = Set(rawValuesByDay.keys)
            .union(normalizedValuesByDay.keys)
            .union(signalFeaturesByDay.keys)
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
            var rawSignalValues = rawValuesByDay[dayKey, default: [:]]
            var normalizedSignalValues = normalizedValuesByDay[dayKey, default: [:]]
            var signalFeatures = signalFeaturesByDay[dayKey, default: [:]]
            if let performanceSignal {
                signalFeatures[SQInsightAnalysisMetricId.workoutPerformance] = derivedSignalFeature(
                    signalId: SQInsightAnalysisMetricId.workoutPerformance,
                    title: "Workout Performance",
                    rawValue: performanceSignal.averageValue,
                    normalizedValue: normalizedScaleValue(performanceSignal.averageValue, min: 0, max: 10),
                    goalUtilityScore: performanceSignal.averageValue * 10,
                    signalRole: .outcome,
                    source: .workoutDerived
                )
            }
            if let difficultySignal {
                signalFeatures[SQInsightAnalysisMetricId.workoutDifficulty] = derivedSignalFeature(
                    signalId: SQInsightAnalysisMetricId.workoutDifficulty,
                    title: "Workout Difficulty",
                    rawValue: difficultySignal.averageValue,
                    normalizedValue: normalizedScaleValue(difficultySignal.averageValue, min: 0, max: 10),
                    goalUtilityScore: nil,
                    signalRole: .behavior,
                    source: .workoutDerived
                )
            }
            if !dayWorkouts.isEmpty {
                let workoutMinutes = dayWorkouts.reduce(0) { $0 + (($1.activeDuration ?? 0) / 60.0) }
                rawSignalValues[SQInsightAnalysisMetricId.workoutMinutes] = workoutMinutes
                normalizedSignalValues[SQInsightAnalysisMetricId.workoutMinutes] = normalizedScore(
                    workoutMinutes,
                    min: 0,
                    max: 90
                )
                signalFeatures[SQInsightAnalysisMetricId.workoutMinutes] = derivedSignalFeature(
                    signalId: SQInsightAnalysisMetricId.workoutMinutes,
                    title: "Workout Minutes",
                    rawValue: workoutMinutes,
                    normalizedValue: normalizedScaleValue(workoutMinutes, min: 0, max: 90),
                    goalUtilityScore: nil,
                    signalRole: .behavior,
                    source: .workoutDerived
                )

                let cardioMinutes = dayWorkouts
                    .filter { Self.cardioActivityTypes.contains($0.activityType) }
                    .reduce(0) { $0 + (($1.activeDuration ?? 0) / 60.0) }
                if cardioMinutes > 0 {
                    rawSignalValues[SQInsightAnalysisMetricId.cardioMinutes] = cardioMinutes
                    normalizedSignalValues[SQInsightAnalysisMetricId.cardioMinutes] = normalizedScore(
                        cardioMinutes,
                        min: 0,
                        max: 75
                    )
                    signalFeatures[SQInsightAnalysisMetricId.cardioMinutes] = derivedSignalFeature(
                        signalId: SQInsightAnalysisMetricId.cardioMinutes,
                        title: "Cardio Minutes",
                        rawValue: cardioMinutes,
                        normalizedValue: normalizedScaleValue(cardioMinutes, min: 0, max: 75),
                        goalUtilityScore: nil,
                        signalRole: .behavior,
                        source: .workoutDerived
                    )
                    rawSignalValues[SQInsightAnalysisMetricId.cardioDay] = 1
                    normalizedSignalValues[SQInsightAnalysisMetricId.cardioDay] = 10
                    signalFeatures[SQInsightAnalysisMetricId.cardioDay] = derivedSignalFeature(
                        signalId: SQInsightAnalysisMetricId.cardioDay,
                        title: "Cardio Day",
                        rawValue: 1,
                        normalizedValue: 1,
                        goalUtilityScore: nil,
                        signalRole: .behavior,
                        source: .workoutDerived
                    )
                }
            }

            return SQInsightFeatureSnapshot(
                date: date,
                anchorDayKey: dayKey,
                rawSignalValues: rawSignalValues,
                normalizedSignalValues: normalizedSignalValues,
                signalFeatures: signalFeatures,
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

    private func metricSignalFeature(
        metricId: String,
        rawValue: Double,
        definition: SQMetricDefinition,
        source: SQInsightSignalSource
    ) -> SQInsightSignalFeature {
        let evaluation = goalEvaluator.evaluate(value: rawValue, definition: definition)

        return .init(
            signalId: metricId,
            title: definition.title,
            rawValue: rawValue,
            normalizedValue: evaluation?.normalizedValue,
            goalUtilityScore: evaluation?.goalUtilityScore,
            signalRole: semanticResolver.signalRole(for: definition),
            lifeScoreImpact: semanticResolver.lifeScoreImpact(for: definition),
            insightMode: semanticResolver.insightMode(for: definition),
            sensitivity: semanticResolver.sensitivity(for: definition),
            source: source
        )
    }

    private func derivedSignalFeature(
        signalId: String,
        title: String,
        rawValue: Double,
        normalizedValue: Double?,
        goalUtilityScore: Double?,
        signalRole: SQMetricSignalRole,
        source: SQInsightSignalSource
    ) -> SQInsightSignalFeature {
        .init(
            signalId: signalId,
            title: title,
            rawValue: rawValue,
            normalizedValue: normalizedValue,
            goalUtilityScore: goalUtilityScore,
            signalRole: signalRole,
            lifeScoreImpact: .automatic,
            insightMode: .curatedRelationships,
            sensitivity: .normal,
            source: source
        )
    }

    private func normalizedScaleValue(
        _ value: Double,
        min minimum: Double,
        max maximum: Double
    ) -> Double? {
        guard maximum > minimum else { return nil }
        return Swift.max(0, Swift.min(1, (value - minimum) / (maximum - minimum)))
    }

    private func normalizedScore(
        _ value: Double,
        min minimum: Double,
        max maximum: Double
    ) -> Double {
        (normalizedScaleValue(value, min: minimum, max: maximum) ?? 0) * 10
    }

    private func inverseNormalizedScore(
        _ value: Double,
        min minimum: Double,
        max maximum: Double
    ) -> Double {
        (1 - (normalizedScaleValue(value, min: minimum, max: maximum) ?? 0)) * 10
    }

    private func mergeDerivedSleepValues(
        from sleepData: SQSleepDashboardData?,
        rawValuesByDay: inout [String: [String: Double]],
        normalizedValuesByDay: inout [String: [String: Double]],
        signalFeaturesByDay: inout [String: [String: SQInsightSignalFeature]]
    ) {
        let nights = ((sleepData?.priorNights ?? []) + (sleepData?.currentNights ?? []))
            .sorted { $0.wakeDay < $1.wakeDay }

        for night in nights {
            let dayKey = night.wakeDay.anchorDayKey()
            let totalSleepMinutes = max(night.totalSleepDuration / 60.0, 1)
            let timeInBedMinutes = max(night.timeInBedDuration / 60.0, 1)
            let remMinutes = night.phaseDuration(for: .rem) / 60.0
            let deepMinutes = night.phaseDuration(for: .deep) / 60.0
            let coreMinutes = night.phaseDuration(for: .core) / 60.0
            let awakeMinutes = night.phaseDuration(for: .awake) / 60.0
            let awakeningCount = Double(interruptionCount(for: night))
            let score = sleepAggregationService.score(for: night)
            let fragmentationScore = score.fragmentationScore
            let remPercent = (remMinutes / totalSleepMinutes) * 100.0
            let sleepEfficiency = min(max((totalSleepMinutes / timeInBedMinutes) * 100.0, 0), 100)

            writeDerivedSleepValue(
                signalId: SQInsightAnalysisMetricId.sleepRemMinutes,
                title: "REM Sleep",
                rawValue: remMinutes,
                normalizedScore: normalizedScore(remMinutes, min: 0, max: 120),
                dayKey: dayKey,
                rawValuesByDay: &rawValuesByDay,
                normalizedValuesByDay: &normalizedValuesByDay,
                signalFeaturesByDay: &signalFeaturesByDay
            )
            writeDerivedSleepValue(
                signalId: SQInsightAnalysisMetricId.sleepRemPercent,
                title: "REM %",
                rawValue: remPercent,
                normalizedScore: normalizedScore(remPercent, min: 0, max: 25),
                dayKey: dayKey,
                rawValuesByDay: &rawValuesByDay,
                normalizedValuesByDay: &normalizedValuesByDay,
                signalFeaturesByDay: &signalFeaturesByDay
            )
            writeDerivedSleepValue(
                signalId: SQInsightAnalysisMetricId.sleepDeepMinutes,
                title: "Deep Sleep",
                rawValue: deepMinutes,
                normalizedScore: normalizedScore(deepMinutes, min: 0, max: 120),
                dayKey: dayKey,
                rawValuesByDay: &rawValuesByDay,
                normalizedValuesByDay: &normalizedValuesByDay,
                signalFeaturesByDay: &signalFeaturesByDay
            )
            writeDerivedSleepValue(
                signalId: SQInsightAnalysisMetricId.sleepCoreMinutes,
                title: "Core Sleep",
                rawValue: coreMinutes,
                normalizedScore: normalizedScore(coreMinutes, min: 0, max: 360),
                dayKey: dayKey,
                rawValuesByDay: &rawValuesByDay,
                normalizedValuesByDay: &normalizedValuesByDay,
                signalFeaturesByDay: &signalFeaturesByDay
            )
            writeDerivedSleepValue(
                signalId: SQInsightAnalysisMetricId.sleepAwakeMinutes,
                title: "Awake Minutes",
                rawValue: awakeMinutes,
                normalizedScore: normalizedScore(awakeMinutes, min: 0, max: 60),
                goalUtilityScore: inverseNormalizedScore(awakeMinutes, min: 0, max: 60) * 10.0,
                dayKey: dayKey,
                rawValuesByDay: &rawValuesByDay,
                normalizedValuesByDay: &normalizedValuesByDay,
                signalFeaturesByDay: &signalFeaturesByDay
            )
            writeDerivedSleepValue(
                signalId: SQInsightAnalysisMetricId.sleepAwakeningCount,
                title: "Awakenings",
                rawValue: awakeningCount,
                normalizedScore: normalizedScore(awakeningCount, min: 0, max: 8),
                goalUtilityScore: inverseNormalizedScore(awakeningCount, min: 0, max: 8) * 10.0,
                dayKey: dayKey,
                rawValuesByDay: &rawValuesByDay,
                normalizedValuesByDay: &normalizedValuesByDay,
                signalFeaturesByDay: &signalFeaturesByDay
            )
            writeDerivedSleepValue(
                signalId: SQInsightAnalysisMetricId.sleepContinuity,
                title: "Sleep Continuity",
                rawValue: awakeningCount,
                normalizedScore: normalizedScore(
                    fragmentationScore,
                    min: 0,
                    max: SQSleepScoreBreakdown.maxFragmentationScore
                ),
                dayKey: dayKey,
                rawValuesByDay: &rawValuesByDay,
                normalizedValuesByDay: &normalizedValuesByDay,
                signalFeaturesByDay: &signalFeaturesByDay
            )
            writeDerivedSleepValue(
                signalId: SQInsightAnalysisMetricId.sleepFragmentationScore,
                title: "Fragmentation Score",
                rawValue: fragmentationScore,
                normalizedScore: normalizedScore(
                    fragmentationScore,
                    min: 0,
                    max: SQSleepScoreBreakdown.maxFragmentationScore
                ),
                dayKey: dayKey,
                rawValuesByDay: &rawValuesByDay,
                normalizedValuesByDay: &normalizedValuesByDay,
                signalFeaturesByDay: &signalFeaturesByDay
            )
            writeDerivedSleepValue(
                signalId: SQInsightAnalysisMetricId.sleepEfficiency,
                title: "Sleep Efficiency",
                rawValue: sleepEfficiency,
                normalizedScore: normalizedScore(sleepEfficiency, min: 70, max: 95),
                dayKey: dayKey,
                rawValuesByDay: &rawValuesByDay,
                normalizedValuesByDay: &normalizedValuesByDay,
                signalFeaturesByDay: &signalFeaturesByDay
            )
        }
    }

    private func interruptionCount(for night: SQSleepNight) -> Int {
        let segments = night.segments
        guard let firstSleepIndex = segments.firstIndex(where: { $0.phase != .awake }),
              let lastSleepIndex = segments.lastIndex(where: { $0.phase != .awake }),
              lastSleepIndex > firstSleepIndex else {
            return 0
        }

        return segments[(firstSleepIndex + 1)..<lastSleepIndex]
            .filter { $0.phase == .awake }
            .count
    }

    private func writeDerivedSleepValue(
        signalId: String,
        title: String,
        rawValue: Double,
        normalizedScore: Double,
        goalUtilityScore: Double? = nil,
        dayKey: String,
        rawValuesByDay: inout [String: [String: Double]],
        normalizedValuesByDay: inout [String: [String: Double]],
        signalFeaturesByDay: inout [String: [String: SQInsightSignalFeature]]
    ) {
        var rawMap = rawValuesByDay[dayKey, default: [:]]
        var normalizedMap = normalizedValuesByDay[dayKey, default: [:]]
        var featureMap = signalFeaturesByDay[dayKey, default: [:]]

        rawMap[signalId] = rawValue
        normalizedMap[signalId] = normalizedScore
        featureMap[signalId] = derivedSignalFeature(
            signalId: signalId,
            title: title,
            rawValue: rawValue,
            normalizedValue: normalizedScore / 10.0,
            goalUtilityScore: goalUtilityScore ?? normalizedScore * 10.0,
            signalRole: .bodyStat,
            source: .healthKitDerived
        )

        rawValuesByDay[dayKey] = rawMap
        normalizedValuesByDay[dayKey] = normalizedMap
        signalFeaturesByDay[dayKey] = featureMap
    }

    private func mergeHealthKitSleepValues(
        from sleepData: SQSleepDashboardData?,
        definitionsById: [String: SQMetricDefinition],
        healthKitSleepMetricIdsByDay: [String: Set<String>],
        rawValuesByDay: inout [String: [String: Double]],
        normalizedValuesByDay: inout [String: [String: Double]],
        signalFeaturesByDay: inout [String: [String: SQInsightSignalFeature]]
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
                normalizedValuesByDay: &normalizedValuesByDay,
                signalFeaturesByDay: &signalFeaturesByDay
            )

            writeHealthKitSleepValue(
                metricId: SQMetricId.sleepHours,
                value: min(max(night.totalSleepDuration / 3600.0, 0), 24),
                dayKey: dayKey,
                definitionsById: definitionsById,
                healthKitSleepMetricIdsByDay: healthKitSleepMetricIdsByDay,
                rawValuesByDay: &rawValuesByDay,
                normalizedValuesByDay: &normalizedValuesByDay,
                signalFeaturesByDay: &signalFeaturesByDay
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
        normalizedValuesByDay: inout [String: [String: Double]],
        signalFeaturesByDay: inout [String: [String: SQInsightSignalFeature]]
    ) {
        let existingWasHealthKitPrefill = healthKitSleepMetricIdsByDay[dayKey]?.contains(metricId) == true
        guard rawValuesByDay[dayKey]?[metricId] == nil || existingWasHealthKitPrefill else {
            return
        }

        var rawMap = rawValuesByDay[dayKey, default: [:]]
        var normalizedMap = normalizedValuesByDay[dayKey, default: [:]]
        var featureMap = signalFeaturesByDay[dayKey, default: [:]]

        rawMap[metricId] = value

        if let definition = definitionsById[metricId] {
            normalizedMap[metricId] = Double(SQMetricEntry.normalizedScore(
                for: Float(value),
                definition: definition
            ))
            featureMap[metricId] = metricSignalFeature(
                metricId: metricId,
                rawValue: value,
                definition: definition,
                source: .healthKitFallback
            )
        } else {
            normalizedMap[metricId] = value
            featureMap[metricId] = derivedSignalFeature(
                signalId: metricId,
                title: metricId,
                rawValue: value,
                normalizedValue: nil,
                goalUtilityScore: nil,
                signalRole: .bodyStat,
                source: .healthKitFallback
            )
        }

        rawValuesByDay[dayKey] = rawMap
        normalizedValuesByDay[dayKey] = normalizedMap
        signalFeaturesByDay[dayKey] = featureMap
    }

    private static let sleepSignalIds: Set<String> = [
        SQMetricId.sleepQuality,
        SQMetricId.sleepHours
    ]

    private static let cardioActivityTypes: Set<HKWorkoutActivityType> = [
        .running,
        .walking,
        .cycling,
        .highIntensityIntervalTraining,
        .elliptical,
        .stairClimbing,
        .rowing,
        .swimming,
        .hiking
    ]
}

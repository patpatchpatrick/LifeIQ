//
//  SQWorkoutStatsManager.swift
//  BeastFitness
//

import Foundation
import HealthKit
import SwiftData
import BeastFitnessCore

// MARK: - Protocol

protocol SQWorkoutStatsManaging {
    func metrics(for activityType: HKWorkoutActivityType) -> [SQQuantityType]
    func loadPerformanceData(for workout: SQWorkoutSessionable, isPremiumUnlocked: Bool) async -> [SQPerformanceRowData]
    func loadPerformanceRows(for activityType: HKWorkoutActivityType, in periodWorkouts: [SQWorkoutSessionable], allTimeWorkouts: [SQWorkoutSessionable], isPremiumUnlocked: Bool) async -> [SQPerformanceRowData]
    func generateHighlights(for workout: SQWorkoutSessionable, performanceData: [SQPerformanceRowData]) async -> [SQWorkoutReviewHighlight]
}

// MARK: - Implementation

final class SQWorkoutStatsManager: SQWorkoutStatsManaging {
    static let shared = SQWorkoutStatsManager()

    private let healthKitManager: SQHealthKitManaging
    private let workoutManager: SQWorkoutManaging

    init(
        healthKitManager: SQHealthKitManaging = SQHealthKitManager.shared,
        workoutManager: SQWorkoutManaging = SQWorkoutManager.shared
    ) {
        self.healthKitManager = healthKitManager
        self.workoutManager = workoutManager
    }
}

// MARK: - Metric Definitions

extension SQWorkoutStatsManager {

    private var metricsForAllActivityTypes: [SQQuantityType] {
        [
            .activeKilocaloriesBurned,
            .heartRate
        ]
    }

    private var activitySpecificMetricsByActivityType: [HKWorkoutActivityType: [SQQuantityType]] {
        [
            .running: [
                .sqFastestPace(.mile),
                .sqFastestPace(.fiveK),
                .sqPaceRunning,
                .distanceWalkingRunning
            ],
            .cycling: [
                .sqFastestPace(.fiveK),
                .distanceCycling
            ]
        ]
    }

    func metrics(for activityType: HKWorkoutActivityType) -> [SQQuantityType] {
        let specific = activitySpecificMetricsByActivityType[activityType] ?? []
        return metricsForAllActivityTypes + specific
    }
}

// MARK: - Performance Data Loading

extension SQWorkoutStatsManager {

    func loadPerformanceData(
        for workout: SQWorkoutSessionable,
        isPremiumUnlocked: Bool
    ) async -> [SQPerformanceRowData] {
        guard case .hkWorkout = workout.workoutSource else { return [] }
        guard let workoutEndDate = workout.endDate else { return [] }
        guard let modelContext = await SQAppState.shared.modelContext else { return [] }

        var rows: [SQPerformanceRowData] = []

        do {
            let allTimeWorkouts = try await workoutManager.getWorkouts(for: .allTime, modelContext: modelContext)
            let sameActivityWorkouts = allTimeWorkouts.filter { $0.activityType == workout.activityType }
            let workoutScoreService = await SQWorkoutScoreService()

            // VO2 Max — special case, not a workout metric
            if workout.activityType.impactsVO2MaxData {
                let recentSamples = try await healthKitManager.fetchVO2MaxSamples(upTo: workoutEndDate, limit: 1)
                if let sample = recentSamples.first {
                    let allTimeSamples = try await healthKitManager.fetchVO2MaxSamples(.allTime)
                    let calendar = Calendar.current
                    var bestByDay: [Date: Double] = [:]
                    for s in allTimeSamples {
                        let dayStart = calendar.startOfDay(for: s.startDate)
                        bestByDay[dayStart] = max(bestByDay[dayStart] ?? 0, s.value)
                    }
                    let percentile = SQPercentileCalculator.calculatePercentile(
                        currentBest: sample.value,
                        historicalValues: Array(bestByDay.values),
                        isLowerBetter: false
                    )
                    rows.append(SQPerformanceRowData(
                        id: "vo2-max",
                        icon: SQImageSymbol.heart.rawValue,
                        title: "VO₂ Max",
                        bestValue: String(format: "%.1f", sample.value),
                        unit: "mL/kg/min",
                        percentileRank: percentile,
                        leaderboardMode: .vo2Max
                    ))
                }
            }

            // Workout metrics — delegate to shared helper
            let metricTypes = metrics(for: workout.activityType)
            for quantityType in metricTypes {
                guard let currentMetric = await workout.getMetric(for: quantityType) else { continue }
                let row = await buildPerformanceRowData(
                    quantityType: quantityType,
                    activityType: workout.activityType,
                    currentValue: currentMetric.value,
                    sampleMetric: currentMetric,
                    sameActivityAllTimeWorkouts: sameActivityWorkouts
                )
                rows.append(row)
            }

            rows.append(contentsOf: await workoutScoreService.dashboardPerformanceRows(
                for: [workout],
                allTimeWorkouts: sameActivityWorkouts,
                isPremiumUnlocked: isPremiumUnlocked
            ))

        } catch {
            SQLogger.shared.log(
                "Failed to load performance data: \(error.localizedDescription)",
                .error,
                context: .workoutSummary
            )
        }

        return orderedPerformanceRows(rows, for: workout.activityType)
    }

    func loadPerformanceRows(
        for activityType: HKWorkoutActivityType,
        in periodWorkouts: [SQWorkoutSessionable],
        allTimeWorkouts: [SQWorkoutSessionable],
        isPremiumUnlocked: Bool
    ) async -> [SQPerformanceRowData] {
        let sameActivityAllTimeWorkouts = allTimeWorkouts.filter { $0.activityType == activityType }
        let metricTypes = metrics(for: activityType)
        var rows: [SQPerformanceRowData] = []
        let workoutScoreService = await SQWorkoutScoreService()

        for quantityType in metricTypes {
            let periodMetrics = await withTaskGroup(of: SQWorkoutMetric?.self) { group in
                for workout in periodWorkouts {
                    group.addTask { await workout.getMetric(for: quantityType) }
                }
                var results: [SQWorkoutMetric] = []
                for await metric in group { if let m = metric { results.append(m) } }
                return results
            }
            guard !periodMetrics.isEmpty, let sampleMetric = periodMetrics.first else { continue }

            // Best single workout in the period — always compare per-workout values so
            // the result is apples-to-apples with historical per-workout data.
            // .minimum types (e.g. pace) use min(); everything else uses max().
            let currentValue: Double
            if quantityType.dashboardAggregationType == .minimum {
                currentValue = periodMetrics.map { $0.value }.min() ?? 0
            } else {
                currentValue = periodMetrics.map { $0.value }.max() ?? 0
            }

            let row = await buildPerformanceRowData(
                quantityType: quantityType,
                activityType: activityType,
                currentValue: currentValue,
                sampleMetric: sampleMetric,
                sameActivityAllTimeWorkouts: sameActivityAllTimeWorkouts
            )
            rows.append(row)
        }

        rows.append(contentsOf: await workoutScoreService.dashboardPerformanceRows(
            for: periodWorkouts,
            allTimeWorkouts: sameActivityAllTimeWorkouts,
            isPremiumUnlocked: isPremiumUnlocked
        ))

        return orderedPerformanceRows(rows, for: activityType)
    }

    // MARK: - Shared helper

    /// Fetches historical metric values for `quantityType` from same-activity workouts,
    /// calculates the percentile rank for `currentValue`, and returns a populated row.
    private func buildPerformanceRowData(
        quantityType: SQQuantityType,
        activityType: HKWorkoutActivityType,
        currentValue: Double,
        sampleMetric: SQWorkoutMetric,
        sameActivityAllTimeWorkouts: [SQWorkoutSessionable]
    ) async -> SQPerformanceRowData {
        let historicalValues = await withTaskGroup(of: Double?.self) { group in
            for w in sameActivityAllTimeWorkouts {
                group.addTask { await w.getMetric(for: quantityType)?.value }
            }
            var results: [Double] = []
            for await value in group { if let v = value { results.append(v) } }
            return results
        }

        let isLowerBetter = quantityType.dashboardAggregationType == .minimum
        let percentile = SQPercentileCalculator.calculatePercentile(
            currentBest: currentValue,
            historicalValues: historicalValues,
            isLowerBetter: isLowerBetter
        )

        return SQPerformanceRowData(
            id: "\(activityType.name.lowercased())-\(quantityType.id)",
            icon: activityType.imageSymbol.rawValue,
            title: sampleMetric.displayName,
            bestValue: sampleMetric.displayableValue(for: quantityType, value: currentValue),
            unit: sampleMetric.unit.unitString ?? "",
            percentileRank: percentile,
            leaderboardMode: .workoutQuantity(quantityType, activityType)
        )
    }

    private func orderedPerformanceRows(
        _ rows: [SQPerformanceRowData],
        for activityType: HKWorkoutActivityType
    ) -> [SQPerformanceRowData] {
        let metricOrder = metrics(for: activityType)

        return rows.sorted { lhs, rhs in
            let leftPriority = performanceRowPriority(lhs, metricOrder: metricOrder)
            let rightPriority = performanceRowPriority(rhs, metricOrder: metricOrder)

            if leftPriority == rightPriority {
                return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
            }

            return leftPriority < rightPriority
        }
    }

    private func performanceRowPriority(
        _ row: SQPerformanceRowData,
        metricOrder: [SQQuantityType]
    ) -> Int {
        if row.id == "vo2-max" {
            return 0
        }

        if row.scoreKind == .performance {
            return 10
        }

        if row.scoreKind == .difficulty {
            return 11
        }

        if case .workoutQuantity(let quantityType, _) = row.leaderboardMode,
           let metricIndex = metricOrder.firstIndex(of: quantityType) {
            return 100 + metricIndex
        }

        return 1000
    }
}

// MARK: - Highlight Generation

extension SQWorkoutStatsManager {

    func generateHighlights(for workout: SQWorkoutSessionable, performanceData: [SQPerformanceRowData]) async -> [SQWorkoutReviewHighlight] {
        let supportsVO2Max = workout.activityType.impactsVO2MaxData
        let targetCount = 3

        var highlights: [SQWorkoutReviewHighlight] = []

        // Slot 1: VO2 Max delta (if supported)
        if supportsVO2Max {
            if let vo2Highlight = await buildVO2MaxHighlight(for: workout, performanceData: performanceData) {
                highlights.append(vo2Highlight)
            }
        }

        // Fill remaining slots with top-percentile rows (excluding VO2 Max if already shown)
        let remainingSlots = targetCount - highlights.count
        let candidateRows = performanceData
            .filter { supportsVO2Max ? $0.id != "vo2-max" : true }
            .filter { $0.percentileRank != nil }
            .sorted { ($0.percentileRank ?? 0) > ($1.percentileRank ?? 0) }
            .prefix(remainingSlots)

        for row in candidateRows {
            highlights.append(buildPercentileHighlight(for: row))
        }

        return highlights
    }

    // MARK: VO2 Max delta highlight

    private func buildVO2MaxHighlight(for workout: SQWorkoutSessionable, performanceData: [SQPerformanceRowData]) async -> SQWorkoutReviewHighlight? {
        guard let startDate = workout.startDate, let endDate = workout.endDate else { return nil }

        do {
            print("PTD Build VO2 Max Highlight 1")
            let beforeSample = try await healthKitManager.fetchLatestVO2MaxSample(strictlyBefore: startDate)
            let afterSample = try await healthKitManager.fetchLatestVO2MaxSample(onOrAfter: startDate, throughEndOfDay: endDate)
            print("PTD Build VO2 Max Highlight 2", beforeSample, afterSample)

            if let before = beforeSample, let after = afterSample {
                let beforeVal = before.value
                let afterVal = after.value
                let beforeStr = String(format: "%.1f", beforeVal)
                let afterStr = String(format: "%.1f", afterVal)

                if afterVal > beforeVal {
                    let deltaPercent = (abs(afterVal - beforeVal) / beforeVal * 100).adaptivePercentString
                    return SQWorkoutReviewHighlight(
                        segments: [
                            .init(text: "↑ VO₂ Max went up ", isStatistic: false),
                            .init(text: "\(deltaPercent): \(beforeStr) → \(afterStr)", isStatistic: true)
                        ],
                        sentiment: .positive
                    )
                } else if afterVal < beforeVal {
                    let deltaPercent = (abs(beforeVal - afterVal) / beforeVal * 100).adaptivePercentString
                    return SQWorkoutReviewHighlight(
                        segments: [
                            .init(text: "↓ VO₂ Max dropped ", isStatistic: false),
                            .init(text: "\(deltaPercent): \(beforeStr) → \(afterStr)", isStatistic: true)
                        ],
                        sentiment: .negative
                    )
                } else {
                    return SQWorkoutReviewHighlight(
                        segments: [
                            .init(text: "VO₂ Max unchanged at ", isStatistic: false),
                            .init(text: "\(afterStr) mL/kg/min", isStatistic: true)
                        ],
                        sentiment: .neutral
                    )
                }
            }
        } catch {
            SQLogger.shared.log(
                "Failed to fetch VO2 Max samples for highlight: \(error.localizedDescription)",
                .debug,
                context: .workoutSummary
            )
        }

        // Fallback: use percentile rank from performance data
        if let vo2Row = performanceData.first(where: { $0.id == "vo2-max" }) {
            return buildPercentileHighlight(for: vo2Row)
        }
        return nil
    }

    // MARK: Percentile highlight

    private func buildPercentileHighlight(for row: SQPerformanceRowData) -> SQWorkoutReviewHighlight {
        guard let percentile = row.percentileRank else {
            return SQWorkoutReviewHighlight(
                segments: [.init(text: row.title, isStatistic: false)],
                sentiment: .neutral
            )
        }

        if row.id.contains(SQQuantityType.heartRate.id) {
            return buildHeartRatePercentileHighlight(for: row, percentile: percentile)
        }

        let topPercent = Int(round((1.0 - percentile) * 100))
        let pctileInt = Int(round(percentile * 100))
        let ordinal = ordinalString(for: pctileInt)

        switch percentile {
        case 0.90...:
            return SQWorkoutReviewHighlight(
                segments: [
                    .init(text: "Top ", isStatistic: false),
                    .init(text: "\(topPercent)%", isStatistic: true),
                    .init(text: " for \(row.title) — you crushed it!", isStatistic: false)
                ],
                sentiment: .positive
            )
        case 0.65...:
            return SQWorkoutReviewHighlight(
                segments: [
                    .init(text: "Top ", isStatistic: false),
                    .init(text: "\(topPercent)%", isStatistic: true),
                    .init(text: " for \(row.title)", isStatistic: false)
                ],
                sentiment: .positive
            )
        case 0.35...:
            return SQWorkoutReviewHighlight(
                segments: [
                    .init(text: "Standard \(row.title) (", isStatistic: false),
                    .init(text: "~\(ordinal) %ile", isStatistic: true),
                    .init(text: ")", isStatistic: false)
                ],
                sentiment: .neutral
            )
        default:
            return SQWorkoutReviewHighlight(
                segments: [
                    .init(text: "Below average \(row.title) (", isStatistic: false),
                    .init(text: "\(ordinal) %ile", isStatistic: true),
                    .init(text: ")", isStatistic: false)
                ],
                sentiment: .negative
            )
        }
    }

    private func buildHeartRatePercentileHighlight(
        for row: SQPerformanceRowData,
        percentile: Double
    ) -> SQWorkoutReviewHighlight {
        let topPercent = Int(round((1.0 - percentile) * 100))
        let pctileInt = Int(round(percentile * 100))
        let ordinal = ordinalString(for: pctileInt)

        switch percentile {
        case 0.90...:
            return SQWorkoutReviewHighlight(
                segments: [
                    .init(text: "Top ", isStatistic: false),
                    .init(text: "\(topPercent)%", isStatistic: true),
                    .init(text: " for \(row.title) — higher than your usual range", isStatistic: false)
                ],
                sentiment: .neutral
            )
        case 0.65...:
            return SQWorkoutReviewHighlight(
                segments: [
                    .init(text: "Top ", isStatistic: false),
                    .init(text: "\(topPercent)%", isStatistic: true),
                    .init(text: " for \(row.title)", isStatistic: false)
                ],
                sentiment: .neutral
            )
        case 0.35...:
            return SQWorkoutReviewHighlight(
                segments: [
                    .init(text: "Typical \(row.title) (", isStatistic: false),
                    .init(text: "~\(ordinal) %ile", isStatistic: true),
                    .init(text: ")", isStatistic: false)
                ],
                sentiment: .neutral
            )
        default:
            return SQWorkoutReviewHighlight(
                segments: [
                    .init(text: "Lower \(row.title) (", isStatistic: false),
                    .init(text: "\(ordinal) %ile", isStatistic: true),
                    .init(text: ")", isStatistic: false)
                ],
                sentiment: .neutral
            )
        }
    }

    private func ordinalString(for n: Int) -> String {
        let suffix: String
        switch n % 100 {
        case 11, 12, 13:
            suffix = "th"
        default:
            switch n % 10 {
            case 1: suffix = "st"
            case 2: suffix = "nd"
            case 3: suffix = "rd"
            default: suffix = "th"
            }
        }
        return "\(n)\(suffix)"
    }
}

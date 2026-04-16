//
//  SQBodyBatteryService.swift
//  BeastFitness
//

import SwiftData
import Foundation
import SwiftUI
import BeastFitnessCore

@MainActor
protocol SQBodyBatteryServicing {
    func buildDashboardRowViewModel(
        todaysWorkouts: [SQWorkoutSessionable],
        yesterdaysWorkouts: [SQWorkoutSessionable],
        sleepData: SQSleepDashboardData?,
        context: ModelContext
    ) async throws -> SQDashboardBodyBatteryRowViewModel?
}

@MainActor
final class SQBodyBatteryService: SQBodyBatteryServicing {
    private let metricEntryManager: SQMetricEntryManaging
    private let metricsManager: SQMetricDefinitionManaging
    private let sleepAggregationService: SQSleepAggregationService
    private let healthKitManager: SQHealthKitManaging

    init(
        metricEntryManager: SQMetricEntryManaging,
        metricsManager: SQMetricDefinitionManaging = SQMetricDefinitionManager.shared,
        sleepAggregationService: SQSleepAggregationService = .init(),
        healthKitManager: SQHealthKitManaging = SQHealthKitManager.shared
    ) {
        self.metricEntryManager = metricEntryManager
        self.metricsManager = metricsManager
        self.sleepAggregationService = sleepAggregationService
        self.healthKitManager = healthKitManager
    }

    func buildDashboardRowViewModel(
        todaysWorkouts: [SQWorkoutSessionable],
        yesterdaysWorkouts: [SQWorkoutSessionable],
        sleepData: SQSleepDashboardData?,
        context: ModelContext
    ) async throws -> SQDashboardBodyBatteryRowViewModel? {
        async let todaysCheckInsTask = metricEntryManager.getDailyCheckInStats(
            from: SQTimeRange.today.startDate,
            to: SQTimeRange.today.endDate,
            context: context
        )
        async let yesterdaysCheckInsTask = metricEntryManager.getDailyCheckInStats(
            from: SQTimeRange.yesterday.startDate,
            to: SQTimeRange.yesterday.endDate,
            context: context
        )
        async let todaysRestingTask = healthKitManager.fetchDailyRestingHeartRateSummaries(.today)
        async let recentRestingTask = healthKitManager.fetchDailyRestingHeartRateSummaries(.pastWeek)
        async let todaysHeartRateTask = healthKitManager.fetchDailyHeartRateSummaries(.today)
        async let recentHeartRateTask = healthKitManager.fetchDailyHeartRateSummaries(.pastWeek)

        let todaysCheckIns = try await todaysCheckInsTask
        let yesterdaysCheckIns = try await yesterdaysCheckInsTask
        let todaysRestingSummaries = (try? await todaysRestingTask) ?? []
        let recentRestingSummaries = (try? await recentRestingTask) ?? []
        let todaysHeartRateSummaries = (try? await todaysHeartRateTask) ?? []
        let recentHeartRateSummaries = (try? await recentHeartRateTask) ?? []

        let heartRecovery = heartRecoverySignal(
            todaysRestingSummaries: todaysRestingSummaries,
            recentRestingSummaries: recentRestingSummaries,
            todaysHeartRateSummaries: todaysHeartRateSummaries,
            recentHeartRateSummaries: recentHeartRateSummaries
        )

        guard sleepData?.latestNight != nil || !todaysWorkouts.isEmpty || !yesterdaysWorkouts.isEmpty || !todaysCheckIns.isEmpty || !yesterdaysCheckIns.isEmpty || heartRecovery.hasSignal else {
            return nil
        }

        let todaysCheckInValues = todaysCheckIns.last?.values ?? [:]
        let yesterdaysCheckInValues = yesterdaysCheckIns.last?.values ?? [:]
        let latestHealthSleepScore = sleepData?.latestNight.map { sleepAggregationService.score(for: $0).totalScore }
        let previousHealthSleepScore = previousHealthSleepScore(from: sleepData)
        let latestSleepSignal = sleepScoreSignal(
            from: todaysCheckInValues,
            healthSleepScore: latestHealthSleepScore,
            nightLabel: "last night"
        )
        let previousSleepSignal = sleepScoreSignal(
            from: yesterdaysCheckInValues,
            healthSleepScore: previousHealthSleepScore,
            nightLabel: "the prior night"
        )
        let sleepScoreSignal = combinedSleepScoreSignal(
            latest: latestSleepSignal,
            previous: previousSleepSignal
        )
        let neutralSleepRecharge = neutralSleepRecharge()
        let sleepAdjustment = sleepScoreSignal.map {
            clamp($0.score * 0.52, min: 14, max: 55) - neutralSleepRecharge
        }

        let todaysStrain = clamp(
            todaysWorkouts.reduce(0.0) { $0 + workoutStrainPenalty(for: $1) },
            min: 0,
            max: 24
        )
        let carryoverStrain = clamp(
            yesterdaysWorkouts.reduce(0.0) { $0 + (workoutStrainPenalty(for: $1) * 0.45) },
            min: 0,
            max: 10
        )
        let totalStrain = todaysStrain + carryoverStrain

        let checkInAdjustment = bodyBatteryCheckInAdjustment(
            from: todaysCheckInValues,
            metrics: metricsManager.allMetrics(includeArchived: false)
        )
        let hasSleepSignal = sleepAdjustment != nil
        let hasStrainSignal = !todaysWorkouts.isEmpty || !yesterdaysWorkouts.isEmpty
        let hasHeartScoreSignal = heartRecovery.hasTodayData && heartRecovery.baselineAverage != nil
        let hasScoreableSignals = hasSleepSignal || hasStrainSignal || hasHeartScoreSignal || checkInAdjustment.hasScoringSignals
        let rawScore = hasScoreableSignals
            ? 55 + (sleepAdjustment ?? 0) + checkInAdjustment.totalAdjustment + (hasHeartScoreSignal ? heartRecovery.adjustment : 0) - (hasStrainSignal ? totalStrain : 0)
            : nil
        let score = rawScore.map { Int(clamp($0.rounded(), min: 5, max: 100)) }

        let statusTone: SQDashboardTrendTone
        let statusTitle: String
        let headline: String
        if let score {
            switch score {
            case 80...100:
                statusTone = .positive
                statusTitle = "High"
                headline = "Well charged for the day"
            case 60..<80:
                statusTone = .positive
                statusTitle = "Solid"
                headline = "Recovery is carrying you"
            case 40..<60:
                statusTone = .neutral
                statusTitle = "Moderate"
                headline = "Energy reserves are mixed"
            case 20..<40:
                statusTone = .negative
                statusTitle = "Low"
                headline = "Recovery is fading"
            default:
                statusTone = .negative
                statusTitle = "Drained"
                headline = "Recovery is under pressure"
            }
        } else {
            statusTone = .neutral
            statusTitle = "Needs Data"
            headline = "Recovery score is not ready"
        }

        return SQDashboardBodyBatteryRowViewModel(
            score: score,
            statusTitle: statusTitle,
            statusTone: statusTone,
            headline: headline,
            summary: score == nil
                ? "Track recovery check-ins or Health sleep, workout, and resting heart data to calculate this."
                : bodyBatterySummary(
                    sleepAdjustment: sleepAdjustment ?? 0,
                    totalStrain: totalStrain,
                    habitAdjustment: checkInAdjustment.totalAdjustment,
                    heartAdjustment: hasHeartScoreSignal ? heartRecovery.adjustment : 0
                ),
            drivers: [
                .init(
                    title: "Sleep",
                    valueText: sleepAdjustment.map { signedValueText(for: $0) } ?? "--",
                    detailText: sleepScoreSignal?.detailText ?? "Not included, no sleep data",
                    attributedDetailText: sleepDriverDetailText(
                        sleepScoreSignal: sleepScoreSignal,
                        sleepAdjustment: sleepAdjustment
                    ),
                    tone: sleepAdjustment.map { tone(for: $0) } ?? .neutral,
                    symbol: sleepAdjustment.flatMap { symbol(for: $0) },
                    alert: sleepAlert(
                        sleepScoreSignal: sleepScoreSignal,
                        sleepAdjustment: sleepAdjustment
                    )
                ),
                .init(
                    title: "Strain",
                    valueText: "-\(Int(totalStrain.rounded()))",
                    detailText: todaysWorkouts.isEmpty && yesterdaysWorkouts.isEmpty ? "No recent load" : "Today + carryover load",
                    attributedDetailText: strainDriverDetailText(
                        totalStrain: totalStrain,
                        todaysWorkoutsCount: todaysWorkouts.count,
                        yesterdaysWorkoutsCount: yesterdaysWorkouts.count
                    ),
                    tone: totalStrain > 8 ? .negative : .neutral,
                    symbol: totalStrain > 8 ? .arrowDown : nil,
                    alert: strainAlert(
                        totalStrain: totalStrain,
                        todaysWorkoutsCount: todaysWorkouts.count,
                        yesterdaysWorkoutsCount: yesterdaysWorkouts.count
                    )
                ),
                .init(
                    title: "Check-ins",
                    valueText: checkInAdjustment.hasScoringSignals ? signedValueText(for: checkInAdjustment.totalAdjustment) : "--",
                    detailText: checkInsDriverDetailLabel(checkInAdjustment: checkInAdjustment),
                    attributedDetailText: checkInsDriverDetailText(checkInAdjustment: checkInAdjustment),
                    tone: tone(for: checkInAdjustment.totalAdjustment),
                    symbol: symbol(for: checkInAdjustment.totalAdjustment),
                    alert: checkInsAlert(checkInAdjustment: checkInAdjustment)
                ),
                .init(
                    title: "Heart",
                    valueText: hasHeartScoreSignal ? heartRecovery.valueText : "--",
                    detailText: hasHeartScoreSignal
                        ? heartRecovery.detailText
                        : (heartRecovery.hasTodayData ? "Building resting HR baseline" : "Not included, no resting HR"),
                    attributedDetailText: hasHeartScoreSignal ? heartDriverDetailText(heartRecovery: heartRecovery) : nil,
                    tone: hasHeartScoreSignal ? heartRecovery.tone : .neutral,
                    symbol: hasHeartScoreSignal ? heartRecovery.symbol : nil,
                    alert: heartAlert(heartRecovery: heartRecovery)
                )
            ],
            formulaAlert: formulaAlert(
                score: score,
                rawScore: rawScore,
                sleepAdjustment: sleepAdjustment,
                sleepScoreSignal: sleepScoreSignal,
                checkInAdjustment: checkInAdjustment,
                heartAdjustment: hasHeartScoreSignal ? heartRecovery.adjustment : nil,
                totalStrain: hasStrainSignal ? totalStrain : nil
            ),
            dataQualityWarning: dataQualityWarning(
                score: score,
                hasSleepSignal: hasSleepSignal,
                hasHeartScoreSignal: hasHeartScoreSignal
            ),
            footer: "Estimated from sleep, resting heart rate, workout strain, and today’s recovery signals."
        )
    }

    private func workoutStrainPenalty(for workout: SQWorkoutSessionable) -> Double {
        let activeMinutes = max(0, (workout.activeDuration ?? 0) / 60)
        let caloriesPenalty = max(0, (workout.totalCalories ?? 0) / 180)
        let heartRateBonus: Double

        if let averageHeartRate = workout.plausibleAverageHeartRate {
            heartRateBonus = clamp((averageHeartRate - 130) / 18, min: 0, max: 6)
        } else {
            heartRateBonus = 0
        }

        return clamp((activeMinutes / 11) + caloriesPenalty + heartRateBonus, min: 0, max: 18)
    }

    private struct CheckInAdjustment {
        let hasPresetSignals: Bool
        let hasCustomScoringSignals: Bool
        let presetAdjustment: Double
        let customAdjustment: Double
        let customMetricTitles: [String]
        let totalAdjustment: Double

        var hasScoringSignals: Bool {
            hasPresetSignals || hasCustomScoringSignals
        }

        var hasCustomSignals: Bool {
            !customMetricTitles.isEmpty
        }
    }

    private struct SleepScoreSignal {
        let score: Double
        let detailText: String
        let formulaSourceText: String
        let alertDescription: String
    }

    private enum HeartRecoverySource {
        case restingHeartRate
        case rawHeartRateFallback

        var metricName: String {
            switch self {
            case .restingHeartRate:
                return "resting HR"
            case .rawHeartRateFallback:
                return "low heart-rate fallback"
            }
        }

        var alertDescription: String {
            switch self {
            case .restingHeartRate:
                return "Resting Heart Rate"
            case .rawHeartRateFallback:
                return "recent Heart Rate samples"
            }
        }
    }

    private struct HeartRecoverySignal {
        let adjustment: Double
        let valueText: String
        let detailText: String
        let tone: SQDashboardTrendTone
        let symbol: SQImageSymbol?
        let hasSignal: Bool
        let hasTodayData: Bool
        let baselineAverage: Double?
        let todaysAverage: Double?
        let source: HeartRecoverySource?
        let baselineSource: HeartRecoverySource?
    }

    private func sleepScoreSignal(
        from values: [String: Float],
        healthSleepScore: Double?,
        nightLabel: String
    ) -> SleepScoreSignal? {
        let sleepQuality = values[SQMetricId.sleepQuality].map { clamp(Double($0), min: 0, max: 10) }
        let sleepHours = values[SQMetricId.sleepHours].map { clamp(Double($0), min: 0, max: 24) }

        if let sleepQuality {
            let qualityScore = sleepQuality * 10

            if let sleepHours {
                let durationScore = sleepDurationScore(hours: sleepHours)
                let score = (qualityScore * 0.75) + (durationScore * 0.25)
                return .init(
                    score: score,
                    detailText: "Check-in quality + hours",
                    formulaSourceText: "Daily Check-In sleep quality and hours",
                    alertDescription: "For \(nightLabel), Daily Check-In Sleep Quality \(formatSleepValue(sleepQuality))/10 and Sleep Hours \(formatSleepValue(sleepHours))h were used. Sleep Quality carries most of the score because it is user-reported."
                )
            }

            return .init(
                score: qualityScore,
                detailText: "Check-in sleep quality",
                formulaSourceText: "Daily Check-In sleep quality",
                alertDescription: "For \(nightLabel), Daily Check-In Sleep Quality \(formatSleepValue(sleepQuality))/10 was used as the sleep source."
            )
        }

        if let healthSleepScore {
            return .init(
                score: healthSleepScore,
                detailText: "Health sleep score",
                formulaSourceText: "Health sleep score",
                alertDescription: "For \(nightLabel), Health sleep data was used because Daily Check-In Sleep Quality was not logged."
            )
        }

        if let sleepHours {
            let score = sleepDurationScore(hours: sleepHours)
            return .init(
                score: score,
                detailText: "Check-in sleep hours",
                formulaSourceText: "Daily Check-In sleep hours",
                alertDescription: "For \(nightLabel), Daily Check-In Sleep Hours \(formatSleepValue(sleepHours))h was used because Sleep Quality and Health sleep data were not available."
            )
        }

        return nil
    }

    private func combinedSleepScoreSignal(
        latest: SleepScoreSignal?,
        previous: SleepScoreSignal?
    ) -> SleepScoreSignal? {
        guard let latest else { return previous }
        guard let previous else { return latest }

        let score = (latest.score * 0.70) + (previous.score * 0.30)

        return .init(
            score: score,
            detailText: "Last 2 nights",
            formulaSourceText: "70% last night, 30% prior night",
            alertDescription: "\(latest.alertDescription) \(previous.alertDescription) Recovery Score weights sleep as 70% last night and 30% the prior night so consecutive good or bad nights can stack."
        )
    }

    private func previousHealthSleepScore(from sleepData: SQSleepDashboardData?) -> Double? {
        let nights = ((sleepData?.currentNights ?? []) + (sleepData?.priorNights ?? []))
            .sorted { $0.wakeDay > $1.wakeDay }

        guard nights.count > 1 else { return nil }
        return sleepAggregationService.score(for: nights[1]).totalScore
    }

    private func sleepDurationScore(hours: Double) -> Double {
        if hours >= 7, hours <= 9 {
            return 100
        }

        if hours < 7 {
            return clamp(100 - ((7 - hours) * 18), min: 0, max: 100)
        }

        return clamp(100 - ((hours - 9) * 12), min: 0, max: 100)
    }

    private func formatSleepValue(_ value: Double) -> String {
        let rounded = (value * 10).rounded() / 10
        if rounded == rounded.rounded() {
            return "\(Int(rounded))"
        }

        return String(format: "%.1f", rounded)
    }

    private func bodyBatteryPresetAdjustment(from values: [String: Float]) -> Double {
        let energyBoost = values[SQMetricId.energy].map { clamp((Double($0) - 5.5) * 1.5, min: -7, max: 7) } ?? 0
        let recoveryBoost = values[SQMetricId.soreness].map { clamp((Double($0) - 5.0) * 1.2, min: -6, max: 6) } ?? 0
        let nutritionBoost = values[SQMetricId.nutrition].map { clamp((Double($0) - 5.0) * 0.7, min: 0, max: 4) } ?? 0
        let alcoholPenalty = values[SQMetricId.alcohol].map { clamp(Double($0) * 1.5, min: 0, max: 12) } ?? 0
        let caffeinePenalty = values[SQMetricId.caffeine].map { clamp((Double($0) - 6.0) * 0.8, min: 0, max: 4) } ?? 0

        return clamp(
            energyBoost + recoveryBoost + nutritionBoost - alcoholPenalty - caffeinePenalty,
            min: -16,
            max: 10
        )
    }

    private func bodyBatteryCheckInAdjustment(
        from values: [String: Float],
        metrics: [SQMetricDefinition]
    ) -> CheckInAdjustment {
        let presetSignalIds = [
            SQMetricId.energy,
            SQMetricId.soreness,
            SQMetricId.nutrition,
            SQMetricId.alcohol,
            SQMetricId.caffeine
        ]
        let hasPresetSignals = presetSignalIds.contains { values[$0] != nil }
        let presetAdjustment = bodyBatteryPresetAdjustment(from: values)
        let hasCustomScoringSignals = metrics.contains { metric in
            guard !metric.isPreset else { return false }
            guard metric.bodyBatteryEffect != .none, metric.bodyBatteryEffect != .unknown else { return false }
            return values[metric.id] != nil
        }

        let customSignals = metrics.compactMap { metric -> (title: String, adjustment: Double)? in
            guard !metric.isPreset else { return nil }
            guard metric.bodyBatteryEffect != .none, metric.bodyBatteryEffect != .unknown else { return nil }
            guard let value = values[metric.id] else { return nil }
            guard let adjustment = customMetricAdjustment(for: metric, value: value) else { return nil }
            guard adjustment != 0 else { return nil }
            return (metric.title, adjustment)
        }

        let rawCustomAdjustment = customSignals.reduce(0.0) { $0 + $1.adjustment }
        let customAdjustment = clamp(rawCustomAdjustment, min: -6, max: 6)

        return .init(
            hasPresetSignals: hasPresetSignals,
            hasCustomScoringSignals: hasCustomScoringSignals,
            presetAdjustment: presetAdjustment,
            customAdjustment: customAdjustment,
            customMetricTitles: customSignals.map(\.title),
            totalAdjustment: clamp(presetAdjustment + customAdjustment, min: -18, max: 12)
        )
    }

    private func customMetricAdjustment(for metric: SQMetricDefinition, value: Float) -> Double? {
        guard let min = metric.min, let max = metric.max, max > min else {
            return nil
        }

        let normalized = clamp(
            (Double(value) - Double(min)) / Double(max - min),
            min: 0,
            max: 1
        )
        let centered = (normalized - 0.5) * 2

        switch metric.bodyBatteryEffect {
        case .boostsWhenHigh:
            return clamp(centered * 2, min: -2, max: 2)
        case .drainsWhenHigh:
            return clamp(-centered * 2, min: -2, max: 2)
        case .none, .unknown:
            return nil
        }
    }

    private func bodyBatterySummary(
        sleepAdjustment: Double,
        totalStrain: Double,
        habitAdjustment: Double,
        heartAdjustment: Double
    ) -> String {
        if sleepAdjustment >= 10 && totalStrain <= 8 && habitAdjustment >= 0 {
            return "Strong overnight recovery is keeping your energy reserves high right now."
        }

        if heartAdjustment <= -5 {
            return "Resting heart rate is running above your recent baseline, which usually signals extra stress or incomplete recovery."
        }

        if totalStrain >= 16 {
            return "Recent training load is draining the battery faster than your recovery is rebuilding it."
        }

        if heartAdjustment >= 4 {
            return "Resting heart rate is calmer than your recent baseline, which is helping preserve your battery today."
        }

        if habitAdjustment <= -6 {
            return "Today’s recovery signals are dragging the score down from its neutral baseline."
        }

        if habitAdjustment >= 6 {
            return "Good energy and recovery check-ins are helping preserve your battery through the day."
        }

        return "Sleep, strain, and daily recovery signals are fairly balanced right now."
    }

    private func heartRecoverySignal(
        todaysRestingSummaries: [SQHeartRateDailySummary],
        recentRestingSummaries: [SQHeartRateDailySummary],
        todaysHeartRateSummaries: [SQHeartRateDailySummary],
        recentHeartRateSummaries: [SQHeartRateDailySummary]
    ) -> HeartRecoverySignal {
        let calendar = Calendar.current
        let todayStart = calendar.startOfDay(for: .now)

        let todaysOfficialAverage = todaysRestingSummaries
            .last(where: { calendar.isDate($0.date, inSameDayAs: todayStart) })?
            .average
        let todaysFallbackAverage = todaysHeartRateSummaries
            .last(where: { calendar.isDate($0.date, inSameDayAs: todayStart) })
            .flatMap(heartRateFallbackValue)

        let todaysAverage = todaysOfficialAverage ?? todaysFallbackAverage
        let todaysSource: HeartRecoverySource? = todaysOfficialAverage != nil
            ? .restingHeartRate
            : (todaysFallbackAverage != nil ? .rawHeartRateFallback : nil)

        let officialBaselineValues = recentRestingSummaries
            .filter { !calendar.isDate($0.date, inSameDayAs: todayStart) }
            .compactMap(\.average)
        let fallbackBaselineValues = recentHeartRateSummaries
            .filter { !calendar.isDate($0.date, inSameDayAs: todayStart) }
            .compactMap(heartRateFallbackValue)
        let baselineValues = todaysSource == .rawHeartRateFallback
            ? (!fallbackBaselineValues.isEmpty ? fallbackBaselineValues : officialBaselineValues)
            : (!officialBaselineValues.isEmpty ? officialBaselineValues : fallbackBaselineValues)
        let baselineAverage = baselineValues.average
        let baselineSource: HeartRecoverySource?
        if todaysSource == .rawHeartRateFallback {
            baselineSource = !fallbackBaselineValues.isEmpty ? .rawHeartRateFallback : (!officialBaselineValues.isEmpty ? .restingHeartRate : nil)
        } else {
            baselineSource = !officialBaselineValues.isEmpty ? .restingHeartRate : (!fallbackBaselineValues.isEmpty ? .rawHeartRateFallback : nil)
        }

        guard let todaysAverage else {
            if let baselineAverage {
                return HeartRecoverySignal(
                    adjustment: 0,
                    valueText: "--",
                    detailText: "Waiting for today’s heart data. 7d baseline \(Int(baselineAverage.rounded())) bpm",
                    tone: .neutral,
                    symbol: nil,
                    hasSignal: true,
                    hasTodayData: false,
                    baselineAverage: baselineAverage,
                    todaysAverage: nil,
                    source: nil,
                    baselineSource: baselineSource
                )
            }

            return HeartRecoverySignal(
                adjustment: 0,
                valueText: "--",
                detailText: "Awaiting resting heart data",
                tone: .neutral,
                symbol: nil,
                hasSignal: false,
                hasTodayData: false,
                baselineAverage: nil,
                todaysAverage: nil,
                source: nil,
                baselineSource: nil
            )
        }

        guard let baselineAverage else {
            return HeartRecoverySignal(
                adjustment: 0,
                valueText: "\(Int(todaysAverage.rounded())) bpm",
                detailText: "\(todaysSource?.metricName.capitalized ?? "Heart rate") today",
                tone: .neutral,
                symbol: nil,
                hasSignal: true,
                hasTodayData: true,
                baselineAverage: nil,
                todaysAverage: todaysAverage,
                source: todaysSource,
                baselineSource: nil
            )
        }

        let delta = baselineAverage - todaysAverage
        let adjustment = clamp(delta * 1.4, min: -10, max: 8)
        let roundedDelta = Int(abs(delta).rounded())
        let detailDirection = delta >= 0 ? "below" : "above"
        let sourceText = todaysSource?.metricName ?? "heart rate"

        return HeartRecoverySignal(
            adjustment: adjustment,
            valueText: signedValueText(for: adjustment),
            detailText: "\(Int(todaysAverage.rounded())) bpm \(sourceText), \(roundedDelta) \(detailDirection) baseline",
            tone: tone(for: adjustment),
            symbol: symbol(for: adjustment),
            hasSignal: true,
            hasTodayData: true,
            baselineAverage: baselineAverage,
            todaysAverage: todaysAverage,
            source: todaysSource,
            baselineSource: baselineSource
        )
    }

    private func heartRateFallbackValue(from summary: SQHeartRateDailySummary) -> Double? {
        if let minimum = summary.minimum, (35...120).contains(minimum) {
            return minimum
        }

        if let average = summary.average, (35...120).contains(average) {
            return average
        }

        return nil
    }

    private func sleepAlert(sleepScoreSignal: SleepScoreSignal?, sleepAdjustment: Double?) -> SQAlertViewModel {
        let subtitle: String
        let attributedSubtitle: AttributedString
        if let sleepScoreSignal, let sleepAdjustment {
            subtitle = "\(sleepScoreSignal.alertDescription) This produced a sleep score of \(Int(sleepScoreSignal.score.rounded())) and changed Recovery Score by \(signedValueText(for: sleepAdjustment)) point(s) versus the neutral baseline."
            attributedSubtitle = buildBodyBatteryText([
                .plain(sleepScoreSignal.alertDescription),
                .plain(" This produced a sleep score of "),
                .highlight("\(Int(sleepScoreSignal.score.rounded()))"),
                .plain(" and changed Recovery Score by "),
                .highlight(signedValueText(for: sleepAdjustment)),
                .plain(" point(s) versus the neutral baseline.")
            ])
        } else {
            subtitle = "No Daily Check-In or Health sleep data is available yet, so sleep is omitted from the Recovery Score calculation instead of being treated as good or bad."
            attributedSubtitle = buildBodyBatteryText([
                .plain("No Daily Check-In or Health sleep data is available yet, so sleep is "),
                .highlight("omitted"),
                .plain(" from the Recovery Score calculation instead of being treated as good or bad.")
            ])
        }

        return .init(
            title: "Sleep",
            subtitle: subtitle,
            attributedSubtitle: attributedSubtitle,
            primary: .ok,
            canDismiss: true
        )
    }

    private func formulaAlert(
        score: Int?,
        rawScore: Double?,
        sleepAdjustment: Double?,
        sleepScoreSignal: SleepScoreSignal?,
        checkInAdjustment: CheckInAdjustment,
        heartAdjustment: Double?,
        totalStrain: Double?
    ) -> SQAlertViewModel {
        guard let score, let rawScore else {
            let subtitle = "Recovery Score needs at least one scoreable signal before it can calculate. Log Sleep Quality, Sleep Hours, Energy, or Recovery in Daily Check-In, add a custom metric marked for Recovery Score, or record Health sleep, workout, and resting heart data."
            let attributedSubtitle = buildBodyBatteryText([
                .plain("Recovery Score needs at least "),
                .highlight("one scoreable signal"),
                .plain(" before it can calculate. Log "),
                .highlight("Sleep Quality"),
                .plain(", "),
                .highlight("Sleep Hours"),
                .plain(", "),
                .highlight("Energy"),
                .plain(", or "),
                .highlight("Recovery"),
                .plain(" in Daily Check-In, add a custom metric marked for Recovery Score, or record Health "),
                .highlight("sleep"),
                .plain(", "),
                .highlight("workout"),
                .plain(", and "),
                .highlight("resting heart"),
                .plain(" data.")
            ])

            return .init(
                title: "How Recovery Score Is Calculated",
                subtitle: subtitle,
                attributedSubtitle: attributedSubtitle,
                primary: .ok,
                canDismiss: true
            )
        }

        let roundedRawScore = Int(rawScore.rounded())
        let activeTerms = activeFormulaTerms(
            sleepAdjustment: sleepAdjustment,
            checkInAdjustment: checkInAdjustment,
            heartAdjustment: heartAdjustment,
            totalStrain: totalStrain
        )
        let omittedSignals = omittedFormulaSignals(
            sleepAdjustment: sleepAdjustment,
            checkInAdjustment: checkInAdjustment,
            heartAdjustment: heartAdjustment,
            totalStrain: totalStrain
        )
        let calculationText = "55 baseline \(activeTerms.map(\.formulaText).joined(separator: " "))"
        let sleepSourceText = sleepScoreSignal.map { "Sleep source: \($0.formulaSourceText)." } ?? ""
        let omittedText = omittedSignals.isEmpty
            ? "No signals were omitted."
            : "Omitted due to missing data: \(omittedSignals.joined(separator: ", "))."
        let subtitle = """
        Recovery Score starts from a neutral baseline and then adjusts based on the signals available today. Current calculation: \(calculationText) = \(roundedRawScore). Your current score is \(score). \(sleepSourceText) \(omittedText) Check-ins use Energy, Recovery, Nutrition, Alcohol, Caffeine, and custom metrics marked for Recovery Score.
        """
        let attributedSubtitle = buildBodyBatteryText([
            .highlight("Recovery Score"),
            .plain(" starts from a "),
            .highlight("55 neutral baseline"),
            .plain(" and then adjusts based on the signals available today. Current calculation: "),
            .highlight(calculationText),
            .plain(" = "),
            .highlight("\(roundedRawScore)"),
            .plain(". Your current score is "),
            .highlight("\(score)"),
            .plain(". "),
            .highlight(sleepSourceText),
            .plain(" "),
            .highlight(omittedText),
            .plain(" Check-ins use "),
            .highlight("Energy"),
            .plain(", "),
            .highlight("Recovery"),
            .plain(", "),
            .highlight("Nutrition"),
            .plain(", "),
            .highlight("Alcohol"),
            .plain(", "),
            .highlight("Caffeine"),
            .plain(", and custom metrics marked for Recovery Score.")
        ])

        return .init(
            title: "How Recovery Score Is Calculated",
            subtitle: subtitle,
            attributedSubtitle: attributedSubtitle,
            primary: .ok,
            canDismiss: true
        )
    }

    private func activeFormulaTerms(
        sleepAdjustment: Double?,
        checkInAdjustment: CheckInAdjustment,
        heartAdjustment: Double?,
        totalStrain: Double?
    ) -> [(label: String, formulaText: String)] {
        var terms: [(label: String, formulaText: String)] = []

        if let sleepAdjustment {
            terms.append(("sleep", labeledFormulaAdjustmentText(for: sleepAdjustment, label: "sleep")))
        }

        if checkInAdjustment.hasScoringSignals {
            terms.append(("check-ins", labeledFormulaAdjustmentText(for: checkInAdjustment.totalAdjustment, label: "check-ins")))
        }

        if let heartAdjustment {
            terms.append(("heart", labeledFormulaAdjustmentText(for: heartAdjustment, label: "heart")))
        }

        if let totalStrain {
            terms.append(("strain", "- \(Int(totalStrain.rounded())) strain"))
        }

        return terms
    }

    private func omittedFormulaSignals(
        sleepAdjustment: Double?,
        checkInAdjustment: CheckInAdjustment,
        heartAdjustment: Double?,
        totalStrain: Double?
    ) -> [String] {
        var signals: [String] = []

        if sleepAdjustment == nil {
            signals.append("sleep")
        }

        if !checkInAdjustment.hasScoringSignals {
            signals.append("check-ins")
        }

        if heartAdjustment == nil {
            signals.append("heart")
        }

        if totalStrain == nil {
            signals.append("strain")
        }

        return signals
    }

    private func dataQualityWarning(
        score: Int?,
        hasSleepSignal: Bool,
        hasHeartScoreSignal: Bool
    ) -> String? {
        guard score != nil else {
            return "Not enough recovery data yet. Log Sleep Quality, Sleep Hours, Energy, or Recovery in Daily Check-In, or record Health sleep and resting heart data."
        }

        guard !hasSleepSignal || !hasHeartScoreSignal else { return nil }

        if !hasSleepSignal && !hasHeartScoreSignal {
            return "Limited accuracy: sleep and resting heart data are missing, so this score is based only on the signals available today."
        }

        if !hasSleepSignal {
            return "Limited accuracy: Health sleep data is missing, so sleep is omitted from this score."
        }

        return nil
    }

    private func neutralSleepRecharge() -> Double {
        clamp(52 * 0.52, min: 14, max: 55)
    }

    private func strainAlert(
        totalStrain: Double,
        todaysWorkoutsCount: Int,
        yesterdaysWorkoutsCount: Int
    ) -> SQAlertViewModel {
        let subtitle = "Strain lowers Recovery Score based on recent workout duration, calories, and workout heart rate. Right now that penalty is \(Int(totalStrain.rounded())) points across \(todaysWorkoutsCount) workout(s) today and \(yesterdaysWorkoutsCount) yesterday."
        let attributedSubtitle = buildBodyBatteryText([
            .plain("Strain lowers Recovery Score based on recent workout duration, calories, and workout heart rate. Right now that penalty is "),
            .highlight("\(Int(totalStrain.rounded()))"),
            .plain(" points across "),
            .highlight("\(todaysWorkoutsCount)"),
            .plain(" workout(s) today and "),
            .highlight("\(yesterdaysWorkoutsCount)"),
            .plain(" yesterday.")
        ])

        return .init(
            title: "Workout Strain",
            subtitle: subtitle,
            attributedSubtitle: attributedSubtitle,
            primary: .ok,
            canDismiss: true
        )
    }

    private func checkInsAlert(checkInAdjustment: CheckInAdjustment) -> SQAlertViewModel {
        let customSummary = customMetricSummary(for: checkInAdjustment.customMetricTitles)
        let subtitle: String
        let attributedSubtitle: AttributedString

        if !checkInAdjustment.hasScoringSignals {
            subtitle = "Check-ins are omitted from Recovery Score until you log at least one recovery-related metric. Built-in signals include Energy, Recovery, Nutrition, Alcohol, and Caffeine. Custom metrics count when they are marked for Recovery Score."
            attributedSubtitle = buildBodyBatteryText([
                .plain("Check-ins are "),
                .highlight("omitted"),
                .plain(" from Recovery Score until you log at least one recovery-related metric. Built-in signals include "),
                .highlight("Energy"),
                .plain(", "),
                .highlight("Recovery"),
                .plain(", "),
                .highlight("Nutrition"),
                .plain(", "),
                .highlight("Alcohol"),
                .plain(", and "),
                .highlight("Caffeine"),
                .plain(". Custom metrics count when they are marked for Recovery Score.")
            ])
        } else if let customSummary {
            subtitle = "Check-ins adjust Recovery Score using Energy, Recovery, Nutrition, Alcohol, Caffeine, and custom metrics like \(customSummary). Today those signals changed the score by \(signedValueText(for: checkInAdjustment.totalAdjustment)) point(s). Custom metric impact is capped so those signals stay supportive instead of dominating the score."
            attributedSubtitle = buildBodyBatteryText([
                .plain("Check-ins adjust Recovery Score using "),
                .highlight("Energy"),
                .plain(", "),
                .highlight("Recovery"),
                .plain(", "),
                .highlight("Nutrition"),
                .plain(", "),
                .highlight("Alcohol"),
                .plain(", "),
                .highlight("Caffeine"),
                .plain(", and custom metrics like "),
                .highlight(customSummary),
                .plain(". Today those signals changed the score by "),
                .highlight(signedValueText(for: checkInAdjustment.totalAdjustment)),
                .plain(" point(s). Custom metric impact is "),
                .highlight("capped"),
                .plain(" so those signals stay supportive instead of dominating the score.")
            ])
        } else {
            subtitle = "Check-ins adjust Recovery Score using Energy, Recovery, Nutrition, Alcohol, and Caffeine. Today those signals changed the score by \(signedValueText(for: checkInAdjustment.totalAdjustment)) point(s)."
            attributedSubtitle = buildBodyBatteryText([
                .plain("Check-ins adjust Recovery Score using "),
                .highlight("Energy"),
                .plain(", "),
                .highlight("Recovery"),
                .plain(", "),
                .highlight("Nutrition"),
                .plain(", "),
                .highlight("Alcohol"),
                .plain(", and "),
                .highlight("Caffeine"),
                .plain(". Today those signals changed the score by "),
                .highlight(signedValueText(for: checkInAdjustment.totalAdjustment)),
                .plain(" point(s).")
            ])
        }

        return .init(
            title: "Recovery Signals",
            subtitle: subtitle,
            attributedSubtitle: attributedSubtitle,
            primary: .ok,
            canDismiss: true
        )
    }

    private func heartAlert(heartRecovery: HeartRecoverySignal) -> SQAlertViewModel {
        let subtitle: String
        let attributedSubtitle: AttributedString

        if !heartRecovery.hasSignal {
            subtitle = "Recovery Score can use Resting Heart Rate when Health has it. When it is missing, LifeIQ can fall back to low raw Heart Rate readings from Health to estimate a resting-ish recovery signal."
            attributedSubtitle = buildBodyBatteryText([
                .plain("Recovery Score can use "),
                .highlight("Resting Heart Rate"),
                .plain(" when Health has it. When it is missing, LifeIQ can fall back to low raw "),
                .highlight("Heart Rate"),
                .plain(" readings from Health to estimate a resting-ish recovery signal.")
            ])
        } else if !heartRecovery.hasTodayData {
            let baselineText = heartRecovery.baselineAverage.map { "\(Int($0.rounded())) bpm" } ?? "your recent baseline"
            let baselineSourceText = heartRecovery.baselineSource?.alertDescription ?? "heart data"
            subtitle = "We have a recent baseline of \(baselineText) from \(baselineSourceText), but not enough heart data for today yet. Apple Watch may record Heart Rate before it produces an official Resting Heart Rate value."
            attributedSubtitle = buildBodyBatteryText([
                .plain("We have a recent baseline of "),
                .highlight(baselineText),
                .plain(" from "),
                .highlight(baselineSourceText),
                .plain(", but not enough heart data for today yet. Apple Watch may record "),
                .highlight("Heart Rate"),
                .plain(" before it produces an official "),
                .highlight("Resting Heart Rate"),
                .plain(" value.")
            ])
        } else if let todaysAverage = heartRecovery.todaysAverage, let baselineAverage = heartRecovery.baselineAverage {
            let sourceText = heartRecovery.source?.alertDescription ?? "heart data"
            let baselineSourceText = heartRecovery.baselineSource?.alertDescription ?? "recent heart data"
            subtitle = "Heart recovery uses \(sourceText). Today is \(Int(todaysAverage.rounded())) bpm versus a recent baseline of \(Int(baselineAverage.rounded())) bpm. Lower-than-baseline values boost Recovery Score, while higher values lower it."
            attributedSubtitle = buildBodyBatteryText([
                .plain("Heart recovery uses "),
                .highlight(sourceText),
                .plain(". Today is "),
                .highlight("\(Int(todaysAverage.rounded())) bpm"),
                .plain(" versus a recent baseline of "),
                .highlight("\(Int(baselineAverage.rounded())) bpm"),
                .plain(". Lower-than-baseline values boost Recovery Score, while higher values lower it.")
            ])
        } else if let todaysAverage = heartRecovery.todaysAverage {
            let sourceText = heartRecovery.source?.alertDescription ?? "heart data"
            subtitle = "Today’s heart value is \(Int(todaysAverage.rounded())) bpm from \(sourceText). Once more history is available, Recovery Score will compare that value against your recent baseline."
            attributedSubtitle = buildBodyBatteryText([
                .plain("Today’s heart value is "),
                .highlight("\(Int(todaysAverage.rounded())) bpm"),
                .plain(" from "),
                .highlight(sourceText),
                .plain(". Once more history is available, Recovery Score will compare that value against your recent baseline.")
            ])
        } else {
            subtitle = "Heart data is used as a recovery signal inside Recovery Score when enough Resting Heart Rate or low raw Heart Rate data is available."
            attributedSubtitle = buildBodyBatteryText([
                .highlight("Heart data"),
                .plain(" is used as a recovery signal inside Recovery Score when enough "),
                .highlight("Resting Heart Rate"),
                .plain(" or low raw "),
                .highlight("Heart Rate"),
                .plain(" data is available.")
            ])
        }

        return .init(
            title: "Heart Recovery",
            subtitle: subtitle,
            attributedSubtitle: attributedSubtitle,
            primary: .ok,
            canDismiss: true
        )
    }

    private func sleepDriverDetailText(
        sleepScoreSignal: SleepScoreSignal?,
        sleepAdjustment: Double?
    ) -> AttributedString? {
        guard let sleepScoreSignal, let sleepAdjustment else { return nil }

        return buildBodyBatteryText([
            .plain("Sleep Score "),
            .highlight("\(Int(sleepScoreSignal.score.rounded()))"),
            .plain(" from "),
            .highlight(sleepScoreSignal.formulaSourceText),
            .plain(" changed score by "),
            .highlight(signedValueText(for: sleepAdjustment))
        ])
    }

    private func strainDriverDetailText(
        totalStrain: Double,
        todaysWorkoutsCount: Int,
        yesterdaysWorkoutsCount: Int
    ) -> AttributedString? {
        guard todaysWorkoutsCount > 0 || yesterdaysWorkoutsCount > 0 else { return nil }

        return buildBodyBatteryText([
            .highlight("\(Int(totalStrain.rounded())) pts"),
            .plain(" from "),
            .highlight("\(todaysWorkoutsCount)"),
            .plain(" today, "),
            .highlight("\(yesterdaysWorkoutsCount)"),
            .plain(" yesterday")
        ])
    }

    private func checkInsDriverDetailLabel(checkInAdjustment: CheckInAdjustment) -> String {
        guard checkInAdjustment.hasScoringSignals else {
            return "No recovery metrics logged"
        }

        if checkInAdjustment.hasCustomSignals {
            return "Recovery + \(checkInAdjustment.customMetricTitles.count) custom"
        }

        if checkInAdjustment.totalAdjustment == 0 {
            return "No strong recovery signal"
        }

        return "Energy, Recovery, habits"
    }

    private func checkInsDriverDetailText(checkInAdjustment: CheckInAdjustment) -> AttributedString? {
        if checkInAdjustment.hasCustomSignals {
            return buildBodyBatteryText([
                .highlight(signedValueText(for: checkInAdjustment.totalAdjustment)),
                .plain(" from "),
                .highlight("\(checkInAdjustment.customMetricTitles.count)"),
                .plain(" custom + preset signals")
            ])
        }

        guard checkInAdjustment.totalAdjustment != 0 else { return nil }

        return buildBodyBatteryText([
            .highlight(signedValueText(for: checkInAdjustment.totalAdjustment)),
            .plain(" from today's recovery signals")
        ])
    }

    private func customMetricSummary(for titles: [String]) -> String? {
        guard !titles.isEmpty else { return nil }
        if titles.count == 1 {
            return titles[0]
        }
        if titles.count == 2 {
            return "\(titles[0]) and \(titles[1])"
        }

        let visibleTitles = titles.prefix(2)
        let remainingCount = titles.count - visibleTitles.count
        return "\(visibleTitles.joined(separator: ", ")), and \(remainingCount) more"
    }

    private func heartDriverDetailText(heartRecovery: HeartRecoverySignal) -> AttributedString? {
        if let todaysAverage = heartRecovery.todaysAverage, let baselineAverage = heartRecovery.baselineAverage {
            let delta = Int(abs(todaysAverage - baselineAverage).rounded())
            let direction = todaysAverage <= baselineAverage ? "below" : "above"
            let sourceText = heartRecovery.source?.metricName ?? "heart"

            return buildBodyBatteryText([
                .highlight("\(Int(todaysAverage.rounded())) bpm"),
                .plain(" \(sourceText), "),
                .highlight("\(delta)"),
                .plain(" \(direction) baseline")
            ])
        }

        if let baselineAverage = heartRecovery.baselineAverage, !heartRecovery.hasTodayData {
            return buildBodyBatteryText([
                .plain("Waiting for today. "),
                .highlight("7d baseline \(Int(baselineAverage.rounded())) bpm")
            ])
        }

        if let todaysAverage = heartRecovery.todaysAverage {
            let sourceText = heartRecovery.source?.metricName ?? "heart"
            return buildBodyBatteryText([
                .highlight("\(Int(todaysAverage.rounded())) bpm"),
                .plain(" \(sourceText) today")
            ])
        }

        return nil
    }

    private enum BodyBatteryTextSegment {
        case plain(String)
        case highlight(String)
    }

    private func buildBodyBatteryText(_ segments: [BodyBatteryTextSegment]) -> AttributedString {
        segments.reduce(into: AttributedString()) { result, segment in
            switch segment {
            case .plain(let text):
                result += AttributedString.build(with: text, color: SQColor.textSecondary.color)
            case .highlight(let text):
                result += AttributedString.build(with: text, color: SQColor.dashboardGlowBlue.color)
            }
        }
    }

    private func signedValueText(for value: Double) -> String {
        let rounded = Int(value.rounded())
        if rounded > 0 {
            return "+\(rounded)"
        }
        return "\(rounded)"
    }

    private func formulaAdjustmentText(for value: Double) -> String {
        let rounded = Int(value.rounded())
        if rounded < 0 {
            return "- \(abs(rounded))"
        }

        return "+ \(rounded)"
    }

    private func labeledFormulaAdjustmentText(for value: Double, label: String) -> String {
        "\(formulaAdjustmentText(for: value)) \(label)"
    }

    private func tone(for value: Double) -> SQDashboardTrendTone {
        if value > 0 {
            return .positive
        } else if value < 0 {
            return .negative
        }
        return .neutral
    }

    private func symbol(for value: Double) -> SQImageSymbol? {
        if value > 0 {
            return .arrowUp
        } else if value < 0 {
            return .arrowDown
        }
        return nil
    }

    private func clamp(_ value: Double, min minValue: Double, max maxValue: Double) -> Double {
        Swift.max(minValue, Swift.min(maxValue, value))
    }
}

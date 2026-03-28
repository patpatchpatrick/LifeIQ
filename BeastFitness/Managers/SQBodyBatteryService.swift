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
    private let metricsManager: SQMetricsManaging
    private let sleepAggregationService: SQSleepAggregationService
    private let healthKitManager: SQHealthKitManaging

    init(
        metricEntryManager: SQMetricEntryManaging,
        metricsManager: SQMetricsManaging = SQMetricsManager.shared,
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
        async let todaysRestingTask = healthKitManager.fetchDailyRestingHeartRateSummaries(.today)
        async let recentRestingTask = healthKitManager.fetchDailyRestingHeartRateSummaries(.pastWeek)

        let todaysCheckIns = try await todaysCheckInsTask
        let todaysRestingSummaries = try await todaysRestingTask
        let recentRestingSummaries = try await recentRestingTask

        let heartRecovery = heartRecoverySignal(
            todaysRestingSummaries: todaysRestingSummaries,
            recentRestingSummaries: recentRestingSummaries
        )

        guard sleepData?.latestNight != nil || !todaysWorkouts.isEmpty || !yesterdaysWorkouts.isEmpty || !todaysCheckIns.isEmpty || heartRecovery.hasSignal else {
            return nil
        }

        let latestSleepScore = sleepData?.latestNight.map { sleepAggregationService.score(for: $0).totalScore }
        let sleepRecharge = clamp(
            (latestSleepScore ?? 52) * 0.52,
            min: 14,
            max: 55
        )

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

        let todaysCheckInValues = todaysCheckIns.last?.values ?? [:]
        let checkInAdjustment = bodyBatteryCheckInAdjustment(
            from: todaysCheckInValues,
            metrics: metricsManager.allMetrics(includeArchived: false)
        )
        let rawScore = 28 + sleepRecharge + checkInAdjustment.totalAdjustment + heartRecovery.adjustment - totalStrain
        let score = Int(clamp(rawScore.rounded(), min: 5, max: 100))

        let statusTone: SQDashboardTrendTone
        let statusTitle: String
        let headline: String
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
            headline = "Battery is running low"
        default:
            statusTone = .negative
            statusTitle = "Drained"
            headline = "Recovery is under pressure"
        }

        return SQDashboardBodyBatteryRowViewModel(
            score: score,
            statusTitle: statusTitle,
            statusTone: statusTone,
            headline: headline,
            summary: bodyBatterySummary(
                sleepRecharge: sleepRecharge,
                totalStrain: totalStrain,
                habitAdjustment: checkInAdjustment.totalAdjustment,
                heartAdjustment: heartRecovery.adjustment
            ),
            drivers: [
                .init(
                    title: "Sleep",
                    valueText: "+\(Int(sleepRecharge.rounded()))",
                    detailText: latestSleepScore == nil ? "Awaiting sleep data" : "Recharge from last night",
                    attributedDetailText: sleepDriverDetailText(
                        latestSleepScore: latestSleepScore,
                        sleepRecharge: sleepRecharge
                    ),
                    tone: .positive,
                    symbol: .arrowUp,
                    alert: sleepAlert(latestSleepScore: latestSleepScore, sleepRecharge: sleepRecharge)
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
                    valueText: signedValueText(for: checkInAdjustment.totalAdjustment),
                    detailText: checkInsDriverDetailLabel(checkInAdjustment: checkInAdjustment),
                    attributedDetailText: checkInsDriverDetailText(checkInAdjustment: checkInAdjustment),
                    tone: tone(for: checkInAdjustment.totalAdjustment),
                    symbol: symbol(for: checkInAdjustment.totalAdjustment),
                    alert: checkInsAlert(checkInAdjustment: checkInAdjustment)
                ),
                .init(
                    title: "Heart",
                    valueText: heartRecovery.valueText,
                    detailText: heartRecovery.detailText,
                    attributedDetailText: heartDriverDetailText(heartRecovery: heartRecovery),
                    tone: heartRecovery.tone,
                    symbol: heartRecovery.symbol,
                    alert: heartAlert(heartRecovery: heartRecovery)
                )
            ],
            footer: "Estimated from last night’s sleep, resting heart rate, current workout strain, and today’s recovery signals."
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
        let presetAdjustment: Double
        let customAdjustment: Double
        let customMetricTitles: [String]
        let totalAdjustment: Double

        var hasCustomSignals: Bool {
            !customMetricTitles.isEmpty
        }
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
        let presetAdjustment = bodyBatteryPresetAdjustment(from: values)

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
        sleepRecharge: Double,
        totalStrain: Double,
        habitAdjustment: Double,
        heartAdjustment: Double
    ) -> String {
        if sleepRecharge >= 38 && totalStrain <= 8 && habitAdjustment >= 0 {
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
            return "Today’s recovery signals are dragging the battery down despite your baseline recharge."
        }

        if habitAdjustment >= 6 {
            return "Good energy and recovery check-ins are helping preserve your battery through the day."
        }

        return "Sleep, strain, and daily recovery signals are fairly balanced right now."
    }

    private func heartRecoverySignal(
        todaysRestingSummaries: [SQHeartRateDailySummary],
        recentRestingSummaries: [SQHeartRateDailySummary]
    ) -> (adjustment: Double, valueText: String, detailText: String, tone: SQDashboardTrendTone, symbol: SQImageSymbol?, hasSignal: Bool, hasTodayData: Bool, baselineAverage: Double?, todaysAverage: Double?) {
        let calendar = Calendar.current
        let todayStart = calendar.startOfDay(for: .now)

        let todaysAverage = todaysRestingSummaries
            .last(where: { calendar.isDate($0.date, inSameDayAs: todayStart) })?
            .average
        let baselineValues = recentRestingSummaries
            .filter { !calendar.isDate($0.date, inSameDayAs: todayStart) }
            .compactMap(\.average)
        let baselineAverage = baselineValues.average

        guard let todaysAverage else {
            if let baselineAverage {
                return (
                    adjustment: 0,
                    valueText: "--",
                    detailText: "Waiting for today’s resting HR. 7d baseline \(Int(baselineAverage.rounded())) bpm",
                    tone: .neutral,
                    symbol: nil,
                    hasSignal: true,
                    hasTodayData: false,
                    baselineAverage: baselineAverage,
                    todaysAverage: nil
                )
            }

            return (
                adjustment: 0,
                valueText: "--",
                detailText: "Awaiting resting heart data",
                tone: .neutral,
                symbol: nil,
                hasSignal: false,
                hasTodayData: false,
                baselineAverage: nil,
                todaysAverage: nil
            )
        }

        guard let baselineAverage else {
            return (
                adjustment: 0,
                valueText: "\(Int(todaysAverage.rounded())) bpm",
                detailText: "Resting HR today",
                tone: .neutral,
                symbol: nil,
                hasSignal: true,
                hasTodayData: true,
                baselineAverage: nil,
                todaysAverage: todaysAverage
            )
        }

        let delta = baselineAverage - todaysAverage
        let adjustment = clamp(delta * 1.4, min: -10, max: 8)
        let roundedDelta = Int(abs(delta).rounded())
        let detailDirection = delta >= 0 ? "below" : "above"

        return (
            adjustment: adjustment,
            valueText: signedValueText(for: adjustment),
            detailText: "\(Int(todaysAverage.rounded())) bpm today, \(roundedDelta) \(detailDirection) 7d baseline",
            tone: tone(for: adjustment),
            symbol: symbol(for: adjustment),
            hasSignal: true,
            hasTodayData: true,
            baselineAverage: baselineAverage,
            todaysAverage: todaysAverage
        )
    }

    private func sleepAlert(latestSleepScore: Double?, sleepRecharge: Double) -> SQAlertViewModel {
        let subtitle: String
        let attributedSubtitle: AttributedString
        if let latestSleepScore {
            subtitle = "Sleep recharge is based on your latest Sleep Score. A score of \(Int(latestSleepScore.rounded())) contributed about \(Int(sleepRecharge.rounded())) points to Body Battery."
            attributedSubtitle = buildBodyBatteryText([
                .plain("Sleep recharge is based on your latest Sleep Score. A score of "),
                .highlight("\(Int(latestSleepScore.rounded()))"),
                .plain(" contributed about "),
                .highlight("\(Int(sleepRecharge.rounded()))"),
                .plain(" points to Body Battery.")
            ])
        } else {
            subtitle = "Sleep recharge uses your latest completed night. When sleep data is available, stronger duration, efficiency, fragmentation, and architecture scores raise Body Battery."
            attributedSubtitle = buildBodyBatteryText([
                .plain("Sleep recharge uses your latest completed night. When sleep data is available, stronger "),
                .highlight("duration"),
                .plain(", "),
                .highlight("efficiency"),
                .plain(", "),
                .highlight("fragmentation"),
                .plain(", and "),
                .highlight("architecture"),
                .plain(" scores raise Body Battery.")
            ])
        }

        return .init(
            title: "Sleep Recharge",
            subtitle: subtitle,
            attributedSubtitle: attributedSubtitle,
            primary: .ok,
            canDismiss: true
        )
    }

    private func strainAlert(
        totalStrain: Double,
        todaysWorkoutsCount: Int,
        yesterdaysWorkoutsCount: Int
    ) -> SQAlertViewModel {
        let subtitle = "Strain lowers Body Battery based on recent workout duration, calories, and workout heart rate. Right now that penalty is \(Int(totalStrain.rounded())) points across \(todaysWorkoutsCount) workout(s) today and \(yesterdaysWorkoutsCount) yesterday."
        let attributedSubtitle = buildBodyBatteryText([
            .plain("Strain lowers Body Battery based on recent workout duration, calories, and workout heart rate. Right now that penalty is "),
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

        if let customSummary {
            subtitle = "Check-ins adjust Body Battery using Energy, Recovery, Nutrition, Alcohol, Caffeine, and custom metrics like \(customSummary). Today those signals changed the score by \(signedValueText(for: checkInAdjustment.totalAdjustment)) point(s). Custom metric impact is capped so those signals stay supportive instead of dominating the score."
            attributedSubtitle = buildBodyBatteryText([
                .plain("Check-ins adjust Body Battery using "),
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
            subtitle = "Check-ins adjust Body Battery using Energy, Recovery, Nutrition, Alcohol, and Caffeine. Today those signals changed the score by \(signedValueText(for: checkInAdjustment.totalAdjustment)) point(s)."
            attributedSubtitle = buildBodyBatteryText([
                .plain("Check-ins adjust Body Battery using "),
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

    private func heartAlert(
        heartRecovery: (adjustment: Double, valueText: String, detailText: String, tone: SQDashboardTrendTone, symbol: SQImageSymbol?, hasSignal: Bool, hasTodayData: Bool, baselineAverage: Double?, todaysAverage: Double?)
    ) -> SQAlertViewModel {
        let subtitle: String
        let attributedSubtitle: AttributedString

        if !heartRecovery.hasSignal {
            subtitle = "Body Battery can use resting heart rate when Health access is allowed and Health has collected enough background heart data. Make sure Heart Rate and Resting Heart Rate permissions are enabled and that a compatible device is recording heart data regularly."
            attributedSubtitle = buildBodyBatteryText([
                .plain("Body Battery can use "),
                .highlight("resting heart rate"),
                .plain(" when Health access is allowed and Health has collected enough background heart data. Make sure "),
                .highlight("Heart Rate"),
                .plain(" and "),
                .highlight("Resting Heart Rate"),
                .plain(" permissions are enabled and that a compatible device is recording heart data regularly.")
            ])
        } else if !heartRecovery.hasTodayData {
            let baselineText = heartRecovery.baselineAverage.map { "\(Int($0.rounded())) bpm" } ?? "your recent baseline"
            subtitle = "We have a recent resting-heart-rate baseline of \(baselineText), but not a resting HR for today yet. Resting heart rate is recorded automatically in the background when supported Health sources provide it; apps can read that data, but cannot force a new resting-heart-rate sample on demand."
            attributedSubtitle = buildBodyBatteryText([
                .plain("We have a recent resting-heart-rate baseline of "),
                .highlight(baselineText),
                .plain(", but not a resting HR for today yet. Resting heart rate is recorded automatically in the background when supported Health sources provide it; apps can read that data, but cannot force a new resting-heart-rate sample on demand.")
            ])
        } else if let todaysAverage = heartRecovery.todaysAverage, let baselineAverage = heartRecovery.baselineAverage {
            subtitle = "Heart recovery compares today’s resting HR (\(Int(todaysAverage.rounded())) bpm) to your recent 7-day baseline (\(Int(baselineAverage.rounded())) bpm). Lower-than-baseline resting HR boosts Body Battery, while higher-than-baseline resting HR adds a recovery penalty."
            attributedSubtitle = buildBodyBatteryText([
                .plain("Heart recovery compares today’s resting HR ("),
                .highlight("\(Int(todaysAverage.rounded())) bpm"),
                .plain(") to your recent 7-day baseline ("),
                .highlight("\(Int(baselineAverage.rounded())) bpm"),
                .plain("). Lower-than-baseline resting HR boosts Body Battery, while higher-than-baseline resting HR adds a recovery penalty.")
            ])
        } else if let todaysAverage = heartRecovery.todaysAverage {
            subtitle = "Today’s resting HR is \(Int(todaysAverage.rounded())) bpm. Once more history is available, Body Battery will compare that value against your recent baseline to estimate recovery."
            attributedSubtitle = buildBodyBatteryText([
                .plain("Today’s resting HR is "),
                .highlight("\(Int(todaysAverage.rounded())) bpm"),
                .plain(". Once more history is available, Body Battery will compare that value against your recent baseline to estimate recovery.")
            ])
        } else {
            subtitle = "Resting heart rate is used as a recovery signal inside Body Battery when enough heart data is available."
            attributedSubtitle = buildBodyBatteryText([
                .highlight("Resting heart rate"),
                .plain(" is used as a recovery signal inside Body Battery when enough heart data is available.")
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

    private func sleepDriverDetailText(latestSleepScore: Double?, sleepRecharge: Double) -> AttributedString? {
        guard let latestSleepScore else { return nil }

        return buildBodyBatteryText([
            .plain("Sleep Score "),
            .highlight("\(Int(latestSleepScore.rounded()))"),
            .plain(" added "),
            .highlight("+\(Int(sleepRecharge.rounded()))"),
            .plain(" points")
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

    private func heartDriverDetailText(
        heartRecovery: (adjustment: Double, valueText: String, detailText: String, tone: SQDashboardTrendTone, symbol: SQImageSymbol?, hasSignal: Bool, hasTodayData: Bool, baselineAverage: Double?, todaysAverage: Double?)
    ) -> AttributedString? {
        if let todaysAverage = heartRecovery.todaysAverage, let baselineAverage = heartRecovery.baselineAverage {
            let delta = Int(abs(todaysAverage - baselineAverage).rounded())
            let direction = todaysAverage <= baselineAverage ? "below" : "above"

            return buildBodyBatteryText([
                .highlight("\(Int(todaysAverage.rounded())) bpm"),
                .plain(" today, "),
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
            return buildBodyBatteryText([
                .highlight("\(Int(todaysAverage.rounded())) bpm"),
                .plain(" resting HR today")
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

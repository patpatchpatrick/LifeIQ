//
//  SQBodyBatteryService.swift
//  BeastFitness
//

import SwiftData
import Foundation
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
    private let sleepAggregationService: SQSleepAggregationService

    init(
        metricEntryManager: SQMetricEntryManaging,
        sleepAggregationService: SQSleepAggregationService = .init()
    ) {
        self.metricEntryManager = metricEntryManager
        self.sleepAggregationService = sleepAggregationService
    }

    func buildDashboardRowViewModel(
        todaysWorkouts: [SQWorkoutSessionable],
        yesterdaysWorkouts: [SQWorkoutSessionable],
        sleepData: SQSleepDashboardData?,
        context: ModelContext
    ) async throws -> SQDashboardBodyBatteryRowViewModel? {
        let todaysCheckIns = try await metricEntryManager.getDailyCheckInStats(
            from: SQTimeRange.today.startDate,
            to: SQTimeRange.today.endDate,
            context: context
        )

        guard sleepData?.latestNight != nil || !todaysWorkouts.isEmpty || !yesterdaysWorkouts.isEmpty || !todaysCheckIns.isEmpty else {
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

        let habitAdjustment = bodyBatteryHabitAdjustment(from: todaysCheckIns.last?.values ?? [:])
        let rawScore = 28 + sleepRecharge + habitAdjustment - totalStrain
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
                habitAdjustment: habitAdjustment
            ),
            drivers: [
                .init(
                    title: "Sleep",
                    valueText: "+\(Int(sleepRecharge.rounded()))",
                    detailText: latestSleepScore == nil ? "Awaiting sleep data" : "Recharge from last night",
                    tone: .positive,
                    symbol: .arrowUp
                ),
                .init(
                    title: "Strain",
                    valueText: "-\(Int(totalStrain.rounded()))",
                    detailText: todaysWorkouts.isEmpty && yesterdaysWorkouts.isEmpty ? "No recent load" : "Today + carryover load",
                    tone: totalStrain > 8 ? .negative : .neutral,
                    symbol: totalStrain > 8 ? .arrowDown : nil
                ),
                .init(
                    title: "Check-ins",
                    valueText: signedValueText(for: habitAdjustment),
                    detailText: habitAdjustment == 0 ? "No strong recovery signal" : "Energy, soreness, habits",
                    tone: tone(for: habitAdjustment),
                    symbol: symbol(for: habitAdjustment)
                )
            ],
            footer: "Estimated from last night’s sleep, current workout strain, and today’s recovery signals."
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

    private func bodyBatteryHabitAdjustment(from values: [String: Float]) -> Double {
        let energyBoost = values[SQMetricId.energy].map { clamp((Double($0) - 5.5) * 1.5, min: -7, max: 7) } ?? 0
        let sorenessBoost = values[SQMetricId.soreness].map { clamp((Double($0) - 5.0) * 1.2, min: -6, max: 6) } ?? 0
        let nutritionBoost = values[SQMetricId.nutrition].map { clamp((Double($0) - 5.0) * 0.7, min: 0, max: 4) } ?? 0
        let alcoholPenalty = values[SQMetricId.alcohol].map { clamp(Double($0) * 1.5, min: 0, max: 12) } ?? 0
        let caffeinePenalty = values[SQMetricId.caffeine].map { clamp((Double($0) - 6.0) * 0.8, min: 0, max: 4) } ?? 0

        return clamp(
            energyBoost + sorenessBoost + nutritionBoost - alcoholPenalty - caffeinePenalty,
            min: -18,
            max: 12
        )
    }

    private func bodyBatterySummary(
        sleepRecharge: Double,
        totalStrain: Double,
        habitAdjustment: Double
    ) -> String {
        if sleepRecharge >= 38 && totalStrain <= 8 && habitAdjustment >= 0 {
            return "Strong overnight recovery is keeping your energy reserves high right now."
        }

        if totalStrain >= 16 {
            return "Recent training load is draining the battery faster than your recovery is rebuilding it."
        }

        if habitAdjustment <= -6 {
            return "Today’s recovery signals are dragging the battery down despite your baseline recharge."
        }

        if habitAdjustment >= 6 {
            return "Good energy and recovery check-ins are helping preserve your battery through the day."
        }

        return "Sleep, strain, and daily recovery signals are fairly balanced right now."
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

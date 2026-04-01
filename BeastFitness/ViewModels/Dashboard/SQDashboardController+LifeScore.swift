//
//  SQDashboardController+LifeScore.swift
//  BeastFitness
//

import SwiftData
import BeastFitnessCore

extension SQDashboardController {
    func handleLifeScoreTap() {
        guard let lifeScoreViewModel else { return }

        let lines = lifeScoreViewModel.components.map {
            "\($0.title): \($0.score)/100 - \($0.summary)"
        }

        let subtitle = [
            lifeScoreViewModel.subtitle,
            "",
            "Current State: \(lifeScoreViewModel.state.title)",
            lifeScoreViewModel.state.summary,
            "",
            "Breakdown",
            lines.joined(separator: "\n")
        ]
            .filter { !$0.isEmpty || !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .joined(separator: "\n")

        let alert = SQAlertViewModel(
            title: lifeScoreViewModel.titleText,
            subtitle: subtitle,
            primary: .ok,
            secondary: nil,
            canDismiss: true
        )

        state.hub.alertEvents.send(.present(alert))
    }

    func buildLifeScoreViewModel(
        todaysCheckIns: [SQDailyCheckInStats],
        past7DaysCheckIns: [SQDailyCheckInStats],
        todaysWorkouts: [SQWorkoutSessionable],
        lastWeekWorkouts: [SQWorkoutSessionable],
        sleepData: SQSleepDashboardData?,
        hasCompletedCurrentCheckIn: Bool
    ) -> SQLifeScoreViewModel {
        var components: [SQLifeScoreComponent] = []

        if let sleepComponent = lifeScoreSleepComponent(from: sleepData) {
            components.append(sleepComponent)
        }

        if let habitsComponent = lifeScoreHabitsComponent(from: todaysCheckIns) {
            components.append(habitsComponent)
        }

        if let workoutsComponent = lifeScoreWorkoutComponent(
            todaysWorkouts: todaysWorkouts,
            lastWeekWorkouts: lastWeekWorkouts
        ) {
            components.append(workoutsComponent)
        }

        if let consistencyComponent = lifeScoreConsistencyComponent(
            past7DaysCheckIns: past7DaysCheckIns,
            hasCompletedCurrentCheckIn: hasCompletedCurrentCheckIn
        ) {
            components.append(consistencyComponent)
        }

        let totalWeight = components.reduce(0) { $0 + $1.weight }
        let weightedScore = totalWeight > 0
            ? components.reduce(0) { $0 + (Double($1.score) * $1.weight) } / totalWeight
            : nil

        let roundedScore = weightedScore.map { Int($0.rounded()) }
        let state = lifeScoreState(for: roundedScore, availableWeight: totalWeight)

        let subtitle: String
        if !userState.isLoggedIn {
            subtitle = "Early preview based on the signals available in guest mode."
        } else if totalWeight < 60 {
            subtitle = "LifeIQ is still calibrating because some of your usual signals are missing today."
        } else {
            subtitle = "A lightweight read on how aligned your recovery, habits, and training look right now."
        }

        return .init(
            score: roundedScore,
            state: state,
            subtitle: subtitle,
            components: components.sorted { $0.weight > $1.weight },
            availableWeight: totalWeight
        )
    }

    private func lifeScoreState(for score: Int?, availableWeight: Double) -> SQLifeScoreState {
        guard let score else { return .calibrating }
        guard availableWeight >= 45 else { return .calibrating }

        switch score {
        case 82...:
            return .aligned
        case 68...81:
            return .steady
        case 50...67:
            return .mixed
        default:
            return .strained
        }
    }

    private func lifeScoreSleepComponent(from sleepData: SQSleepDashboardData?) -> SQLifeScoreComponent? {
        let sleepScore: Double?
        if let latestNight = sleepData?.latestNight {
            sleepScore = sleepAggregationService.score(for: latestNight).totalScore
        } else {
            sleepScore = sleepData?.averageScore?.totalScore
        }

        guard let sleepScore else { return nil }
        let roundedScore = Int(clamp(sleepScore, min: 0, max: 100).rounded())

        let summary: String
        switch roundedScore {
        case 80...:
            summary = "Sleep looked strong and should be helping recovery."
        case 65...79:
            summary = "Sleep was decent, but not elite enough to fully lift the day."
        case 45...64:
            summary = "Sleep was mixed, so recovery support looks only moderate."
        default:
            summary = "Sleep is the biggest drag on the score right now."
        }

        return .init(
            id: "sleep",
            title: "Sleep",
            score: roundedScore,
            summary: summary,
            weight: 30
        )
    }

    private func lifeScoreHabitsComponent(from todaysCheckIns: [SQDailyCheckInStats]) -> SQLifeScoreComponent? {
        let values = mergedMetricValues(from: todaysCheckIns)
        guard !values.isEmpty else { return nil }

        let supportiveMetricIds = [
            SQMetricId.energy,
            SQMetricId.soreness,
            SQMetricId.nutrition,
            SQMetricId.sleepQuality,
            SQMetricId.mentalClarity,
            SQMetricId.mood,
            SQMetricId.meditation
        ]
        let viceMetricIds = [
            SQMetricId.alcohol,
            SQMetricId.caffeine,
            SQMetricId.weed,
            SQMetricId.porn
        ]

        let supportiveScores = supportiveMetricIds.compactMap { values[$0] }.map { Double($0) / 10 * 100 }
        let viceScores = viceMetricIds.compactMap { values[$0] }.map { (1 - (Double($0) / 10)) * 100 }
        let allScores = supportiveScores + viceScores

        guard !allScores.isEmpty else { return nil }
        let averageScore = allScores.reduce(0, +) / Double(allScores.count)
        let roundedScore = Int(clamp(averageScore, min: 0, max: 100).rounded())

        let summary: String
        if roundedScore >= 80 {
            summary = "Today's self-reported signals look supportive and low-friction."
        } else if roundedScore >= 65 {
            summary = "Your logged habits look mostly supportive, with a little drift."
        } else if roundedScore >= 45 {
            summary = "Today's check-ins are mixed enough to keep the score neutral."
        } else {
            summary = "Today's habit and recovery signals are clearly weighing on the score."
        }

        return .init(
            id: "habits",
            title: "Habits",
            score: roundedScore,
            summary: summary,
            weight: 35
        )
    }

    private func lifeScoreWorkoutComponent(
        todaysWorkouts: [SQWorkoutSessionable],
        lastWeekWorkouts: [SQWorkoutSessionable]
    ) -> SQLifeScoreComponent? {
        let activeWorkoutDays = Set(lastWeekWorkouts.compactMap { $0.startDate?.firebaseDailyDateKey }).count
        let todayWorkoutBonus = todaysWorkouts.isEmpty ? 0.0 : 8.0
        let rawScore = (Double(activeWorkoutDays) / 4.0) * 100.0 + todayWorkoutBonus
        let roundedScore = Int(clamp(rawScore, min: 0, max: 100).rounded())

        let summary: String
        if todaysWorkouts.isEmpty {
            summary = "You trained on \(activeWorkoutDays) of the last 7 days."
        } else {
            summary = "You trained on \(activeWorkoutDays) of the last 7 days, including today."
        }

        return .init(
            id: "workouts",
            title: "Workouts",
            score: roundedScore,
            summary: summary,
            weight: 20
        )
    }

    private func lifeScoreConsistencyComponent(
        past7DaysCheckIns: [SQDailyCheckInStats],
        hasCompletedCurrentCheckIn: Bool
    ) -> SQLifeScoreComponent? {
        guard userState.isLoggedIn else { return nil }

        let uniqueLoggedDays = Set(past7DaysCheckIns.map(\.uniqueDateKey)).count
        let baseScore = (Double(uniqueLoggedDays) / 5.0) * 100.0
        let completionBonus = hasCompletedCurrentCheckIn ? 10.0 : 0.0
        let roundedScore = Int(clamp(baseScore + completionBonus, min: 0, max: 100).rounded())

        let summary: String
        if hasCompletedCurrentCheckIn {
            summary = "You checked in on \(uniqueLoggedDays) of the last 7 days and you're current for today."
        } else {
            summary = "You checked in on \(uniqueLoggedDays) of the last 7 days, but today's prompt is still open."
        }

        return .init(
            id: "consistency",
            title: "Consistency",
            score: roundedScore,
            summary: summary,
            weight: 15
        )
    }

    private func mergedMetricValues(from stats: [SQDailyCheckInStats]) -> [String: Float] {
        stats.reduce(into: [String: Float]()) { partialResult, stat in
            for (metricId, value) in stat.values {
                partialResult[metricId] = value
            }
        }
    }

    private func clamp(_ value: Double, min minimum: Double, max maximum: Double) -> Double {
        Swift.max(minimum, Swift.min(maximum, value))
    }
}

//
//  SQDashboardController+LifeScore.swift
//  BeastFitness
//

import SwiftData
import BeastFitnessCore

extension SQDashboardController {
    func handleLifeScoreTap() {
        guard let lifeScoreViewModel else { return }
        SQAnalyticsManager.shared.track(.dashboardItemOpened(
            itemType: "life_score",
            itemId: nil,
            sourceGroup: "daily_stats",
            score: lifeScoreViewModel.score
        ))
        let controller = SQLifeScoreDetailController(viewModel: lifeScoreViewModel)
        state.hub.domainEvents.send(.pushDashboardRoute(.lifeScoreDetail(controller: controller)))
    }

    func buildLifeScoreViewModel(
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

        if let habitsComponent = lifeScoreHabitsComponent(from: past7DaysCheckIns) {
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

        let preliminaryScore = weightedScore.map { Int($0.rounded()) }
        let state = lifeScoreState(for: preliminaryScore, availableWeight: totalWeight)
        let roundedScore = state == .calibrating ? nil : preliminaryScore

        let subtitle: String
        if components.isEmpty {
            subtitle = "LifeIQ is still calibrating. Add Health data or check in a few times so the score has something real to work from."
        } else if !userState.isLoggedIn {
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
            weight: 30,
            detailItems: []
        )
    }

    private func lifeScoreHabitsComponent(from recentCheckIns: [SQDailyCheckInStats]) -> SQLifeScoreComponent? {
        let values = averagedMetricValues(from: recentCheckIns)
        guard !values.isEmpty else { return nil }

        let trackedDefinitions = metricsManager.dailyCheckInMetrics()
        let scoredHabits = trackedDefinitions
            .filter { values[$0.id] != nil }
            .filter { $0.goalStyle != .justTrack && $0.goalStyle != .unknown }
            .compactMap { definition -> (definition: SQMetricDefinition, value: Double, score: Double, item: SQLifeScoreDetailItem)? in
                guard let rawValue = values[definition.id] else { return nil }
                let value = rawValue
                guard let score = habitScore(for: value, definition: definition) else { return nil }
                let effect = habitEffect(for: value, score: score, definition: definition)

                return (
                    definition: definition,
                    value: value,
                    score: score,
                    item: .init(
                        id: definition.id,
                        title: definition.title,
                        valueText: "7d avg \(formattedMetricValue(value, definition: definition))",
                        summary: habitScoreSummary(for: value, score: score, definition: definition),
                        effect: effect
                    )
                )
            }

        guard !scoredHabits.isEmpty else { return nil }
        let averageScore = scoredHabits.map(\.score).reduce(0, +) / Double(scoredHabits.count)
        let roundedScore = Int(clamp(averageScore, min: 0, max: 100).rounded())

        let positiveCount = scoredHabits.filter { $0.item.effect == .positive }.count
        let negativeCount = scoredHabits.filter { $0.item.effect == .negative }.count

        let summary: String
        if positiveCount > 0 && negativeCount > 0 {
            summary = "\(positiveCount) recent habits supported the score, while \(negativeCount) pulled it down."
        } else if positiveCount > 0 {
            summary = "Your recent goal-based habits are mostly supportive."
        } else if negativeCount > 0 {
            summary = "Several recent goal-based habits are dragging the score down."
        } else if roundedScore >= 45 {
            summary = "Your recent goal-based habits are mostly neutral."
        } else {
            summary = "Your recent habit signals are clearly weighing on the score."
        }

        return .init(
            id: "habits",
            title: "Habits",
            score: roundedScore,
            summary: summary,
            weight: 35,
            detailItems: scoredHabits
                .map(\.item)
                .sorted { lhs, rhs in
                    lifeScoreEffectPriority(lhs.effect) < lifeScoreEffectPriority(rhs.effect)
                }
        )
    }

    private func lifeScoreWorkoutComponent(
        todaysWorkouts: [SQWorkoutSessionable],
        lastWeekWorkouts: [SQWorkoutSessionable]
    ) -> SQLifeScoreComponent? {
        let activeWorkoutDays = Set(lastWeekWorkouts.compactMap { $0.startDate?.firebaseDailyDateKey }).count
        guard activeWorkoutDays > 0 || !todaysWorkouts.isEmpty else { return nil }
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
            weight: 20,
            detailItems: []
        )
    }

    private func lifeScoreConsistencyComponent(
        past7DaysCheckIns: [SQDailyCheckInStats],
        hasCompletedCurrentCheckIn: Bool
    ) -> SQLifeScoreComponent? {
        guard userState.isLoggedIn else { return nil }

        let uniqueLoggedDays = Set(past7DaysCheckIns.map(\.uniqueDateKey)).count
        guard uniqueLoggedDays > 0 || hasCompletedCurrentCheckIn else { return nil }
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
            weight: 15,
            detailItems: []
        )
    }

    private func averagedMetricValues(from stats: [SQDailyCheckInStats]) -> [String: Double] {
        var perDayValues: [String: [String: [Double]]] = [:]

        for stat in stats {
            let dayKey = stat.uniqueDateKey
            for (metricId, value) in stat.values {
                perDayValues[metricId, default: [:]][dayKey, default: []].append(Double(value))
            }
        }

        return perDayValues.reduce(into: [String: Double]()) { partialResult, pair in
            let metricId = pair.key
            let dailyValues = pair.value.values.compactMap { values -> Double? in
                guard !values.isEmpty else { return nil }
                return values.reduce(0, +) / Double(values.count)
            }

            guard !dailyValues.isEmpty else { return }
            partialResult[metricId] = dailyValues.reduce(0, +) / Double(dailyValues.count)
        }
    }

    private func clamp(_ value: Double, min minimum: Double, max maximum: Double) -> Double {
        Swift.max(minimum, Swift.min(maximum, value))
    }

    private func habitScore(for value: Double, definition: SQMetricDefinition) -> Double? {
        switch definition.goalStyle {
        case .buildUp:
            if let target = definition.targetValue, target > 0 {
                return clamp((value / Double(target)) * 100, min: 0, max: 100)
            }

            guard let normalized = normalizedMetricValue(value, definition: definition) else { return nil }
            return normalized * 100

        case .keepLow:
            if let target = definition.targetValue {
                return inverseScore(
                    value: value,
                    target: Double(target),
                    upperBound: keepLowUpperBound(for: definition, target: Double(target))
                )
            }

            guard let normalized = normalizedMetricValue(value, definition: definition) else { return nil }
            return (1 - normalized) * 100

        case .avoidIt:
            if value <= 0 {
                return 100
            }

            let upperBound = max(Double(definition.max ?? 0), 1)
            return clamp((1 - (value / upperBound)) * 100, min: 0, max: 100)

        case .stayInRange:
            guard
                let rangeMin = definition.targetRangeMin.map(Double.init),
                let rangeMax = definition.targetRangeMax.map(Double.init),
                rangeMax >= rangeMin
            else {
                return nil
            }

            if value >= rangeMin && value <= rangeMax {
                return 100
            }

            let distance: Double
            let toleranceSpan: Double
            if value < rangeMin {
                distance = rangeMin - value
                toleranceSpan = max(rangeMin - Double(definition.min ?? 0), rangeMax - rangeMin, 1)
            } else {
                distance = value - rangeMax
                toleranceSpan = max(Double(definition.max ?? Float(rangeMax)) - rangeMax, rangeMax - rangeMin, 1)
            }

            return clamp((1 - (distance / toleranceSpan)) * 100, min: 0, max: 100)

        case .justTrack, .unknown:
            return nil
        }
    }

    private func inverseScore(value: Double, target: Double, upperBound: Double) -> Double {
        guard upperBound > target else {
            return value <= target ? 100 : 0
        }

        if value <= target {
            return 100
        }

        return clamp((1 - ((value - target) / (upperBound - target))) * 100, min: 0, max: 100)
    }

    private func normalizedMetricValue(_ value: Double, definition: SQMetricDefinition) -> Double? {
        guard
            let min = definition.min.map(Double.init),
            let max = definition.max.map(Double.init),
            max > min
        else {
            return nil
        }

        return clamp((value - min) / (max - min), min: 0, max: 1)
    }

    private func keepLowUpperBound(for definition: SQMetricDefinition, target: Double) -> Double {
        let maxValue = Double(definition.max ?? Float(target + 1))
        return max(maxValue, target + 1)
    }

    private func formattedMetricValue(_ value: Double, definition: SQMetricDefinition) -> String {
        let raw = value == value.rounded() ? "\(Int(value))" : String(format: "%.1f", value)

        let unit = definition.quantityUnit
        let unitSuffix = unit.shortDisplayName
        if unit == .none || unit == .count || unit == .unknown {
            if definition.kind == .scale || definition.kind == .binary {
                let max = definition.scaleMaxValue
                return "\(raw)/\(Int(max))"
            }
            return raw
        }

        if unit == .percent {
            return "\(raw)%"
        }

        return "\(raw) \(unitSuffix)"
    }

    private func habitScoreSummary(for value: Double, score: Double, definition: SQMetricDefinition) -> String {
        switch definition.goalStyle {
        case .buildUp:
            if let target = definition.targetValue {
                return value >= Double(target)
                    ? "Your 7-day average met or exceeded the target of \(formattedTarget(target, definition: definition))."
                    : "Your 7-day average stayed below the target of \(formattedTarget(target, definition: definition))."
            }
            return score >= 70 ? "Your 7-day average helped this goal." : "This goal still wants a higher recent average."

        case .keepLow:
            if let target = definition.targetValue {
                return value <= Double(target)
                    ? "Your 7-day average stayed at or below the target of \(formattedTarget(target, definition: definition))."
                    : "Your 7-day average ran above the target of \(formattedTarget(target, definition: definition))."
            }
            return score >= 70 ? "Your 7-day average stayed reasonably low." : "Your 7-day average ran higher than the goal."

        case .avoidIt:
            if value <= 0 {
                return "Your 7-day average stayed at zero, which fully supports this goal."
            }

            return score >= 55
                ? "Your 7-day average was above zero, so it slightly lowered this goal score."
                : "Your 7-day average was well above zero, so it clearly lowered this goal score."

        case .stayInRange:
            let minText = definition.targetRangeMin.map { formattedTarget($0, definition: definition) } ?? "?"
            let maxText = definition.targetRangeMax.map { formattedTarget($0, definition: definition) } ?? "?"
            return value >= Double(definition.targetRangeMin ?? 0) && value <= Double(definition.targetRangeMax ?? 0)
                ? "Your 7-day average stayed inside the target range of \(minText)-\(maxText)."
                : "Your 7-day average sat outside the target range of \(minText)-\(maxText)."

        case .justTrack, .unknown:
            return "Tracked for awareness."
        }
    }

    private func habitEffect(for value: Double, score: Double, definition: SQMetricDefinition) -> SQLifeScoreSignalEffect {
        switch definition.goalStyle {
        case .buildUp:
            if let target = definition.targetValue, value >= Double(target) {
                return .positive
            }
            return habitEffect(forScore: score, positiveThreshold: 85, negativeThreshold: 50)

        case .keepLow:
            if let target = definition.targetValue, value <= Double(target) {
                return .positive
            }
            return score < 50 ? .negative : .neutral

        case .avoidIt:
            if value <= 0 {
                return .positive
            }
            return score < 55 ? .negative : .neutral

        case .stayInRange:
            if
                let rangeMin = definition.targetRangeMin.map(Double.init),
                let rangeMax = definition.targetRangeMax.map(Double.init),
                value >= rangeMin,
                value <= rangeMax
            {
                return .positive
            }
            return score < 60 ? .negative : .neutral

        case .justTrack, .unknown:
            return .neutral
        }
    }

    private func habitEffect(
        forScore score: Double,
        positiveThreshold: Double,
        negativeThreshold: Double
    ) -> SQLifeScoreSignalEffect {
        if score >= positiveThreshold {
            return .positive
        }

        if score < negativeThreshold {
            return .negative
        }

        return .neutral
    }

    private func formattedTarget(_ value: Float, definition: SQMetricDefinition) -> String {
        formattedMetricValue(Double(value), definition: definition)
    }

    private func lifeScoreEffectPriority(_ effect: SQLifeScoreSignalEffect) -> Int {
        switch effect {
        case .positive:
            return 0
        case .negative:
            return 1
        case .neutral:
            return 2
        }
    }
}

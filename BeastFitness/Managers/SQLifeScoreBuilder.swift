//
//  SQLifeScoreBuilder.swift
//  BeastFitness
//
//  Created by Codex on 4/24/26.
//

import Foundation
import BeastFitnessCore

struct SQLifeScoreBuildInput {
    let intelligenceInput: SQHealthIntelligenceInput
    let insightsResult: SQInsightsResult
}

@MainActor
protocol SQLifeScoreBuilding {
    func buildViewModel(input: SQLifeScoreBuildInput) -> SQLifeScoreViewModel
}

@MainActor
struct SQLifeScoreBuilder: SQLifeScoreBuilding {
    private let sleepAggregationService: SQSleepAggregationService

    init(
        sleepAggregationService: SQSleepAggregationService
    ) {
        self.sleepAggregationService = sleepAggregationService
    }

    func buildViewModel(input: SQLifeScoreBuildInput) -> SQLifeScoreViewModel {
        let calendar = Calendar.current
        let intelligenceInput = input.intelligenceInput
        let primaryInsight = intelligenceInput.timeRange == .today ? input.insightsResult.insights.first : nil
        let startOfReferenceDay = calendar.startOfDay(for: intelligenceInput.referenceDate)
        let startOfYesterday = calendar.date(byAdding: .day, value: -1, to: startOfReferenceDay) ?? startOfReferenceDay
        let pastSevenDayStart = calendar.date(byAdding: .day, value: -6, to: startOfReferenceDay) ?? startOfReferenceDay

        let pastSevenDaysCheckIns = intelligenceInput.checkIns.filter {
            let day = calendar.startOfDay(for: $0.date)
            return day >= pastSevenDayStart && day <= startOfReferenceDay
        }

        let todaysWorkouts = intelligenceInput.workouts.filter {
            guard let startDate = $0.startDate else { return false }
            return calendar.isDate(startDate, inSameDayAs: startOfReferenceDay)
        }

        let yesterdaysWorkouts = intelligenceInput.workouts.filter {
            guard let startDate = $0.startDate else { return false }
            return calendar.isDate(startDate, inSameDayAs: startOfYesterday)
        }

        let lastWeekWorkouts = intelligenceInput.workouts.filter {
            guard let startDate = $0.startDate else { return false }
            let day = calendar.startOfDay(for: startDate)
            return day >= pastSevenDayStart && day <= startOfReferenceDay
        }

        let hasCompletedCurrentCheckIn = pastSevenDaysCheckIns.contains {
            calendar.isDate($0.date, inSameDayAs: startOfReferenceDay)
        }
        let hasCompletedYesterdayCheckIn = pastSevenDaysCheckIns.contains {
            calendar.isDate($0.date, inSameDayAs: startOfYesterday)
        }

        var components = [SQLifeScoreComponent]()

        if let sleepComponent = lifeScoreSleepComponent(
            checkIns: intelligenceInput.checkIns,
            sleepCheckIns: intelligenceInput.sleepCheckIns,
            referenceDate: intelligenceInput.referenceDate,
            sleepData: intelligenceInput.sleepData
        ) {
            components.append(sleepComponent)
        }

        if let heartComponent = lifeScoreHeartComponent(
            from: intelligenceInput.restingHeartRateSummaries,
            referenceDate: intelligenceInput.referenceDate
        ) {
            components.append(heartComponent)
        }

        if let habitsComponent = lifeScoreHabitsComponent(
            from: pastSevenDaysCheckIns,
            metricDefinitions: intelligenceInput.metricDefinitions,
            referenceDate: intelligenceInput.referenceDate
        ) {
            components.append(habitsComponent)
        }

        if let workoutsComponent = lifeScoreWorkoutComponent(
            todaysWorkouts: todaysWorkouts,
            lastWeekWorkouts: lastWeekWorkouts
        ) {
            components.append(workoutsComponent)
        }

        if let consistencyComponent = lifeScoreConsistencyComponent(
            past7DaysCheckIns: pastSevenDaysCheckIns,
            hasCompletedCurrentCheckIn: hasCompletedCurrentCheckIn,
            isLoggedIn: intelligenceInput.isLoggedIn
        ) {
            components.append(consistencyComponent)
        }

        let totalWeight = components.reduce(0) { $0 + $1.weight }
        let weightedScore = totalWeight > 0
            ? components.reduce(0) { $0 + (Double($1.score) * $1.weight) } / totalWeight
            : nil

        let preliminaryScore = weightedScore.map { Int($0.rounded()) }
        let previousScore = estimatedPreviousDayLifeScore(
            referenceDate: intelligenceInput.referenceDate,
            checkIns: intelligenceInput.checkIns,
            sleepCheckIns: intelligenceInput.sleepCheckIns,
            workouts: intelligenceInput.workouts,
            metricDefinitions: intelligenceInput.metricDefinitions,
            sleepData: intelligenceInput.sleepData,
            restingHeartRateSummaries: intelligenceInput.restingHeartRateSummaries,
            isLoggedIn: intelligenceInput.isLoggedIn
        )
        let scoreDeltaFromPreviousDay: Int? = {
            guard let preliminaryScore, let previousScore else { return nil }
            return preliminaryScore - previousScore
        }()
        let state = lifeScoreState(
            score: preliminaryScore,
            availableWeight: totalWeight,
            scoreDeltaFromPreviousDay: scoreDeltaFromPreviousDay,
            components: components,
            drivers: input.insightsResult.drivers,
            primaryInsight: primaryInsight
        )
        let roundedScore = state == .calibrating ? nil : preliminaryScore
        let alignedActions = lifeScoreAlignedActions(
            input.insightsResult.actions,
            state: state,
            score: roundedScore,
            scoreDeltaFromPreviousDay: scoreDeltaFromPreviousDay,
            components: components
        )
        let refinementPromptText = lifeScoreRefinementPromptText(for: intelligenceInput)

        let subtitle: String
        if components.isEmpty {
            subtitle = "LifeIQ is still calibrating. Add Health data or check in a few times so the score has something real to work from."
        } else if !intelligenceInput.isLoggedIn {
            subtitle = "Early preview based on the signals available in guest mode."
        } else if totalWeight < 60 {
            subtitle = "LifeIQ is still calibrating because some of your usual signals are missing today."
        } else {
            subtitle = "A lightweight read on how your recovery, heart, habits, and training are lining up right now."
        }

        return .init(
            score: roundedScore,
            scoreDeltaFromPreviousDay: scoreDeltaFromPreviousDay,
            state: state,
            subtitle: subtitle,
            refinementPromptText: refinementPromptText,
            components: components.sorted { $0.weight > $1.weight },
            primaryInsight: primaryInsight,
            drivers: alignedHeroDrivers(
                primaryInsight: primaryInsight,
                drivers: input.insightsResult.drivers
            ),
            changes: Array(input.insightsResult.changes.prefix(2)),
            actions: alignedActions,
            availableWeight: totalWeight
        )
    }
}

private extension SQLifeScoreBuilder {
    func lifeScoreAlignedActions(
        _ actions: [SQInsightAction],
        state: SQLifeScoreState,
        score: Int?,
        scoreDeltaFromPreviousDay: Int?,
        components: [SQLifeScoreComponent]
    ) -> [SQInsightAction] {
        let limitedActions = Array(actions.prefix(1))
        guard shouldCautionLifeScoreTraining(
            state: state,
            score: score,
            scoreDeltaFromPreviousDay: scoreDeltaFromPreviousDay,
            components: components
        ) else {
            return limitedActions
        }

        guard let action = limitedActions.first else { return [] }
        guard isTrainingPushAction(action.summary) else { return limitedActions }

        return [
            .init(
                id: "\(action.id)-life-score-caution",
                title: "Watch Today",
                summary: lifeScoreCautionActionSummary(state: state, components: components),
                context: action.context,
                tone: .caution,
                rankingScore: action.rankingScore
            )
        ]
    }

    func shouldCautionLifeScoreTraining(
        state: SQLifeScoreState,
        score: Int?,
        scoreDeltaFromPreviousDay: Int?,
        components: [SQLifeScoreComponent]
    ) -> Bool {
        if state == .dipping || state == .underPressure {
            return true
        }

        if (score ?? 100) < 72 {
            return true
        }

        if (scoreDeltaFromPreviousDay ?? 0) < 0,
           (score ?? 100) < 80 {
            return true
        }

        return components.contains { component in
            switch component.id {
            case "sleep":
                return component.score < 72
            case "heart", "habits":
                return component.score < 65
            default:
                return false
            }
        }
    }

    func lifeScoreCautionActionSummary(
        state: SQLifeScoreState,
        components: [SQLifeScoreComponent]
    ) -> String {
        if let sleepScore = componentScore("sleep", in: components), sleepScore < 72 {
            return "Keep training moderate until sleep and recovery look stronger."
        }

        if let heartScore = componentScore("heart", in: components), heartScore < 65 {
            return "Keep strain moderate while heart recovery is still soft."
        }

        if state == .dipping {
            return "Keep strain moderate while the score is dipping."
        }

        return "Protect recovery before adding extra intensity."
    }

    func componentScore(_ id: String, in components: [SQLifeScoreComponent]) -> Int? {
        components.first { $0.id == id }?.score
    }

    func isTrainingPushAction(_ summary: String) -> Bool {
        let normalizedSummary = normalizedHeroMatchText(summary)
        return normalizedSummary.contains("push harder")
            || normalizedSummary.contains("push training")
            || normalizedSummary.contains("good day to push")
    }

    func lifeScoreRefinementPromptText(for intelligenceInput: SQHealthIntelligenceInput) -> String? {
        guard intelligenceInput.timeRange == .today,
              intelligenceInput.isLoggedIn,
              let currentCheckInPromptPeriod = intelligenceInput.currentCheckInPromptPeriod,
              !intelligenceInput.hasCompletedCurrentPromptCheckIn else {
            return nil
        }

        let periodTitle: String
        switch currentCheckInPromptPeriod {
        case .morning:
            periodTitle = "morning"
        case .evening:
            periodTitle = "evening"
        case .unknown:
            return "Complete your check-in to refine today's score."
        }

        return "Complete your \(periodTitle) check-in to refine today's score."
    }

    func alignedHeroDrivers(
        primaryInsight: SQInsight?,
        drivers: [SQInsightDriver]
    ) -> [SQInsightDriver] {
        guard let primaryInsight else { return Array(drivers.prefix(3)) }

        let normalizedInsightText = normalizedHeroMatchText(
            [
                primaryInsight.title,
                primaryInsight.summary,
                primaryInsight.driverText,
                primaryInsight.outcomeText
            ]
            .joined(separator: " ")
        )

        let exactMatches = drivers.filter { driver in
            let driverTitle = normalizedHeroMatchText(driver.title)
            return normalizedInsightText.contains(driverTitle)
        }

        let categoryMatches = drivers.filter { driver in
            driver.category == primaryInsight.category && !exactMatches.contains(driver)
        }

        let remainingDrivers = drivers.filter { driver in
            !exactMatches.contains(driver) && !categoryMatches.contains(driver)
        }

        var alignedDrivers = exactMatches + categoryMatches + remainingDrivers

        if let synthesizedDriver = synthesizedHeroDriver(from: primaryInsight) {
            let normalizedSynthesizedTitle = normalizedHeroMatchText(synthesizedDriver.title)

            alignedDrivers.removeAll { driver in
                normalizedHeroMatchText(driver.title) == normalizedSynthesizedTitle
            }

            alignedDrivers.insert(synthesizedDriver, at: 0)
        }

        return Array(alignedDrivers.prefix(3))
    }

    func synthesizedHeroDriver(from primaryInsight: SQInsight) -> SQInsightDriver? {
        let normalizedText = normalizedHeroMatchText(
            [
                primaryInsight.title,
                primaryInsight.summary,
                primaryInsight.driverText,
                primaryInsight.outcomeText
            ]
            .joined(separator: " ")
        )

        let synthesizedTitle: String
        let signalId: String

        if normalizedText.contains("sleep") {
            synthesizedTitle = "Sleep"
            signalId = SQMetricId.sleepQuality
        } else if normalizedText.contains("resting hr") || normalizedText.contains("resting heart") {
            synthesizedTitle = "Resting HR"
            signalId = SQInsightAnalysisMetricId.restingHeartRate
        } else if normalizedText.contains("energy") {
            synthesizedTitle = "Energy"
            signalId = SQMetricId.energy
        } else if normalizedText.contains("mental clarity") || normalizedText.contains("clarity") {
            synthesizedTitle = "Mental Clarity"
            signalId = SQMetricId.mentalClarity
        } else if normalizedText.contains("mood") {
            synthesizedTitle = "Mood"
            signalId = SQMetricId.mood
        } else if normalizedText.contains("motivation") {
            synthesizedTitle = "Motivation"
            signalId = SQMetricId.motivation
        } else if normalizedText.contains("stress") {
            synthesizedTitle = "Stress"
            signalId = SQMetricId.stress
        } else if normalizedText.contains("anxiety") {
            synthesizedTitle = "Anxiety"
            signalId = SQMetricId.anxiety
        } else if normalizedText.contains("soreness") {
            synthesizedTitle = "Soreness"
            signalId = SQMetricId.soreness
        } else if normalizedText.contains("recovery") {
            synthesizedTitle = "Recovery"
            signalId = "hero.recovery"
        } else if normalizedText.contains("strain") {
            synthesizedTitle = "Strain"
            signalId = "hero.strain"
        } else if normalizedText.contains("performance") {
            synthesizedTitle = "Performance"
            signalId = SQInsightAnalysisMetricId.workoutPerformance
        } else {
            return nil
        }

        return .init(
            id: "hero-synth-\(signalId)",
            signalId: signalId,
            title: synthesizedTitle,
            summary: primaryInsight.summary,
            category: primaryInsight.category,
            direction: primaryInsight.effect == .negative ? .drag : .supportive,
            recentAverage: 0,
            baselineAverage: 0,
            deltaText: primaryInsight.deltaText,
            effectMagnitude: 0,
            rankingScore: primaryInsight.rankingScore
        )
    }

    func normalizedHeroMatchText(_ text: String) -> String {
        text.lowercased()
            .replacingOccurrences(of: "sleep quality", with: "sleep")
            .replacingOccurrences(of: "sleep hours", with: "sleep")
            .replacingOccurrences(of: "resting heart rate", with: "resting hr")
            .replacingOccurrences(of: "mental clarity", with: "clarity")
            .replacingOccurrences(of: "running performance", with: "performance")
            .replacingOccurrences(of: "cycling performance", with: "performance")
            .replacingOccurrences(of: "walking performance", with: "performance")
            .replacingOccurrences(of: "pickleball performance", with: "performance")
            .replacingOccurrences(of: "workout performance", with: "performance")
    }

    func estimatedPreviousDayLifeScore(
        referenceDate: Date,
        checkIns: [SQDailyCheckInStats],
        sleepCheckIns: [SQDailyCheckInStats],
        workouts: [SQWorkoutSessionable],
        metricDefinitions: [SQMetricDefinition],
        sleepData: SQSleepDashboardData?,
        restingHeartRateSummaries: [SQHeartRateDailySummary],
        isLoggedIn: Bool
    ) -> Int? {
        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: referenceDate)
        let startOfYesterday = calendar.date(byAdding: .day, value: -1, to: startOfToday) ?? startOfToday
        let startOfPriorWeek = calendar.date(byAdding: .day, value: -7, to: startOfYesterday) ?? startOfYesterday

        var components = [SQLifeScoreComponent]()

        if let sleepComponent = previousLifeScoreSleepComponent(
            checkIns: checkIns,
            sleepCheckIns: sleepCheckIns,
            referenceDate: referenceDate,
            sleepData: sleepData
        ) {
            components.append(sleepComponent)
        }

        if let heartComponent = lifeScoreHeartComponent(
            from: restingHeartRateSummaries,
            referenceDate: startOfYesterday
        ) {
            components.append(heartComponent)
        }

        let priorCheckIns = checkIns.filter {
            let day = calendar.startOfDay(for: $0.date)
            return day >= startOfPriorWeek && day < startOfToday
        }

        if let habitsComponent = lifeScoreHabitsComponent(
            from: priorCheckIns,
            metricDefinitions: metricDefinitions,
            referenceDate: startOfYesterday
        ) {
            components.append(habitsComponent)
        }

        let priorWeekWorkouts = workouts.filter {
            guard let startDate = $0.startDate else { return false }
            let day = calendar.startOfDay(for: startDate)
            return day >= startOfPriorWeek && day < startOfToday
        }

        let yesterdaysWorkouts = priorWeekWorkouts.filter {
            guard let startDate = $0.startDate else { return false }
            return calendar.isDate(startDate, inSameDayAs: startOfYesterday)
        }

        if let workoutsComponent = lifeScoreWorkoutComponent(
            todaysWorkouts: yesterdaysWorkouts,
            lastWeekWorkouts: priorWeekWorkouts
        ) {
            components.append(workoutsComponent)
        }

        if let consistencyComponent = lifeScoreConsistencyComponent(
            past7DaysCheckIns: priorCheckIns,
            hasCompletedCurrentCheckIn: priorCheckIns.contains {
                calendar.isDate($0.date, inSameDayAs: startOfYesterday)
            },
            isLoggedIn: isLoggedIn
        ) {
            components.append(consistencyComponent)
        }

        let totalWeight = components.reduce(0) { $0 + $1.weight }
        guard totalWeight > 0 else { return nil }

        let weightedScore = components.reduce(0) { $0 + (Double($1.score) * $1.weight) } / totalWeight
        return Int(weightedScore.rounded())
    }

    func lifeScoreState(
        score: Int?,
        availableWeight: Double,
        scoreDeltaFromPreviousDay: Int?,
        components: [SQLifeScoreComponent],
        drivers: [SQInsightDriver],
        primaryInsight: SQInsight?
    ) -> SQLifeScoreState {
        guard let score else { return .calibrating }
        guard availableWeight >= 45 else { return .calibrating }

        let componentScores = Dictionary(uniqueKeysWithValues: components.map { ($0.id, $0.score) })
        let sleepScore = componentScores["sleep"]
        let heartScore = componentScores["heart"]
        let habitsScore = componentScores["habits"]
        let workoutsScore = componentScores["workouts"]
        let consistencyScore = componentScores["consistency"]

        let lowComponentCount = components.filter { $0.score < 60 }.count
        let softDragComponentCount = components.filter { $0.score < 72 }.count
        let strongComponentCount = components.filter { $0.score >= 85 }.count

        let stateDrivers = drivers.filter { isLifeScoreStateSignalId($0.signalId) }
        let supportiveDrivers = stateDrivers.filter { $0.direction == .supportive }
        let dragDrivers = stateDrivers.filter { $0.direction == .drag }

        let strongNegativeMomentum = (scoreDeltaFromPreviousDay ?? 0) <= -7
        let negativeMomentum = (scoreDeltaFromPreviousDay ?? 0) <= -4
        let positiveMomentum = (scoreDeltaFromPreviousDay ?? 0) >= 4

        let hasRecoveryDrag = (sleepScore ?? 100) < 62
            || (heartScore ?? 100) < 58
            || dragDrivers.contains { recoveryPressureSignalIds.contains($0.signalId) }
        let hasMentalPressure = dragDrivers.contains { mentalPressureSignalIds.contains($0.signalId) }
        let hasTrainingPressure = dragDrivers.contains { trainingPressureSignalIds.contains($0.signalId) }
        let hasReadinessLift = supportiveDrivers.contains { readinessLiftSignalIds.contains($0.signalId) }
        let hasTrainingLift = supportiveDrivers.contains { trainingLiftSignalIds.contains($0.signalId) }

        let primaryInsightText = normalizedHeroMatchText(
            [
                primaryInsight?.title ?? "",
                primaryInsight?.summary ?? ""
            ]
            .joined(separator: " ")
        )
        let insightSuggestsPressure = primaryInsight?.effect == .negative
            || primaryInsightText.contains("under pressure")
            || primaryInsightText.contains("dragging")
            || primaryInsightText.contains("stress")
            || primaryInsightText.contains("anxiety")
        let insightSuggestsLift = primaryInsight?.effect == .positive
            || primaryInsightText.contains("helping")
            || primaryInsightText.contains("setting up a good day")

        if score < 56
            || lowComponentCount >= 2
            || (hasRecoveryDrag && (hasMentalPressure || hasTrainingPressure))
            || ((habitsScore ?? 100) < 42 && (sleepScore ?? 100) < 72) {
            return .underPressure
        }

        if strongNegativeMomentum && (score < 82 || softDragComponentCount >= 1 || insightSuggestsPressure) {
            return .dipping
        }

        if negativeMomentum && (score < 78 || hasMentalPressure || hasTrainingPressure || softDragComponentCount >= 2) {
            return .dipping
        }

        if positiveMomentum
            && score >= 72
            && score < 88
            && lowComponentCount == 0
            && !hasRecoveryDrag
            && !hasMentalPressure {
            return .rebounding
        }

        if score >= 90
            && strongComponentCount >= 3
            && !hasRecoveryDrag
            && !hasMentalPressure
            && !negativeMomentum {
            return .strong
        }

        if score >= 84
            && !hasRecoveryDrag
            && !negativeMomentum
            && (hasReadinessLift
                || hasTrainingLift
                || insightSuggestsLift
                || (sleepScore ?? 0) >= 85
                || (heartScore ?? 0) >= 82
                || (workoutsScore ?? 0) >= 78) {
            return .primed
        }

        if score >= 78
            && softDragComponentCount <= 1
            && !negativeMomentum
            && (consistencyScore ?? 100) >= 55 {
            return .balanced
        }

        if score >= 66
            || (score >= 60 && lowComponentCount == 0) {
            return .slightlyOff
        }

        return .underPressure
    }

    func isLifeScoreStateSignalId(_ signalId: String) -> Bool {
        readinessLiftSignalIds.contains(signalId)
            || mentalPressureSignalIds.contains(signalId)
            || trainingPressureSignalIds.contains(signalId)
    }

    var readinessLiftSignalIds: Set<String> {
        [
            SQMetricId.sleepHours,
            SQMetricId.sleepQuality,
            SQInsightAnalysisMetricId.restingHeartRate,
            SQMetricId.energy,
            SQMetricId.mood,
            SQMetricId.mentalClarity,
            SQMetricId.motivation,
            SQInsightAnalysisMetricId.workoutPerformance
        ]
    }

    var mentalPressureSignalIds: Set<String> {
        [
            SQMetricId.stress,
            SQMetricId.anxiety,
            SQMetricId.mood,
            SQMetricId.energy,
            SQMetricId.mentalClarity
        ]
    }

    var recoveryPressureSignalIds: Set<String> {
        [
            SQMetricId.sleepHours,
            SQMetricId.sleepQuality,
            SQInsightAnalysisMetricId.restingHeartRate,
            SQMetricId.soreness,
            SQMetricId.stress,
            SQMetricId.anxiety
        ]
    }

    var trainingPressureSignalIds: Set<String> {
        [
            SQInsightAnalysisMetricId.workoutDifficulty,
            SQInsightAnalysisMetricId.workoutPerformance,
            SQMetricId.soreness,
            SQMetricId.motivation
        ]
    }

    var trainingLiftSignalIds: Set<String> {
        [
            SQMetricId.motivation,
            SQInsightAnalysisMetricId.workoutPerformance,
            SQMetricId.energy
        ]
    }

    func lifeScoreSleepComponent(
        checkIns: [SQDailyCheckInStats],
        sleepCheckIns: [SQDailyCheckInStats] = [],
        referenceDate: Date,
        sleepData: SQSleepDashboardData?
    ) -> SQLifeScoreComponent? {
        guard let sleepInput = sleepComponentInput(
            checkIns: resolvedSleepCheckIns(from: checkIns, explicitSleepCheckIns: sleepCheckIns),
            targetDay: referenceDate,
            sleepData: sleepData,
            usePreviousHealthNight: false
        ) else {
            return nil
        }

        return lifeScoreSleepComponent(
            for: sleepInput.score,
            durationHours: sleepInput.durationHours
        )
    }

    func previousLifeScoreSleepComponent(
        checkIns: [SQDailyCheckInStats],
        sleepCheckIns: [SQDailyCheckInStats] = [],
        referenceDate: Date,
        sleepData: SQSleepDashboardData?
    ) -> SQLifeScoreComponent? {
        let calendar = Calendar.current
        let targetDay = calendar.date(byAdding: .day, value: -1, to: referenceDate) ?? referenceDate
        guard let sleepInput = sleepComponentInput(
            checkIns: resolvedSleepCheckIns(from: checkIns, explicitSleepCheckIns: sleepCheckIns),
            targetDay: targetDay,
            sleepData: sleepData,
            usePreviousHealthNight: true
        ) else {
            return nil
        }

        return lifeScoreSleepComponent(
            for: sleepInput.score,
            durationHours: sleepInput.durationHours
        )
    }

    struct LifeScoreSleepInput {
        let score: Double
        let durationHours: Double?
    }

    func sleepComponentInput(
        checkIns: [SQDailyCheckInStats],
        targetDay: Date,
        sleepData: SQSleepDashboardData?,
        usePreviousHealthNight: Bool
    ) -> LifeScoreSleepInput? {
        let calendar = Calendar.current
        let targetCheckIn = checkIns
            .filter { calendar.isDate($0.date, inSameDayAs: targetDay) }
            .sorted { $0.date < $1.date }
            .last

        let sleepQuality = targetCheckIn?.values[SQMetricId.sleepQuality].map { clamp(Double($0), min: 0, max: 10) }
        let sleepHours = targetCheckIn?.values[SQMetricId.sleepHours].map { clamp(Double($0), min: 0, max: 24) }

        if let sleepQuality {
            let qualityScore = sleepQuality * 10
            if let sleepHours {
                let durationScore = sleepDurationScore(hours: sleepHours)
                return .init(
                    score: (qualityScore * 0.75) + (durationScore * 0.25),
                    durationHours: sleepHours
                )
            }

            return .init(score: qualityScore, durationHours: sleepHours)
        }

        if let sleepHours {
            return .init(
                score: sleepDurationScore(hours: sleepHours),
                durationHours: sleepHours
            )
        }

        if usePreviousHealthNight {
            if let priorNight = sleepData?.priorNights.sorted(by: { $0.wakeDay < $1.wakeDay }).last {
                return .init(
                    score: sleepAggregationService.score(for: priorNight).totalScore,
                    durationHours: priorNight.totalSleepDuration / 3600.0
                )
            }

            if let averageScore = sleepData?.priorNights
                .map({ sleepAggregationService.score(for: $0).totalScore })
                .average {
                let averageDuration = sleepData?.priorNights.map(\.totalSleepDuration).average.map { $0 / 3600.0 }
                return .init(score: averageScore, durationHours: averageDuration)
            }

            return nil
        }

        if let latestNight = sleepData?.latestNight {
            return .init(
                score: sleepAggregationService.score(for: latestNight).totalScore,
                durationHours: latestNight.totalSleepDuration / 3600.0
            )
        }

        if let averageScore = sleepData?.averageScore?.totalScore {
            let averageDuration = sleepData?.currentNights.map(\.totalSleepDuration).average.map { $0 / 3600.0 }
            return .init(score: averageScore, durationHours: averageDuration)
        }

        return nil
    }

    func resolvedSleepCheckIns(
        from checkIns: [SQDailyCheckInStats],
        explicitSleepCheckIns: [SQDailyCheckInStats]
    ) -> [SQDailyCheckInStats] {
        if !explicitSleepCheckIns.isEmpty {
            return explicitSleepCheckIns
        }

        let morningCheckIns = checkIns.filter { $0.period == .morning }
        if !morningCheckIns.isEmpty {
            return morningCheckIns
        }

        return checkIns
    }

    func lifeScoreSleepComponent(for sleepScore: Double?, durationHours: Double?) -> SQLifeScoreComponent? {
        guard let sleepScore else { return nil }
        let roundedScore = adjustedLifeScoreSleepComponentScore(
            rawSleepScore: sleepScore,
            durationHours: durationHours
        )

        let summary: String
        switch roundedScore {
        case 85...:
            summary = "Sleep looked strong and should be helping recovery."
        case 70...84:
            summary = "Sleep was decent, but not elite enough to fully lift the day."
        case 55...69:
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

    func adjustedLifeScoreSleepComponentScore(
        rawSleepScore: Double,
        durationHours: Double?
    ) -> Int {
        var adjustedScore = rawSleepScore

        if rawSleepScore < 90 {
            adjustedScore -= (90 - rawSleepScore) * 0.35
        }

        if let durationHours {
            switch durationHours {
            case ..<5.5:
                adjustedScore -= 18
            case ..<6.5:
                adjustedScore -= 11
            case ..<7.25:
                adjustedScore -= 5
            case 9.75...:
                adjustedScore -= 4
            default:
                break
            }
        }

        return Int(clamp(adjustedScore, min: 20, max: 98).rounded())
    }

    func sleepDurationScore(hours: Double) -> Double {
        if hours >= 7, hours <= 9 {
            return 100
        }

        if hours < 7 {
            return clamp(100 - ((7 - hours) * 18), min: 0, max: 100)
        }

        return clamp(100 - ((hours - 9) * 12), min: 0, max: 100)
    }

    func lifeScoreHeartComponent(
        from restingHeartRateSummaries: [SQHeartRateDailySummary],
        referenceDate: Date
    ) -> SQLifeScoreComponent? {
        let calendar = Calendar.current
        let startOfReferenceDay = calendar.startOfDay(for: referenceDate)
        let summaries = restingHeartRateSummaries
            .filter { $0.average != nil }
            .sorted { $0.date < $1.date }
            .filter { calendar.startOfDay(for: $0.date) <= startOfReferenceDay }

        guard let latestSummary = summaries.last,
              let latestAverage = latestSummary.average else {
            return nil
        }

        let daysSinceLatest = calendar.dateComponents(
            [.day],
            from: calendar.startOfDay(for: latestSummary.date),
            to: startOfReferenceDay
        ).day ?? 0
        guard daysSinceLatest <= 2 else { return nil }

        let recentSummaries = Array(summaries.suffix(2))
        let baselineSummaries = Array(summaries.dropLast(recentSummaries.count).suffix(7))

        guard recentSummaries.count >= 1,
              baselineSummaries.count >= 3,
              let recentAverage = recentSummaries.compactMap(\.average).average,
              let baselineAverage = baselineSummaries.compactMap(\.average).average else {
            return nil
        }

        let delta = recentAverage - baselineAverage
        let roundedScore = Int(clamp(78 - (delta * 8), min: 30, max: 95).rounded())

        let summary: String
        switch delta {
        case ...(-2):
            summary = "Resting HR is lower than usual and should be helping recovery."
        case ...1:
            summary = "Resting HR is close to your usual range and looks stable."
        case ...4:
            summary = "Resting HR is a bit elevated versus your usual range."
        default:
            summary = "Resting HR is elevated enough to drag recovery today."
        }

        return .init(
            id: "heart",
            title: "Heart",
            score: roundedScore,
            summary: summary,
            weight: 20,
            detailItems: [
                .init(
                    id: "resting-heart-rate",
                    title: "Resting HR",
                    valueText: "\(formattedWholeNumber(latestAverage)) bpm vs \(formattedWholeNumber(baselineAverage)) baseline",
                    summary: summary,
                    effect: delta <= 1 ? .positive : .negative
                )
            ]
        )
    }

    func lifeScoreHabitsComponent(
        from recentCheckIns: [SQDailyCheckInStats],
        metricDefinitions: [SQMetricDefinition],
        referenceDate: Date
    ) -> SQLifeScoreComponent? {
        let sevenDayValues = averagedMetricValues(from: recentCheckIns)
        let recentValues = weightedRecentMetricValues(
            from: recentCheckIns,
            referenceDate: referenceDate,
            maxDays: 2
        )
        guard !sevenDayValues.isEmpty || !recentValues.isEmpty else { return nil }

        let trackedDefinitions = metricDefinitions
            .filter { $0.isEnabled && !$0.isArchived }

        let scoredHabits = trackedDefinitions
            .filter { sevenDayValues[$0.id] != nil || recentValues[$0.id] != nil }
            .filter { $0.goalStyle != .justTrack && $0.goalStyle != .unknown }
            .compactMap { definition -> (definition: SQMetricDefinition, value: Double, score: Double, item: SQLifeScoreDetailItem)? in
                let sevenDayValue = sevenDayValues[definition.id]
                let recentValue = recentValues[definition.id]
                guard let baselineValue = sevenDayValue ?? recentValue,
                      let baselineScore = habitScore(for: baselineValue, definition: definition) else {
                    return nil
                }

                let recentScore = recentValue.flatMap { habitScore(for: $0, definition: definition) }
                let blendedScore = blendedHabitScore(
                    baselineScore: baselineScore,
                    recentScore: recentScore
                )
                let effect = habitEffect(for: recentValue ?? baselineValue, score: blendedScore, definition: definition)
                let valueText = habitValueText(
                    sevenDayValue: sevenDayValue,
                    recentValue: recentValue,
                    definition: definition
                )

                return (
                    definition: definition,
                    value: recentValue ?? baselineValue,
                    score: blendedScore,
                    item: .init(
                        id: definition.id,
                        title: definition.title,
                        valueText: valueText,
                        summary: habitScoreSummary(
                            sevenDayValue: sevenDayValue,
                            recentValue: recentValue,
                            score: blendedScore,
                            definition: definition
                        ),
                        effect: effect
                    )
                )
            }

        guard !scoredHabits.isEmpty else { return nil }
        let averageScore = scoredHabits.map(\.score).reduce(0, +) / Double(scoredHabits.count)
        let vicePenalty = recentVicePenalty(
            from: recentValues,
            trackedDefinitions: trackedDefinitions
        )
        let adjustedScore = averageScore - vicePenalty
        let roundedScore = Int(clamp(adjustedScore, min: 0, max: 100).rounded())

        let positiveCount = scoredHabits.filter { $0.item.effect == .positive }.count
        let negativeCount = scoredHabits.filter { $0.item.effect == .negative }.count

        let summary: String
        if vicePenalty >= 10 {
            summary = "Recent vice-heavy days are weighing on the score more than usual."
        } else if positiveCount > 0 && negativeCount > 0 {
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

    func blendedHabitScore(
        baselineScore: Double,
        recentScore: Double?
    ) -> Double {
        guard let recentScore else { return baselineScore }
        return (baselineScore * 0.45) + (recentScore * 0.55)
    }

    func weightedRecentMetricValues(
        from stats: [SQDailyCheckInStats],
        referenceDate: Date,
        maxDays: Int
    ) -> [String: Double] {
        let calendar = Calendar.current
        let startOfReferenceDay = calendar.startOfDay(for: referenceDate)
        var weightedValues: [String: [(value: Double, weight: Double)]] = [:]

        for stat in stats {
            let dayStart = calendar.startOfDay(for: stat.date)
            let dayOffset = calendar.dateComponents([.day], from: dayStart, to: startOfReferenceDay).day ?? maxDays
            guard dayOffset >= 0, dayOffset < maxDays else { continue }

            let weight: Double = dayOffset == 0 ? 1.0 : 0.7
            for (metricId, value) in stat.values {
                weightedValues[metricId, default: []].append((Double(value), weight))
            }
        }

        return weightedValues.reduce(into: [String: Double]()) { partialResult, pair in
            let totalWeight = pair.value.reduce(0) { $0 + $1.weight }
            guard totalWeight > 0 else { return }
            let weightedSum = pair.value.reduce(0) { $0 + ($1.value * $1.weight) }
            partialResult[pair.key] = weightedSum / totalWeight
        }
    }

    func recentVicePenalty(
        from recentValues: [String: Double],
        trackedDefinitions: [SQMetricDefinition]
    ) -> Double {
        let definitionsById = Dictionary(uniqueKeysWithValues: trackedDefinitions.map { ($0.id, $0) })

        let alcoholPenalty = recentValues[SQMetricId.alcohol].map {
            clamp($0 * 4.2, min: 0, max: 18)
        } ?? 0
        let caffeinePenalty = recentValues[SQMetricId.caffeine].map {
            clamp(($0 - 120.0) / 30.0, min: 0, max: 7)
        } ?? 0

        func normalizedPenalty(metricId: String, maxPenalty: Double) -> Double {
            guard let value = recentValues[metricId],
                  let definition = definitionsById[metricId],
                  let normalized = normalizedMetricValue(value, definition: definition) else {
                return 0
            }

            return clamp(normalized * maxPenalty, min: 0, max: maxPenalty)
        }

        let weedPenalty = normalizedPenalty(metricId: SQMetricId.weed, maxPenalty: 10)
        let nicotinePenalty = normalizedPenalty(metricId: SQMetricId.nicotine, maxPenalty: 9)
        let pornPenalty = normalizedPenalty(metricId: SQMetricId.porn, maxPenalty: 5)

        return clamp(
            alcoholPenalty + caffeinePenalty + weedPenalty + nicotinePenalty + pornPenalty,
            min: 0,
            max: 24
        )
    }

    func lifeScoreWorkoutComponent(
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

    func lifeScoreConsistencyComponent(
        past7DaysCheckIns: [SQDailyCheckInStats],
        hasCompletedCurrentCheckIn: Bool,
        isLoggedIn: Bool
    ) -> SQLifeScoreComponent? {
        guard isLoggedIn else { return nil }

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

    func averagedMetricValues(from stats: [SQDailyCheckInStats]) -> [String: Double] {
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

    func clamp(_ value: Double, min minimum: Double, max maximum: Double) -> Double {
        Swift.max(minimum, Swift.min(maximum, value))
    }

    func formattedWholeNumber(_ value: Double) -> String {
        String(Int(value.rounded()))
    }

    func habitScore(for value: Double, definition: SQMetricDefinition) -> Double? {
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

    func inverseScore(value: Double, target: Double, upperBound: Double) -> Double {
        guard upperBound > target else {
            return value <= target ? 100 : 0
        }

        if value <= target {
            return 100
        }

        return clamp((1 - ((value - target) / (upperBound - target))) * 100, min: 0, max: 100)
    }

    func normalizedMetricValue(_ value: Double, definition: SQMetricDefinition) -> Double? {
        guard
            let min = definition.min.map(Double.init),
            let max = definition.max.map(Double.init),
            max > min
        else {
            return nil
        }

        return clamp((value - min) / (max - min), min: 0, max: 1)
    }

    func keepLowUpperBound(for definition: SQMetricDefinition, target: Double) -> Double {
        let maxValue = Double(definition.max ?? Float(target + 1))
        return max(maxValue, target + 1)
    }

    func formattedMetricValue(_ value: Double, definition: SQMetricDefinition) -> String {
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

    func habitValueText(
        sevenDayValue: Double?,
        recentValue: Double?,
        definition: SQMetricDefinition
    ) -> String {
        switch (sevenDayValue, recentValue) {
        case let (.some(sevenDayValue), .some(recentValue)):
            return "7d avg \(formattedMetricValue(sevenDayValue, definition: definition)) • recent \(formattedMetricValue(recentValue, definition: definition))"
        case let (.some(sevenDayValue), .none):
            return "7d avg \(formattedMetricValue(sevenDayValue, definition: definition))"
        case let (.none, .some(recentValue)):
            return "recent \(formattedMetricValue(recentValue, definition: definition))"
        case (.none, .none):
            return "Tracked"
        }
    }

    func habitScoreSummary(
        sevenDayValue: Double?,
        recentValue: Double?,
        score: Double,
        definition: SQMetricDefinition
    ) -> String {
        let comparisonValue = sevenDayValue ?? recentValue ?? 0

        switch definition.goalStyle {
        case .buildUp:
            if let target = definition.targetValue {
                return comparisonValue >= Double(target)
                    ? "Your 7-day average met or exceeded the target of \(formattedTarget(target, definition: definition))."
                    : "Your 7-day average stayed below the target of \(formattedTarget(target, definition: definition))."
            }
            return score >= 70
                ? "Your recent average is moving in a supportive direction."
                : "Your recent average still wants a higher range."

        case .keepLow:
            if let target = definition.targetValue {
                return comparisonValue <= Double(target)
                    ? "Your 7-day average stayed at or below the target of \(formattedTarget(target, definition: definition))."
                    : "Your 7-day average ran above the target of \(formattedTarget(target, definition: definition))."
            }
            return score >= 70
                ? "Your recent average stayed reasonably low."
                : "Your recent average has been running higher than ideal."

        case .avoidIt:
            if comparisonValue <= 0 {
                return "Your recent average stayed at zero, which is strongly supportive."
            }

            return score >= 55
                ? "Your recent average was above zero, so it slightly lowered this score."
                : "Your recent average was high enough to clearly lower this score."

        case .stayInRange:
            let minText = definition.targetRangeMin.map { formattedTarget($0, definition: definition) } ?? "?"
            let maxText = definition.targetRangeMax.map { formattedTarget($0, definition: definition) } ?? "?"
            return comparisonValue >= Double(definition.targetRangeMin ?? 0) && comparisonValue <= Double(definition.targetRangeMax ?? 0)
                ? "Your 7-day average stayed inside the target range of \(minText)-\(maxText)."
                : "Your 7-day average sat outside the target range of \(minText)-\(maxText)."

        case .justTrack, .unknown:
            return "Tracked for awareness."
        }
    }

    func habitEffect(for value: Double, score: Double, definition: SQMetricDefinition) -> SQLifeScoreSignalEffect {
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

    func habitEffect(
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

    func formattedTarget(_ value: Float, definition: SQMetricDefinition) -> String {
        formattedMetricValue(Double(value), definition: definition)
    }

    func lifeScoreEffectPriority(_ effect: SQLifeScoreSignalEffect) -> Int {
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

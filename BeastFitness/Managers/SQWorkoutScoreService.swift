//
//  SQWorkoutScoreService.swift
//  BeastFitness
//

import Foundation
import HealthKit
import SwiftUI
import BeastFitnessCore

enum SQWorkoutScoreKind: String, CaseIterable, Identifiable {
    case performance
    case difficulty

    var id: String { rawValue }

    var title: String {
        switch self {
        case .performance:
            return "Performance"
        case .difficulty:
            return "Difficulty"
        }
    }

    var accentColor: SQColor {
        switch self {
        case .performance:
            return .dashboardGlowBlue
        case .difficulty:
            return .dashboardTrendWarm
        }
    }
}

enum SQWorkoutPremiumInsightAvailability: Equatable {
    case available
    case locked
}

struct SQWorkoutPremiumInsightScore: Identifiable {
    let id: String
    let kind: SQWorkoutScoreKind
    let title: String
    let value: Int
    let headline: String
    let detail: String
    let accentColor: SQColor
    let detailModel: SQWorkoutPremiumInsightDetailModel
}

struct SQWorkoutPremiumInsightsModel {
    let title: String
    let subtitle: String
    let badgeTitle: String
    let availability: SQWorkoutPremiumInsightAvailability
    let scores: [SQWorkoutPremiumInsightScore]
    let footer: String
    let lockedTitle: String?
    let lockedSubtitle: String?
}

struct SQWorkoutPremiumInsightDetailModel {
    struct DefinitionLine: Identifiable {
        let id: String
        let valueText: String
        let summaryText: String
    }

    struct ScoreCard: Identifiable {
        let id: String
        let title: String
        let value: String
        let caption: String
        let accentColor: SQColor
    }

    struct Component: Identifiable {
        let id: String
        let title: String
        let value: String
        let detail: String
        let accentColor: SQColor
        let definitionLines: [DefinitionLine]

        init(
            id: String,
            title: String,
            value: String,
            detail: String,
            accentColor: SQColor,
            definitionLines: [DefinitionLine] = []
        ) {
            self.id = id
            self.title = title
            self.value = value
            self.detail = detail
            self.accentColor = accentColor
            self.definitionLines = definitionLines
        }
    }

    struct Example: Identifiable {
        let id: String
        let range: String
        let title: String
        let detail: String
    }

    let title: String
    let subtitle: String
    let summary: String
    let scoreCards: [ScoreCard]
    let components: [Component]
    let examples: [Example]
    let footnote: String?
}

@MainActor
protocol SQWorkoutScoreServicing {
    func insights(
        for workout: SQWorkoutSessionable,
        allTimeWorkouts: [SQWorkoutSessionable],
        isPremiumUnlocked: Bool
    ) async -> SQWorkoutPremiumInsightsModel?

    func dashboardInsights(
        for workouts: [SQWorkoutSessionable],
        allTimeWorkouts: [SQWorkoutSessionable],
        isPremiumUnlocked: Bool
    ) async -> SQWorkoutPremiumInsightsModel?

    func dashboardPerformanceRows(
        for workouts: [SQWorkoutSessionable],
        allTimeWorkouts: [SQWorkoutSessionable],
        isPremiumUnlocked: Bool
    ) async -> [SQPerformanceRowData]

    func activityScoreItems(
        for workouts: [SQWorkoutSessionable],
        allTimeWorkouts: [SQWorkoutSessionable],
        isPremiumUnlocked: Bool
    ) async -> [HKWorkoutActivityType: [SQDashboardWorkoutGroupViewModel.WorkoutStatItem]]

    func leaderboardRows(
        for kind: SQWorkoutScoreKind,
        activityType: HKWorkoutActivityType,
        workouts: [SQWorkoutSessionable],
        allTimeWorkouts: [SQWorkoutSessionable]
    ) async -> [SQLeaderboardRowViewModel]
}

@MainActor
final class SQWorkoutScoreService: SQWorkoutScoreServicing {
    private let heartRateService: SQHeartRateServicing

    /// Running-specific performance inputs.
    fileprivate struct RunningSample {
        let workout: SQWorkoutSessionable
        let distanceMiles: Double
        let paceSecondsPerMile: Double
        let durationSeconds: Double
        let averageHeartRate: Double?
        let calories: Double?
        let vdot: Double
    }

    fileprivate struct CyclingSample {
        let workout: SQWorkoutSessionable
        let distanceMiles: Double
        let durationSeconds: Double
        let averageHeartRate: Double?
        let calories: Double?
        let averageSpeedMilesPerHour: Double
        let outputEstimate: Double
    }

    fileprivate enum PerformanceSample {
        case running(RunningSample)
        case cycling(CyclingSample)

        var workout: SQWorkoutSessionable {
            switch self {
            case .running(let sample):
                return sample.workout
            case .cycling(let sample):
                return sample.workout
            }
        }

        var historyValue: Double {
            switch self {
            case .running(let sample):
                return sample.vdot
            case .cycling(let sample):
                return sample.outputEstimate
            }
        }
    }

    fileprivate struct PerformanceBreakdown {
        let finalScore: Int
        let percentileRank: Double?
        let referenceValue: Double
        let historicalWorkoutCount: Int
        let usedFallback: Bool
    }

    fileprivate struct DifficultySample {
        let workout: SQWorkoutSessionable
        let durationSeconds: Double
        let zoneSummary: SQHeartRateWorkoutZoneSummary
    }

    fileprivate struct DifficultyBreakdown {
        let finalScore: Int
        let percentileRank: Double?
        let weightedLoad: Double
        let historicalWorkoutCount: Int
        let activityType: HKWorkoutActivityType
        let zoneSummary: SQHeartRateWorkoutZoneSummary
        let usedFallback: Bool
    }

    fileprivate struct SupportedWorkoutScores {
        let workout: SQWorkoutSessionable
        let title: String
        let subtitle: String
        let footer: String
        let scores: [SQWorkoutPremiumInsightScore]
    }

    init(heartRateService: SQHeartRateServicing? = nil) {
        self.heartRateService = heartRateService ?? SQHeartRateService()
    }

    func insights(
        for workout: SQWorkoutSessionable,
        allTimeWorkouts: [SQWorkoutSessionable],
        isPremiumUnlocked: Bool
    ) async -> SQWorkoutPremiumInsightsModel? {
        guard let scoredWorkout = await supportedWorkoutScores(
            for: workout,
            allTimeWorkouts: allTimeWorkouts,
            footerContext: .singleWorkout
        ) else {
            return nil
        }
        let previewState = SQSubscriptionManager.weeklyWorkoutScorePreviewState(
            candidates: [workout],
            isPremiumUnlocked: isPremiumUnlocked
        )
        let shouldUnlockScores = isPremiumUnlocked || previewState.unlockedWorkoutId == workout.id

        return buildInsightsModel(
            from: scoredWorkout,
            isPremiumUnlocked: shouldUnlockScores,
            lockedTitle: "Premium workout insights",
            lockedSubtitle: previewState.lockedSubtitle
        )
    }

    func dashboardInsights(
        for workouts: [SQWorkoutSessionable],
        allTimeWorkouts: [SQWorkoutSessionable],
        isPremiumUnlocked: Bool
    ) async -> SQWorkoutPremiumInsightsModel? {
        let sortedWorkouts = workouts.sorted { ($0.startDate ?? .distantPast) > ($1.startDate ?? .distantPast) }
        let scoredWorkouts = await loadSupportedWorkoutScores(
            from: sortedWorkouts,
            allTimeWorkouts: allTimeWorkouts,
            footerContext: .dashboard
        )
        guard !scoredWorkouts.isEmpty else {
            return nil
        }

        let previewState = SQSubscriptionManager.weeklyWorkoutScorePreviewState(
            candidates: scoredWorkouts.map(\.workout),
            isPremiumUnlocked: isPremiumUnlocked
        )
        let scoredWorkout = scoredWorkouts.first(where: { $0.workout.id == previewState.unlockedWorkoutId })
            ?? scoredWorkouts.first
        guard let scoredWorkout else {
            return nil
        }

        let shouldUnlockScores = isPremiumUnlocked || previewState.unlockedWorkoutId == scoredWorkout.workout.id
        return buildInsightsModel(
            from: scoredWorkout,
            isPremiumUnlocked: shouldUnlockScores,
            lockedTitle: "Premium workout insights",
            lockedSubtitle: previewState.lockedSubtitle
        )
    }

    func dashboardPerformanceRows(
        for workouts: [SQWorkoutSessionable],
        allTimeWorkouts: [SQWorkoutSessionable],
        isPremiumUnlocked: Bool
    ) async -> [SQPerformanceRowData] {
        let workoutsByActivity = workouts.workoutsByActivityType
        var rows = [SQPerformanceRowData]()
        let allPeriodScoredWorkouts = await loadSupportedWorkoutScores(
            from: workouts,
            allTimeWorkouts: allTimeWorkouts,
            footerContext: .dashboard
        )
        let globalPreviewState = SQSubscriptionManager.weeklyWorkoutScorePreviewState(
            candidates: allPeriodScoredWorkouts.map(\.workout),
            isPremiumUnlocked: isPremiumUnlocked
        )

        for (activityType, activityWorkouts) in workoutsByActivity {
            let scoredWorkouts = await loadSupportedWorkoutScores(
                from: activityWorkouts,
                allTimeWorkouts: allTimeWorkouts,
                footerContext: .dashboard
            )
            guard !scoredWorkouts.isEmpty else { continue }

            let allTimeActivityWorkouts = allTimeWorkouts.filter { $0.activityType == activityType }
            let allTimeScoredWorkouts = await loadSupportedWorkoutScores(
                from: allTimeActivityWorkouts,
                allTimeWorkouts: allTimeWorkouts,
                footerContext: .dashboard
            )

            for kind in SQWorkoutScoreKind.allCases {
                let previewScore = scoredWorkouts
                    .first(where: { $0.workout.id == globalPreviewState.unlockedWorkoutId })?
                    .scores
                    .first(where: { $0.kind == kind })
                let currentValues: [Int]
                if !isPremiumUnlocked, let previewScore {
                    currentValues = [previewScore.value]
                } else {
                    currentValues = scoredWorkouts.compactMap { scoredWorkout in
                        scoredWorkout.scores.first(where: { $0.kind == kind })?.value
                    }
                }
                guard !currentValues.isEmpty else { continue }
                let currentAverageValue = Double(currentValues.reduce(0, +)) / Double(currentValues.count)

                let historicalValues = allTimeScoredWorkouts.compactMap { scoredWorkout in
                    scoredWorkout.scores.first(where: { $0.kind == kind })?.value
                }.map(Double.init)
                let percentileRank = SQPercentileCalculator.calculatePercentile(
                    currentBest: currentAverageValue,
                    historicalValues: historicalValues,
                    isLowerBetter: false
                )

                rows.append(
                    SQPerformanceRowData(
                        id: "\(activityType.name.lowercased())-\(kind.rawValue)-score",
                        icon: activityType.imageSymbol.rawValue,
                        title: kind.title,
                        bestValue: String(format: "%.1f", currentAverageValue),
                        unit: "/100",
                        percentileRank: percentileRank,
                        leaderboardMode: .workoutScore(kind, activityType),
                        isPremiumLocked: !(isPremiumUnlocked || previewScore != nil),
                        premiumLockText: globalPreviewState.compactLockText,
                        scoreKind: kind
                    )
                )
            }
        }

        return rows.sorted {
            if $0.title == $1.title {
                return $0.id < $1.id
            }
            return $0.title < $1.title
        }
    }

    func activityScoreItems(
        for workouts: [SQWorkoutSessionable],
        allTimeWorkouts: [SQWorkoutSessionable],
        isPremiumUnlocked: Bool
    ) async -> [HKWorkoutActivityType : [SQDashboardWorkoutGroupViewModel.WorkoutStatItem]] {
        var itemsByActivity = [HKWorkoutActivityType: [SQDashboardWorkoutGroupViewModel.WorkoutStatItem]]()
        let allScoredWorkouts = await loadSupportedWorkoutScores(
            from: workouts,
            allTimeWorkouts: allTimeWorkouts,
            footerContext: .dashboard
        )
        let globalPreviewState = SQSubscriptionManager.weeklyWorkoutScorePreviewState(
            candidates: allScoredWorkouts.map(\.workout),
            isPremiumUnlocked: isPremiumUnlocked
        )

        for (activityType, activityWorkouts) in workouts.workoutsByActivityType {
            let scoredWorkouts = await loadSupportedWorkoutScores(
                from: activityWorkouts,
                allTimeWorkouts: allTimeWorkouts,
                footerContext: .dashboard
            )
            guard !scoredWorkouts.isEmpty else {
                continue
            }
            let previewScores = scoredWorkouts
                .first(where: { $0.workout.id == globalPreviewState.unlockedWorkoutId })?
                .scores ?? []

            itemsByActivity[activityType] = SQWorkoutScoreKind.allCases.compactMap { kind in
                let previewScore = previewScores.first(where: { $0.kind == kind })
                let values: [Int]
                if !isPremiumUnlocked, let previewScore {
                    values = [previewScore.value]
                } else {
                    values = scoredWorkouts.compactMap { scoredWorkout in
                        scoredWorkout.scores.first(where: { $0.kind == kind })?.value
                    }
                }
                guard !values.isEmpty else { return nil }

                let averageValue = Int((Double(values.reduce(0, +)) / Double(values.count)).rounded())
                return SQDashboardWorkoutGroupViewModel.WorkoutStatItem(
                    id: "avg-score-\(kind.rawValue)",
                    title: "Avg \(kind.title)",
                    value: attributedScoreValue(averageValue),
                    isPremiumLocked: !(isPremiumUnlocked || previewScore != nil),
                    premiumLockText: globalPreviewState.compactLockText,
                    accentColor: kind.accentColor
                )
            }
        }

        return itemsByActivity
    }

    func leaderboardRows(
        for kind: SQWorkoutScoreKind,
        activityType: HKWorkoutActivityType,
        workouts: [SQWorkoutSessionable],
        allTimeWorkouts: [SQWorkoutSessionable]
    ) async -> [SQLeaderboardRowViewModel] {
        let filteredWorkouts = workouts.filter { $0.activityType == activityType }
        let scoredWorkouts = await loadSupportedWorkoutScores(
            from: filteredWorkouts,
            allTimeWorkouts: allTimeWorkouts,
            footerContext: .dashboard
        )
        let allTimeFilteredWorkouts = allTimeWorkouts.filter { $0.activityType == activityType }
        let historicalValues = await loadSupportedWorkoutScores(
            from: allTimeFilteredWorkouts,
            allTimeWorkouts: allTimeWorkouts,
            footerContext: .dashboard
        ).compactMap { scoredWorkout in
            scoredWorkout.scores.first(where: { $0.kind == kind })?.value
        }.map(Double.init)

        let sortedScores = scoredWorkouts
            .compactMap { scoredWorkout -> (SQWorkoutSessionable, SQWorkoutPremiumInsightScore)? in
                guard let score = scoredWorkout.scores.first(where: { $0.kind == kind }) else { return nil }
                return (scoredWorkout.workout, score)
            }
            .sorted { $0.1.value > $1.1.value }

        return sortedScores.enumerated().map { index, item in
            SQLeaderboardRowViewModel(
                id: item.0.id,
                rank: index + 1,
                title: item.0.title ?? item.0.visibleTitle,
                date: item.0.startDate ?? .now,
                value: Double(item.1.value),
                formattedScore: "\(item.1.value)",
                unitString: "/100",
                percentileRank: SQPercentileCalculator.calculatePercentile(
                    currentBest: Double(item.1.value),
                    historicalValues: historicalValues,
                    isLowerBetter: false
                ),
                workout: item.0
            )
        }
    }
}

// MARK: - Insight Construction

private extension SQWorkoutScoreService {
    fileprivate enum FooterContext {
        case dashboard
        case singleWorkout
    }

    func buildInsightsModel(
        from scoredWorkout: SupportedWorkoutScores,
        isPremiumUnlocked: Bool,
        lockedTitle: String,
        lockedSubtitle: String
    ) -> SQWorkoutPremiumInsightsModel {
        SQWorkoutPremiumInsightsModel(
            title: scoredWorkout.title,
            subtitle: scoredWorkout.subtitle,
            badgeTitle: "Premium Insight",
            availability: isPremiumUnlocked ? .available : .locked,
            scores: isPremiumUnlocked
                ? scoredWorkout.scores
                : scoredWorkout.scores.map { lockedPreviewScore(for: $0.kind, activityType: scoredWorkout.workout.activityType) },
            footer: isPremiumUnlocked
                ? scoredWorkout.footer
                : "Free members get 1 preview score each week. Unlock personalized workout insights built from your output and training load.",
            lockedTitle: isPremiumUnlocked ? nil : lockedTitle,
            lockedSubtitle: isPremiumUnlocked ? nil : lockedSubtitle
        )
    }

    func supportedWorkoutScores(
        for workout: SQWorkoutSessionable,
        allTimeWorkouts: [SQWorkoutSessionable],
        footerContext: FooterContext
    ) async -> SupportedWorkoutScores? {
        async let historicalPerformanceSamplesTask = makePerformanceSamples(
            from: allTimeWorkouts.filter { $0.activityType == workout.activityType }
        )
        async let historicalDifficultySamplesTask = makeDifficultySamples(
            from: allTimeWorkouts.filter { $0.activityType == workout.activityType }
        )

        let historicalPerformanceSamples = await historicalPerformanceSamplesTask
        let historicalDifficultySamples = await historicalDifficultySamplesTask

        return await supportedWorkoutScores(
            for: workout,
            historicalPerformanceSamples: historicalPerformanceSamples,
            historicalDifficultySamples: historicalDifficultySamples,
            footerContext: footerContext
        )
    }

    func supportedWorkoutScores(
        for workout: SQWorkoutSessionable,
        historicalPerformanceSamples: [PerformanceSample],
        historicalDifficultySamples: [DifficultySample],
        footerContext: FooterContext
    ) async -> SupportedWorkoutScores? {
        async let performanceSampleTask = makePerformanceSample(for: workout)
        async let difficultySampleTask = makeDifficultySample(for: workout)

        let performanceSample = await performanceSampleTask
        let difficultySample = await difficultySampleTask

        var scores = [SQWorkoutPremiumInsightScore]()

        if let performanceSample {
            let performanceBreakdown = performanceBreakdown(
                for: performanceSample,
                historicalSamples: historicalPerformanceSamples
            )
            scores.append(makePerformanceScore(sample: performanceSample, breakdown: performanceBreakdown))
        }

        if let difficultySample {
            let difficultyBreakdown = difficultyBreakdown(
                for: difficultySample,
                historicalSamples: historicalDifficultySamples
            )
            scores.append(makeDifficultyScore(sample: difficultySample, breakdown: difficultyBreakdown))
        }

        guard !scores.isEmpty else {
            return nil
        }

        return SupportedWorkoutScores(
            workout: workout,
            title: insightsTitle(for: scores, footerContext: footerContext),
            subtitle: insightsSubtitle(
                for: workout,
                performanceSample: performanceSample,
                difficultySample: difficultySample,
                footerContext: footerContext
            ),
            footer: insightsFooter(
                for: workout,
                scores: scores,
                difficultySample: difficultySample
            ),
            scores: scores
        )
    }

    func loadSupportedWorkoutScores(
        from workouts: [SQWorkoutSessionable],
        allTimeWorkouts: [SQWorkoutSessionable],
        footerContext: FooterContext
    ) async -> [SupportedWorkoutScores] {
        let uniqueActivityTypes = Set(workouts.map(\.activityType))
        var historicalPerformanceSamplesByActivityType = [HKWorkoutActivityType: [PerformanceSample]]()
        var historicalDifficultySamplesByActivityType = [HKWorkoutActivityType: [DifficultySample]]()

        for activityType in uniqueActivityTypes {
            historicalPerformanceSamplesByActivityType[activityType] = await makePerformanceSamples(
                from: allTimeWorkouts.filter { $0.activityType == activityType }
            )
            historicalDifficultySamplesByActivityType[activityType] = await makeDifficultySamples(
                from: allTimeWorkouts.filter { $0.activityType == activityType }
            )
        }

        var results = [SupportedWorkoutScores]()

        for workout in workouts {
            if let scoredWorkout = await supportedWorkoutScores(
                for: workout,
                historicalPerformanceSamples: historicalPerformanceSamplesByActivityType[workout.activityType] ?? [],
                historicalDifficultySamples: historicalDifficultySamplesByActivityType[workout.activityType] ?? [],
                footerContext: footerContext
            ) {
                results.append(scoredWorkout)
            }
        }
        return results
    }

    func lockedPreviewScore(
        for kind: SQWorkoutScoreKind,
        activityType: HKWorkoutActivityType
    ) -> SQWorkoutPremiumInsightScore {
        switch kind {
        case .performance:
            return .init(
                id: "performance-preview",
                kind: .performance,
                title: "Performance",
                value: 84,
                headline: "Strong effort",
                detail: activityType == .cycling
                    ? "Personalized cycling output score."
                    : "VDOT-inspired pace and distance score.",
                accentColor: .dashboardGlowBlue,
                detailModel: lockedPerformanceDetailModel(for: activityType)
            )
        case .difficulty:
            return .init(
                id: "difficulty-preview",
                kind: .difficulty,
                title: "Difficulty",
                value: 71,
                headline: "Challenging",
                detail: "Training load based on heart-rate zones and time in zone.",
                accentColor: .dashboardTrendWarm,
                detailModel: lockedDifficultyDetailModel()
            )
        }
    }
}

// MARK: - Performance Samples

private extension SQWorkoutScoreService {
    func makePerformanceSamples(from workouts: [SQWorkoutSessionable]) async -> [PerformanceSample] {
        var samples = [PerformanceSample]()
        for workout in workouts {
            if let sample = await makePerformanceSample(for: workout) {
                samples.append(sample)
            }
        }
        return samples
    }

    func makePerformanceSample(for workout: SQWorkoutSessionable) async -> PerformanceSample? {
        if let runningSample = await makeRunningSample(for: workout) {
            return .running(runningSample)
        }

        if let cyclingSample = await makeCyclingSample(for: workout) {
            return .cycling(cyclingSample)
        }

        return nil
    }

    func makeRunningSample(for workout: SQWorkoutSessionable) async -> RunningSample? {
        guard workout.activityType == .running else { return nil }

        guard let distanceMetric = await workout.getMetric(for: .distanceWalkingRunning),
              let paceMetric = await workout.getMetric(for: .sqPaceRunning) else {
            return nil
        }

        let distanceMiles = distanceMetric.value
        let paceSecondsPerMile = paceMetric.value
        let durationSeconds = workout.activeDuration ?? (distanceMiles * paceSecondsPerMile)

        guard distanceMiles >= 1, paceSecondsPerMile > 0, durationSeconds > 0 else {
            return nil
        }

        // Daniels-style VDOT estimate:
        // 1. Convert the run into average velocity.
        // 2. Estimate oxygen cost at that velocity.
        // 3. Estimate the percentage of VO2 max that could be sustained for the
        //    workout duration.
        // 4. Divide cost by sustain percentage to get a fitness/performance proxy.
        let durationMinutes = durationSeconds / 60
        let distanceMeters = distanceMiles * SQDistance.mile.meters
        let velocityMetersPerMinute = distanceMeters / durationMinutes
        let oxygenCost = -4.60 + (0.182258 * velocityMetersPerMinute) + (0.000104 * velocityMetersPerMinute * velocityMetersPerMinute)
        let percentVO2Max = 0.8
            + (0.1894393 * exp(-0.012778 * durationMinutes))
            + (0.2989558 * exp(-0.1932605 * durationMinutes))

        guard percentVO2Max > 0 else { return nil }

        return RunningSample(
            workout: workout,
            distanceMiles: distanceMiles,
            paceSecondsPerMile: paceSecondsPerMile,
            durationSeconds: durationSeconds,
            averageHeartRate: workout.plausibleAverageHeartRate,
            calories: workout.totalCalories,
            vdot: oxygenCost / percentVO2Max
        )
    }

    func makeCyclingSample(for workout: SQWorkoutSessionable) async -> CyclingSample? {
        guard workout.activityType == .cycling else { return nil }
        guard let distanceMetric = await workout.getMetric(for: .distanceCycling) else {
            return nil
        }

        let distanceMiles = distanceMetric.value
        let durationSeconds = workout.activeDuration
            ?? workout.endDate?.timeIntervalSince(workout.startDate ?? .now)
            ?? 0
        guard distanceMiles >= 5, durationSeconds >= 15 * 60 else {
            return nil
        }

        let durationHours = durationSeconds / 3600
        guard durationHours > 0 else { return nil }

        let averageSpeedMilesPerHour = distanceMiles / durationHours
        let distanceFactor = normalized(value: distanceMiles, minValue: 8, maxValue: 40)
        let durationFactor = normalized(value: durationSeconds / 60, minValue: 20, maxValue: 150)
        let sustainFactor = 0.55 + (distanceFactor * 0.20) + (durationFactor * 0.25)

        return CyclingSample(
            workout: workout,
            distanceMiles: distanceMiles,
            durationSeconds: durationSeconds,
            averageHeartRate: workout.plausibleAverageHeartRate,
            calories: workout.totalCalories,
            averageSpeedMilesPerHour: averageSpeedMilesPerHour,
            outputEstimate: averageSpeedMilesPerHour * sustainFactor
        )
    }

    func makeDifficultySamples(from workouts: [SQWorkoutSessionable]) async -> [DifficultySample] {
        var samples = [DifficultySample]()
        for workout in workouts {
            if let sample = await makeDifficultySample(for: workout) {
                samples.append(sample)
            }
        }
        return samples
    }

    func makeDifficultySample(for workout: SQWorkoutSessionable) async -> DifficultySample? {
        let durationSeconds = workout.activeDuration
            ?? workout.endDate?.timeIntervalSince(workout.startDate ?? .now)
            ?? 0
        guard durationSeconds > 0 else {
            return nil
        }

        guard let zoneSummary = await heartRateService.buildWorkoutZoneSummary(for: workout) else {
            return nil
        }

        return DifficultySample(
            workout: workout,
            durationSeconds: durationSeconds,
            zoneSummary: zoneSummary
        )
    }
}

// MARK: - Performance

private extension SQWorkoutScoreService {
    var preferredUnitSystem: SQUnitSystem {
        SQUserDefaults.shared.preferredUnitSystem ?? .defaultForCurrentLocale
    }

    func formattedDistance(_ miles: Double) -> String {
        let unit = preferredUnitSystem == .metric ? SQUnit.kilometer : SQUnit.mile
        let converted = SQUnit.mile.convert(miles, to: unit) ?? miles
        return "\(converted.sqStringRoundedTo(places: 1)) \(unit == .kilometer ? "km" : "mi")"
    }

    func formattedPace(_ secondsPerMile: Double) -> String {
        let unit = preferredUnitSystem == .metric ? SQUnit.secondsPerKilometer : SQUnit.secondsPerMile
        let converted = SQUnit.secondsPerMile.convert(secondsPerMile, to: unit) ?? secondsPerMile
        return "\(converted.timeCode())\(unit == .secondsPerKilometer ? "/km" : "/mi")"
    }

    func formattedSpeed(_ milesPerHour: Double) -> String {
        let unit = preferredUnitSystem == .metric ? SQUnit.kilometer : SQUnit.mile
        let converted = SQUnit.mile.convert(milesPerHour, to: unit) ?? milesPerHour
        return "\(converted.sqStringRoundedTo(places: 1)) \(unit == .kilometer ? "km/h" : "mph")"
    }

    func performanceBreakdown(for sample: PerformanceSample, historicalSamples: [PerformanceSample]) -> PerformanceBreakdown {
        let historicalValues = historicalSamples.map(\.historyValue)
        let percentileRank = SQPercentileCalculator.calculatePercentile(
            currentBest: sample.historyValue,
            historicalValues: historicalValues,
            isLowerBetter: false
        )
        let usedFallback = percentileRank == nil
        let finalScore = Int(clamp(((percentileRank ?? 0.5) * 100).rounded(), min: 1, max: 100))

        return .init(
            finalScore: finalScore,
            percentileRank: percentileRank,
            referenceValue: sample.historyValue,
            historicalWorkoutCount: historicalValues.count,
            usedFallback: usedFallback
        )
    }

    func makePerformanceScore(
        sample: PerformanceSample,
        breakdown: PerformanceBreakdown
    ) -> SQWorkoutPremiumInsightScore {
        SQWorkoutPremiumInsightScore(
            id: "performance",
            kind: .performance,
            title: "Performance",
            value: breakdown.finalScore,
            headline: performanceHeadline(for: breakdown.finalScore),
            detail: performanceDetailText(for: sample),
            accentColor: .dashboardGlowBlue,
            detailModel: performanceDetailModel(for: sample, breakdown: breakdown)
        )
    }

    func performanceHeadline(for score: Int) -> String {
        switch score {
        case 85...: return "Excellent"
        case 70...: return "Strong"
        case 55...: return "Solid"
        case 40...: return "Steady"
        default: return "Easy effort"
        }
    }

    func performanceDetailText(for sample: PerformanceSample) -> String {
        switch sample {
        case .running(let runningSample):
            return "VDOT \(runningSample.vdot.sqStringRoundedTo(places: 1)) • \(formattedPace(runningSample.paceSecondsPerMile)) across \(formattedDistance(runningSample.distanceMiles))"
        case .cycling(let cyclingSample):
            return "\(formattedSpeed(cyclingSample.averageSpeedMilesPerHour)) • \(formattedDistance(cyclingSample.distanceMiles)) ride"
        }
    }
}

// MARK: - Difficulty

private extension SQWorkoutScoreService {
    func difficultyBreakdown(
        for sample: DifficultySample,
        historicalSamples: [DifficultySample]
    ) -> DifficultyBreakdown {
        let historicalLoads = historicalSamples
            .filter { $0.workout.id != sample.workout.id }
            .map { $0.zoneSummary.weightedLoad }
        let percentileRank = SQPercentileCalculator.calculatePercentile(
            currentBest: sample.zoneSummary.weightedLoad,
            historicalValues: historicalLoads,
            isLowerBetter: false
        )
        let usedFallback = percentileRank == nil
        let finalScore: Int

        if let percentileRank {
            finalScore = Int(clamp((percentileRank * 100).rounded(), min: 1, max: 100))
        } else {
            finalScore = fallbackDifficultyScore(for: sample)
        }

        return .init(
            finalScore: finalScore,
            percentileRank: percentileRank,
            weightedLoad: sample.zoneSummary.weightedLoad,
            historicalWorkoutCount: historicalLoads.count,
            activityType: sample.workout.activityType,
            zoneSummary: sample.zoneSummary,
            usedFallback: usedFallback
        )
    }

    func fallbackDifficultyScore(for sample: DifficultySample) -> Int {
        let durationMinutes = sample.durationSeconds / 60
        let intensity = sample.zoneSummary.weightedLoad / max(sample.zoneSummary.recordedDurationSeconds / 60, 1)
        let durationComponent = normalized(value: durationMinutes, minValue: 15, maxValue: 90) * 35
        let intensityComponent = normalized(value: intensity, minValue: 1.5, maxValue: 5.5) * 65
        return Int(clamp((durationComponent + intensityComponent).rounded(), min: 1, max: 100))
    }

    func makeDifficultyScore(
        sample: DifficultySample,
        breakdown: DifficultyBreakdown
    ) -> SQWorkoutPremiumInsightScore {
        SQWorkoutPremiumInsightScore(
            id: "difficulty",
            kind: .difficulty,
            title: "Difficulty",
            value: breakdown.finalScore,
            headline: difficultyHeadline(for: breakdown.finalScore),
            detail: difficultyDetailText(for: sample, breakdown: breakdown),
            accentColor: .dashboardTrendWarm,
            detailModel: difficultyDetailModel(for: sample, breakdown: breakdown)
        )
    }

    func difficultyHeadline(for score: Int) -> String {
        switch score {
        case 85...: return "Very hard"
        case 70...: return "Challenging"
        case 55...: return "Moderate"
        case 35...: return "Steady"
        default: return "Easy"
        }
    }

    func difficultyDetailText(for sample: DifficultySample, breakdown: DifficultyBreakdown) -> String {
        let durationText = sample.durationSeconds.readableTime()
        let averageHeartRateText = "\(sample.zoneSummary.averageHeartRate.sqStringRoundedTo(places: 0)) bpm avg HR"

        guard let percentileRank = breakdown.percentileRank, !breakdown.usedFallback else {
            return "\(durationText) • \(averageHeartRateText)"
        }

        let topPercent = Int(((1 - percentileRank) * 100).rounded())
        return "\(durationText) • top \(topPercent)% \(sample.workout.activityType.name.lowercased()) HR load"
    }
}

// MARK: - Text

private extension SQWorkoutScoreService {
    func performanceDetailModel(
        for sample: PerformanceSample,
        breakdown: PerformanceBreakdown
    ) -> SQWorkoutPremiumInsightDetailModel {
        switch sample {
        case .running(let runningSample):
            let percentileText: String = {
                guard let percentileRank = breakdown.percentileRank else { return "Not enough run history yet." }
                let topPercent = Int(((1 - percentileRank) * 100).rounded())
                return "This run's VDOT ranks in your top \(topPercent)% of \(breakdown.historicalWorkoutCount) logged run(s)."
            }()

            return .init(
                title: "Performance Score",
                subtitle: "How this run ranked against your other runs.",
                summary: "Performance is a personalized score based on VDOT. Faster pace over meaningful distance improves VDOT, and your score reflects where that VDOT ranks in your run history.",
                scoreCards: [],
                components: [
                    .init(
                        id: "overall",
                        title: "Performance score",
                        value: "\(breakdown.finalScore)/100",
                        detail: percentileText,
                        accentColor: .dashboardGlowBlue
                    ),
                    .init(
                        id: "vdot",
                        title: "VDOT estimate",
                        value: breakdown.referenceValue.sqStringRoundedTo(places: 1),
                        detail: "Derived from pace and duration using a Daniels-style running model. This is the main input behind your performance score.",
                        accentColor: .accentNeutral1,
                        definitionLines: vdotGuideDefinitionLines()
                    ),
                    .init(
                        id: "pace",
                        title: "Pace",
                        value: formattedPace(runningSample.paceSecondsPerMile),
                        detail: "Faster sustained pace raises your VDOT and usually lifts the score quickly.",
                        accentColor: .accentNeutral4
                    ),
                    .init(
                        id: "distance",
                        title: "Distance",
                        value: formattedDistance(runningSample.distanceMiles),
                        detail: "Meaningful distance makes the pace effort more representative than a very short burst.",
                        accentColor: .dashboardGlowMint
                    )
                ],
                examples: [],
                footnote: breakdown.usedFallback
                    ? "Performance needs at least two scored runs before it can rank this effort against your own history. Until then, the score stays neutral and the VDOT estimate is shown for context."
                    : "Because performance is relative to your own run history, the same VDOT can score differently as your baseline improves."
            )
        case .cycling(let cyclingSample):
            let percentileText: String = {
                guard let percentileRank = breakdown.percentileRank else { return "Not enough ride history yet." }
                let topPercent = Int(((1 - percentileRank) * 100).rounded())
                return "This ride's output estimate ranks in your top \(topPercent)% of \(breakdown.historicalWorkoutCount) logged ride(s)."
            }()

            return .init(
                title: "Performance Score",
                subtitle: "How this ride ranked against your other rides.",
                summary: "Performance is a personalized cycling score based on sustained speed over meaningful distance and duration. The score reflects where that ride output ranks in your cycling history.",
                scoreCards: [],
                components: [
                    .init(
                        id: "overall",
                        title: "Performance score",
                        value: "\(breakdown.finalScore)/100",
                        detail: percentileText,
                        accentColor: .dashboardGlowBlue
                    ),
                    .init(
                        id: "cycling-output",
                        title: "Cycling output estimate",
                        value: breakdown.referenceValue.sqStringRoundedTo(places: 1),
                        detail: "Built from average speed, distance, and duration so short rides do not outrank stronger sustained rides too easily.",
                        accentColor: .accentNeutral1
                    ),
                    .init(
                        id: "speed",
                        title: "Average speed",
                        value: formattedSpeed(cyclingSample.averageSpeedMilesPerHour),
                        detail: "Higher sustained speed is the main driver of the cycling performance estimate.",
                        accentColor: .accentNeutral4
                    ),
                    .init(
                        id: "distance",
                        title: "Distance",
                        value: formattedDistance(cyclingSample.distanceMiles),
                        detail: "More meaningful ride distance makes the speed signal more representative.",
                        accentColor: .dashboardGlowMint
                    ),
                    .init(
                        id: "duration",
                        title: "Active duration",
                        value: cyclingSample.durationSeconds.readableTime(),
                        detail: "Longer sustained efforts increase the confidence that this was real output rather than a short burst.",
                        accentColor: .dashboardGlowBlue
                    )
                ],
                examples: [],
                footnote: breakdown.usedFallback
                    ? "Performance needs at least two scored rides before it can rank this effort against your own history. Until then, the score stays neutral and the cycling output estimate is shown for context."
                    : "Because performance is relative to your own cycling history, the same ride speed can score differently as your baseline improves."
            )
        }
    }

    func difficultyDetailModel(
        for sample: DifficultySample,
        breakdown: DifficultyBreakdown
    ) -> SQWorkoutPremiumInsightDetailModel {
        let percentileText: String = {
            guard let percentileRank = breakdown.percentileRank else {
                return "Not enough HR-tracked \(breakdown.activityType.name.lowercased()) history yet. Using an absolute zone-load estimate for now."
            }
            let topPercent = Int(((1 - percentileRank) * 100).rounded())
            return "This workout's HR load ranks in your top \(topPercent)% of \(breakdown.historicalWorkoutCount) HR-tracked \(breakdown.activityType.name.lowercased()) workout(s)."
        }()

        var components: [SQWorkoutPremiumInsightDetailModel.Component] = [
            .init(
                id: "overall-difficulty",
                title: "Difficulty score",
                value: "\(breakdown.finalScore)/100",
                detail: percentileText,
                accentColor: .dashboardTrendWarm
            ),
            .init(
                id: "zone-load",
                title: "Weighted HR load",
                value: "\(Int(breakdown.weightedLoad.rounded())) pts",
                detail: "Each minute spent in a higher heart-rate zone is worth more points than a minute at an easy effort.",
                accentColor: .dashboardTrendWarm
            ),
            .init(
                id: "zone-model",
                title: "Zone model",
                value: "Max HR \(breakdown.zoneSummary.profile.estimatedMaxHeartRate)",
                detail: breakdown.zoneSummary.profile.methodDescription,
                accentColor: .dashboardGlowBlue
            )
        ]

        components.append(contentsOf: breakdown.zoneSummary.distributions.map { distribution in
            let minutes = Int((distribution.durationSeconds / 60).rounded())
            return .init(
                id: "zone-\(distribution.zone.rawValue)",
                title: "\(distribution.zone.title) • \(distribution.zone.subtitle)",
                value: "\(minutes)m • \(Int(distribution.contribution.rounded())) pts",
                detail: "Range \(rangeText(for: distribution.range)).",
                accentColor: accentColor(for: distribution.zone)
            )
        })

        return .init(
            title: "Difficulty Score",
            subtitle: "How taxing this workout was, primarily from your heart-rate load.",
            summary: "Difficulty is driven by time in heart-rate zones. Higher zones count much more than easy aerobic time, and the final score ranks that weighted load against your own HR-tracked \(breakdown.activityType.name.lowercased()) history.",
            scoreCards: [],
            components: components,
            examples: [
                .init(
                    id: "difficulty-90",
                    range: "85-100",
                    title: "Peak load",
                    detail: "One of your hardest HR-tracked efforts, usually with sustained time in Zone 4-5 or a very long aerobic load."
                ),
                .init(
                    id: "difficulty-65",
                    range: "65-84",
                    title: "Hard session",
                    detail: "Meaningful training stress with a solid block of Zone 3-4 work."
                ),
                .init(
                    id: "difficulty-40",
                    range: "40-64",
                    title: "Moderate training",
                    detail: "Useful aerobic work, often centered around Zone 2-3."
                ),
                .init(
                    id: "difficulty-1",
                    range: "1-39",
                    title: "Easy / recovery",
                    detail: "Mostly lower-zone work that should be easier to absorb."
                )
            ],
            footnote: "This model is intentionally personal and sport-relative. As your fitness improves, the same heart-rate load can move lower in your \(breakdown.activityType.name.lowercased()) difficulty rankings."
        )
    }

    func lockedPerformanceDetailModel(for activityType: HKWorkoutActivityType) -> SQWorkoutPremiumInsightDetailModel {
        if activityType == .cycling {
            return .init(
                title: "Performance Score",
                subtitle: "How this ride ranked against your other rides.",
                summary: "Performance is a personalized cycling score based on sustained speed over meaningful distance and duration.",
                scoreCards: [],
                components: [
                    .init(
                        id: "overall",
                        title: "Performance score",
                        value: "--/100",
                        detail: "Built from where this ride's output ranks against your ride history.",
                        accentColor: .dashboardGlowBlue
                    ),
                    .init(
                        id: "cycling-output",
                        title: "Cycling output estimate",
                        value: "Included",
                        detail: "The score is centered around a distance-and-duration weighted cycling output estimate.",
                        accentColor: .dashboardGlowBlue
                    ),
                    .init(
                        id: "speed",
                        title: "Average speed",
                        value: "Included",
                        detail: "Higher sustained speed lifts the ride performance estimate.",
                        accentColor: .accentNeutral4
                    ),
                    .init(
                        id: "distance",
                        title: "Distance",
                        value: "Included",
                        detail: "A meaningful ride distance makes the speed signal more representative.",
                        accentColor: .dashboardGlowMint
                    ),
                    .init(
                        id: "duration",
                        title: "Active duration",
                        value: "Included",
                        detail: "Longer sustained efforts carry more performance signal than short bursts.",
                        accentColor: .dashboardGlowBlue
                    )
                ],
                examples: [],
                footnote: "Unlock premium to see your actual personalized cycling performance score and breakdown."
            )
        }

        return .init(
            title: "Performance Score",
            subtitle: "How this run ranked against your other runs.",
            summary: "Performance is a personalized score based on VDOT. Faster pace over meaningful distance improves VDOT, and your score reflects where that VDOT ranks in your run history.",
            scoreCards: [],
            components: [
                .init(
                    id: "overall",
                    title: "Performance score",
                    value: "--/100",
                    detail: "Built from where this run's VDOT ranks against your run history.",
                    accentColor: .dashboardGlowBlue
                ),
                .init(
                    id: "vdot",
                    title: "VDOT estimate",
                    value: "Included",
                    detail: "The score is centered around a Daniels-style VDOT estimate.",
                    accentColor: .dashboardGlowBlue,
                    definitionLines: vdotGuideDefinitionLines()
                ),
                .init(
                    id: "pace",
                    title: "Pace",
                    value: "Included",
                    detail: "Faster sustained pace lifts the performance estimate.",
                    accentColor: .accentNeutral4
                ),
                .init(
                    id: "distance",
                    title: "Distance",
                    value: "Included",
                    detail: "A meaningful distance makes the pace effort more representative.",
                    accentColor: .dashboardGlowMint
                )
            ],
            examples: [],
            footnote: "Unlock premium to see your actual personalized performance score and VDOT breakdown."
        )
    }

    func lockedDifficultyDetailModel() -> SQWorkoutPremiumInsightDetailModel {
        .init(
            title: "Difficulty Score",
            subtitle: "How taxing a workout was for you.",
            summary: "Difficulty is driven by time in heart-rate zones, with harder zones carrying much more load than easy aerobic time. When enough history exists, it is ranked against the same workout type.",
            scoreCards: [],
            components: [
                .init(id: "overall-difficulty", title: "Difficulty score", value: "--/100", detail: "Ranked against your own same-sport HR-tracked workout history.", accentColor: .dashboardTrendWarm),
                .init(id: "zone-load", title: "Weighted HR load", value: "Included", detail: "Time in higher heart-rate zones contributes more load points.", accentColor: .dashboardTrendWarm),
                .init(id: "zone-model", title: "Zone model", value: "Included", detail: "Zones are estimated from your profile age and observed workout HR when available.", accentColor: .dashboardGlowBlue),
                .init(id: "zone-breakdown", title: "Time in each zone", value: "Included", detail: "See exactly how much time you spent in Zone 1 through Zone 5.", accentColor: .dashboardGlowMint)
            ],
            examples: [
                .init(id: "difficulty-90", range: "85-100", title: "Peak load", detail: "One of your hardest HR-tracked efforts."),
                .init(id: "difficulty-65", range: "65-84", title: "Hard session", detail: "Meaningful stress with a solid block of higher-zone work."),
                .init(id: "difficulty-40", range: "40-64", title: "Moderate training", detail: "Useful aerobic work centered around middle zones."),
                .init(id: "difficulty-1", range: "1-39", title: "Easy / recovery", detail: "Mostly lower-zone work.")
            ],
            footnote: "Unlock premium to see your actual difficulty breakdown."
        )
    }

    func vdotGuideDefinitionLines() -> [SQWorkoutPremiumInsightDetailModel.DefinitionLine] {
        [
            .init(id: "vdot-60", valueText: "60+", summaryText: "exceptional endurance range"),
            .init(id: "vdot-50", valueText: "50-59", summaryText: "advanced endurance range"),
            .init(id: "vdot-40", valueText: "40-49", summaryText: "strong recreational endurance range"),
            .init(id: "vdot-30", valueText: "30-39", summaryText: "solid recreational endurance range"),
            .init(id: "vdot-under-30", valueText: "<30", summaryText: "early endurance-building range")
        ]
    }

    func insightsTitle(
        for scores: [SQWorkoutPremiumInsightScore],
        footerContext: FooterContext
    ) -> String {
        switch footerContext {
        case .dashboard:
            return "Latest Workout"
        case .singleWorkout:
            if scores.count == 2 {
                return "Performance & Difficulty"
            }
            return "\(scores.first?.title ?? "Workout") Score"
        }
    }

    func insightsSubtitle(
        for workout: SQWorkoutSessionable,
        performanceSample: PerformanceSample?,
        difficultySample: DifficultySample?,
        footerContext: FooterContext
    ) -> String {
        let dateText = workout.startDate?.formattedString(with: .medium) ?? "Recent workout"

        if let performanceSample {
            switch performanceSample {
            case .running(let runningSample):
                switch footerContext {
                case .dashboard:
                    return "\(workout.activityType.name) • \(formattedDistance(runningSample.distanceMiles)) • \(formattedPace(runningSample.paceSecondsPerMile)) • \(dateText)"
                case .singleWorkout:
                    return "\(formattedDistance(runningSample.distanceMiles)) • \(formattedPace(runningSample.paceSecondsPerMile)) • \(dateText)"
                }
            case .cycling(let cyclingSample):
                switch footerContext {
                case .dashboard:
                    return "\(workout.activityType.name) • \(formattedDistance(cyclingSample.distanceMiles)) • \(formattedSpeed(cyclingSample.averageSpeedMilesPerHour)) • \(dateText)"
                case .singleWorkout:
                    return "\(formattedDistance(cyclingSample.distanceMiles)) • \(formattedSpeed(cyclingSample.averageSpeedMilesPerHour)) • \(dateText)"
                }
            }
        }

        if let difficultySample {
            let durationText = difficultySample.durationSeconds.readableTime()
            let heartRateText = "\(difficultySample.zoneSummary.averageHeartRate.sqStringRoundedTo(places: 0)) bpm avg HR"
            switch footerContext {
            case .dashboard:
                return "\(workout.activityType.name) • \(durationText) • \(heartRateText) • \(dateText)"
            case .singleWorkout:
                return "\(durationText) • \(heartRateText) • \(dateText)"
            }
        }

        return workout.activityType.name
    }

    func insightsFooter(
        for workout: SQWorkoutSessionable,
        scores: [SQWorkoutPremiumInsightScore],
        difficultySample: DifficultySample?
    ) -> String {
        ""
    }

    func accentColor(for zone: SQHeartRateZone) -> SQColor {
        switch zone {
        case .zone1:
            return .accentNeutral4
        case .zone2:
            return .dashboardGlowMint
        case .zone3:
            return .dashboardGlowBlue
        case .zone4:
            return .dashboardTrendWarm
        case .zone5:
            return .accentNeutral1
        }
    }

    func rangeText(for range: SQHeartRateZoneRange) -> String {
        if let upperBound = range.upperBound {
            return "\(range.lowerBound)-\(upperBound - 1) bpm"
        }

        return "\(range.lowerBound)+ bpm"
    }
}

// MARK: - Helpers

private extension SQWorkoutScoreService {
    func attributedScoreValue(_ value: Int) -> AttributedString {
        var result = AttributedString()

        var score = AttributedString("\(value)")
        score.font = SQFont(type: .bodySmallSemiBold).font
        score.foregroundColor = SQColor.textPrimary.color
        result.append(score)

        var unit = AttributedString(" /100")
        unit.font = SQFont(type: .bodyExtraSmall).font
        unit.foregroundColor = SQColor.textSecondary.color
        result.append(unit)

        return result
    }

    func average(of values: [Double]) -> Double? {
        guard !values.isEmpty else { return nil }
        return values.reduce(0, +) / Double(values.count)
    }

    func normalized(value: Double, minValue: Double, maxValue: Double) -> Double {
        guard maxValue > minValue else { return 0 }
        return clamp((value - minValue) / (maxValue - minValue), min: 0, max: 1)
    }

    func clamp(_ value: Double, min minValue: Double, max maxValue: Double) -> Double {
        Swift.max(minValue, Swift.min(maxValue, value))
    }
}

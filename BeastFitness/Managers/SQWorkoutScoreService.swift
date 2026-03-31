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
    /// Normalized running inputs used by both premium scores.
    ///
    /// `Performance` is driven primarily by the derived `vdot`.
    /// `Difficulty` compares the other fields against the runner's own history.
    fileprivate struct RunningSample {
        let workout: SQWorkoutSessionable
        let distanceMiles: Double
        let paceSecondsPerMile: Double
        let durationSeconds: Double
        let averageHeartRate: Double?
        let calories: Double?
        let vdot: Double
    }

    fileprivate struct PerformanceBreakdown {
        let finalScore: Int
        let globalScore: Int
        let personalizedScore: Int
        let vdot: Double
        let personalizedWeight: Int
        let globalWeight: Int
        let historicalRunCount: Int
    }

    fileprivate struct DifficultyBreakdown {
        let finalScore: Int
        let distanceLoad: Double
        let durationLoad: Double
        let paceLoad: Double
        let heartRateLoad: Double?
        let usedFallback: Bool
    }

    fileprivate struct SupportedWorkoutScores {
        let workout: SQWorkoutSessionable
        let title: String
        let subtitle: String
        let footer: String
        let scores: [SQWorkoutPremiumInsightScore]
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

        return buildInsightsModel(
            from: scoredWorkout,
            isPremiumUnlocked: isPremiumUnlocked,
            lockedTitle: "Premium workout insights",
            lockedSubtitle: "Unlock performance and difficulty scores for your workouts."
        )
    }

    func dashboardInsights(
        for workouts: [SQWorkoutSessionable],
        allTimeWorkouts: [SQWorkoutSessionable],
        isPremiumUnlocked: Bool
    ) async -> SQWorkoutPremiumInsightsModel? {
        let sortedWorkouts = workouts.sorted { ($0.startDate ?? .distantPast) > ($1.startDate ?? .distantPast) }

        for workout in sortedWorkouts {
            guard let scoredWorkout = await supportedWorkoutScores(
                for: workout,
                allTimeWorkouts: allTimeWorkouts,
                footerContext: .dashboard
            ) else {
                continue
            }

            return buildInsightsModel(
                from: scoredWorkout,
                isPremiumUnlocked: isPremiumUnlocked,
                lockedTitle: "Premium performance insights",
                lockedSubtitle: "Unlock performance and difficulty scores for your workouts."
            )
        }

        return nil
    }

    func dashboardPerformanceRows(
        for workouts: [SQWorkoutSessionable],
        allTimeWorkouts: [SQWorkoutSessionable],
        isPremiumUnlocked: Bool
    ) async -> [SQPerformanceRowData] {
        let workoutsByActivity = workouts.workoutsByActivityType
        var rows = [SQPerformanceRowData]()

        for (activityType, activityWorkouts) in workoutsByActivity {
            let allTimeActivityWorkouts = allTimeWorkouts.filter { $0.activityType == activityType }
            let scoredWorkouts = await loadSupportedWorkoutScores(
                from: activityWorkouts,
                allTimeWorkouts: allTimeActivityWorkouts,
                footerContext: .dashboard
            )
            guard !scoredWorkouts.isEmpty else { continue }

            let allTimeScoredWorkouts = await loadSupportedWorkoutScores(
                from: allTimeActivityWorkouts,
                allTimeWorkouts: allTimeActivityWorkouts,
                footerContext: .dashboard
            )

            for kind in SQWorkoutScoreKind.allCases {
                let currentValues = scoredWorkouts.compactMap { scoredWorkout in
                    scoredWorkout.scores.first(where: { $0.kind == kind })?.value
                }
                guard let currentValue = currentValues.max() else { continue }

                let historicalValues = allTimeScoredWorkouts.compactMap { scoredWorkout in
                    scoredWorkout.scores.first(where: { $0.kind == kind })?.value
                }.map(Double.init)
                let percentileRank = SQPercentileCalculator.calculatePercentile(
                    currentBest: Double(currentValue),
                    historicalValues: historicalValues,
                    isLowerBetter: false
                )

                rows.append(
                    SQPerformanceRowData(
                        id: "\(activityType.name.lowercased())-\(kind.rawValue)-score",
                        icon: activityType.imageSymbol.rawValue,
                        title: kind.title,
                        bestValue: "\(currentValue)",
                        unit: "/100",
                        percentileRank: percentileRank,
                        leaderboardMode: .workoutScore(kind, activityType),
                        isPremiumLocked: !isPremiumUnlocked,
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

        for (activityType, activityWorkouts) in workouts.workoutsByActivityType {
            guard let latestWorkout = activityWorkouts.sorted(by: {
                ($0.startDate ?? .distantPast) > ($1.startDate ?? .distantPast)
            }).first else {
                continue
            }
            let allTimeActivityWorkouts = allTimeWorkouts.filter { $0.activityType == activityType }
            guard let scoredWorkout = await supportedWorkoutScores(
                for: latestWorkout,
                allTimeWorkouts: allTimeActivityWorkouts,
                footerContext: .dashboard
            ) else {
                continue
            }

            itemsByActivity[activityType] = scoredWorkout.scores.map { score in
                SQDashboardWorkoutGroupViewModel.WorkoutStatItem(
                    id: "score-\(score.kind.rawValue)",
                    title: score.title,
                    value: attributedScoreValue(score.value),
                    isPremiumLocked: !isPremiumUnlocked,
                    accentColor: score.accentColor
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
        let allTimeFilteredWorkouts = allTimeWorkouts.filter { $0.activityType == activityType }
        let scoredWorkouts = await loadSupportedWorkoutScores(
            from: filteredWorkouts,
            allTimeWorkouts: allTimeFilteredWorkouts,
            footerContext: .dashboard
        )
        let historicalValues = await loadSupportedWorkoutScores(
            from: allTimeFilteredWorkouts,
            allTimeWorkouts: allTimeFilteredWorkouts,
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
            scores: isPremiumUnlocked ? scoredWorkout.scores : lockedPreviewScores(),
            footer: isPremiumUnlocked
                ? scoredWorkout.footer
                : "Unlock personalized workout insights built from your output and training load.",
            lockedTitle: isPremiumUnlocked ? nil : lockedTitle,
            lockedSubtitle: isPremiumUnlocked ? nil : lockedSubtitle
        )
    }

    func supportedWorkoutScores(
        for workout: SQWorkoutSessionable,
        allTimeWorkouts: [SQWorkoutSessionable],
        footerContext: FooterContext
    ) async -> SupportedWorkoutScores? {
        switch workout.activityType {
        case .running:
            guard let sample = await makeRunningSample(for: workout) else { return nil }
            let historicalSamples = await makeRunningSamples(
                from: allTimeWorkouts.filter { $0.activityType == .running }
            )
            return buildRunningWorkoutScores(
                sample: sample,
                historicalSamples: historicalSamples,
                footerContext: footerContext
            )
        default:
            return nil
        }
    }

    func loadSupportedWorkoutScores(
        from workouts: [SQWorkoutSessionable],
        allTimeWorkouts: [SQWorkoutSessionable],
        footerContext: FooterContext
    ) async -> [SupportedWorkoutScores] {
        var results = [SupportedWorkoutScores]()
        for workout in workouts {
            if let scoredWorkout = await supportedWorkoutScores(
                for: workout,
                allTimeWorkouts: allTimeWorkouts,
                footerContext: footerContext
            ) {
                results.append(scoredWorkout)
            }
        }
        return results
    }

    func buildRunningWorkoutScores(
        sample: RunningSample,
        historicalSamples: [RunningSample],
        footerContext: FooterContext
    ) -> SupportedWorkoutScores {
        // Both scores are always calculated, even for locked users, so the future
        // premium gate can simply switch between live values and teaser presentation.
        let performanceBreakdown = performanceBreakdown(for: sample, historicalSamples: historicalSamples)
        let difficultyBreakdown = difficultyBreakdown(for: sample, historicalSamples: historicalSamples)

        let performanceScore = makePerformanceScore(sample: sample, breakdown: performanceBreakdown)
        let difficultyScore = makeDifficultyScore(sample: sample, breakdown: difficultyBreakdown)

        let title: String
        switch footerContext {
        case .dashboard:
            title = "Performance Insights"
        case .singleWorkout:
            title = "Performance & Difficulty"
        }

        return SupportedWorkoutScores(
            workout: sample.workout,
            title: title,
            subtitle: dashboardSubtitle(for: sample, footerContext: footerContext),
            footer: footerText(
                performanceValue: performanceBreakdown.finalScore,
                difficultyValue: difficultyBreakdown.finalScore,
                activityType: sample.workout.activityType,
                context: footerContext
            ),
            scores: [performanceScore, difficultyScore]
        )
    }

    func lockedPreviewScores() -> [SQWorkoutPremiumInsightScore] {
        [
            .init(
                id: "performance-preview",
                kind: .performance,
                title: "Performance",
                value: 84,
                headline: "Strong effort",
                detail: "VDOT-inspired pace and distance score.",
                accentColor: .dashboardGlowBlue,
                detailModel: lockedPerformanceDetailModel()
            ),
            .init(
                id: "difficulty-preview",
                kind: .difficulty,
                title: "Difficulty",
                value: 71,
                headline: "Challenging",
                detail: "Training load based on pace, duration, and heart rate.",
                accentColor: .dashboardTrendWarm,
                detailModel: lockedDifficultyDetailModel()
            )
        ]
    }
}

// MARK: - Running Samples

private extension SQWorkoutScoreService {
    func makeRunningSamples(from workouts: [SQWorkoutSessionable]) async -> [RunningSample] {
        var samples = [RunningSample]()
        for workout in workouts {
            if let sample = await makeRunningSample(for: workout) {
                samples.append(sample)
            }
        }
        return samples
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
}

// MARK: - Performance

private extension SQWorkoutScoreService {
    func performanceBreakdown(for sample: RunningSample, historicalSamples: [RunningSample]) -> PerformanceBreakdown {
        let historicalVdots = historicalSamples.map(\.vdot)

        // Absolute component:
        // Maps the workout's VDOT into a broad 28...70 running-fitness band so the
        // score still behaves reasonably for users with limited history.
        let absoluteComponent = normalized(
            value: sample.vdot,
            minValue: 28,
            maxValue: 70
        ) * 100

        // Relative component:
        // Compares this run's VDOT to the user's own running history. This makes the
        // score feel personal instead of only rewarding globally fast runners.
        let percentileComponent = (SQPercentileCalculator.calculatePercentile(
            currentBest: sample.vdot,
            historicalValues: historicalVdots,
            isLowerBetter: false
        ) ?? (absoluteComponent / 100)) * 100

        let personalizedWeight: Int
        let globalWeight: Int
        let blendedScore: Double
        // Once we have enough historical runs, personal percentile matters more than
        // the absolute VDOT band. Before that, lean more heavily on the absolute score
        // so early scores are still stable.
        if historicalVdots.count >= 5 {
            personalizedWeight = 65
            globalWeight = 35
            blendedScore = (percentileComponent * 0.65) + (absoluteComponent * 0.35)
        } else {
            personalizedWeight = 35
            globalWeight = 65
            blendedScore = (percentileComponent * 0.35) + (absoluteComponent * 0.65)
        }

        return .init(
            finalScore: Int(clamp(blendedScore.rounded(), min: 1, max: 100)),
            globalScore: Int(clamp(absoluteComponent.rounded(), min: 1, max: 100)),
            personalizedScore: Int(clamp(percentileComponent.rounded(), min: 1, max: 100)),
            vdot: sample.vdot,
            personalizedWeight: personalizedWeight,
            globalWeight: globalWeight,
            historicalRunCount: historicalVdots.count
        )
    }

    func makePerformanceScore(
        sample: RunningSample,
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

    func performanceDetailText(for sample: RunningSample) -> String {
        "VDOT \(sample.vdot.sqStringRoundedTo(places: 1)) • \(sample.paceSecondsPerMile.timeCode())/mi across \(sample.distanceMiles.sqStringRoundedTo(places: 1)) mi"
    }
}

// MARK: - Difficulty

private extension SQWorkoutScoreService {
    func difficultyBreakdown(for sample: RunningSample, historicalSamples: [RunningSample]) -> DifficultyBreakdown {
        let comparisonSamples = historicalSamples.filter { $0.workout.id != sample.workout.id }
        guard !comparisonSamples.isEmpty else {
            return fallbackDifficultyScore(for: sample)
        }

        // Difficulty is intentionally baseline-relative.
        // A 6-mile run may be easy for one user and very demanding for another, so the
        // score compares the run to the user's own typical distance, duration, pace,
        // and heart rate rather than using only global thresholds.
        let baselineDistance = average(of: comparisonSamples.map(\.distanceMiles)) ?? sample.distanceMiles
        let baselineDuration = average(of: comparisonSamples.map(\.durationSeconds)) ?? sample.durationSeconds
        let baselinePace = average(of: comparisonSamples.map(\.paceSecondsPerMile)) ?? sample.paceSecondsPerMile
        let baselineHeartRate = average(of: comparisonSamples.compactMap(\.averageHeartRate))

        let distanceLoad = clamp(sample.distanceMiles / max(baselineDistance, 1.5), min: 0.55, max: 1.65)
        let durationLoad = clamp(sample.durationSeconds / max(baselineDuration, 20 * 60), min: 0.55, max: 1.65)
        let paceLoad = clamp(baselinePace / max(sample.paceSecondsPerMile, 1), min: 0.55, max: 1.65)

        let heartRateLoad: Double
        if let baselineHeartRate, let averageHeartRate = sample.averageHeartRate {
            heartRateLoad = clamp(averageHeartRate / max(baselineHeartRate, 90), min: 0.7, max: 1.45)
        } else {
            heartRateLoad = 1.0
        }

        let blendedLoad =
            (distanceLoad * 0.30) +
            (durationLoad * 0.25) +
            (paceLoad * 0.30) +
            (heartRateLoad * 0.15)

        // The load blend is then normalized into a 0...100 score. We clamp each
        // component earlier so one outlier input cannot dominate the final result.
        let normalizedScore = normalized(value: blendedLoad, minValue: 0.65, maxValue: 1.45) * 100
        return .init(
            finalScore: Int(clamp(normalizedScore.rounded(), min: 1, max: 100)),
            distanceLoad: distanceLoad,
            durationLoad: durationLoad,
            paceLoad: paceLoad,
            heartRateLoad: sample.averageHeartRate == nil ? nil : heartRateLoad,
            usedFallback: false
        )
    }

    func fallbackDifficultyScore(for sample: RunningSample) -> DifficultyBreakdown {
        // Fallback for runners with little or no history. This uses absolute heuristics
        // so the score is still usable before we have a personal baseline.
        let distanceComponent = normalized(value: sample.distanceMiles, minValue: 1, maxValue: 10) * 35
        let durationComponent = normalized(value: sample.durationSeconds, minValue: 15 * 60, maxValue: 90 * 60) * 25
        let paceComponent = normalized(value: 11 * 60 - sample.paceSecondsPerMile, minValue: 0, maxValue: 5 * 60) * 25
        let heartRateComponent = normalized(value: sample.averageHeartRate ?? 130, minValue: 120, maxValue: 180) * 15
        let score = distanceComponent + durationComponent + paceComponent + heartRateComponent
        return .init(
            finalScore: Int(clamp(score.rounded(), min: 1, max: 100)),
            distanceLoad: normalized(value: sample.distanceMiles, minValue: 1, maxValue: 10),
            durationLoad: normalized(value: sample.durationSeconds, minValue: 15 * 60, maxValue: 90 * 60),
            paceLoad: normalized(value: 11 * 60 - sample.paceSecondsPerMile, minValue: 0, maxValue: 5 * 60),
            heartRateLoad: sample.averageHeartRate == nil ? nil : normalized(value: sample.averageHeartRate ?? 130, minValue: 120, maxValue: 180),
            usedFallback: true
        )
    }

    func makeDifficultyScore(
        sample: RunningSample,
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

    func difficultyDetailText(for sample: RunningSample, breakdown: DifficultyBreakdown) -> String {
        let durationText = sample.durationSeconds.readableTime()
        let heartRateText = sample.averageHeartRate.map { "\($0.sqStringRoundedTo(places: 0)) bpm avg HR" } ?? "\(sample.distanceMiles.sqStringRoundedTo(places: 1)) mi run"
        guard !breakdown.usedFallback else {
            return "\(durationText) • \(heartRateText)"
        }

        let paceDelta = (breakdown.paceLoad - 1) * 100
        let paceDirection = paceDelta >= 0 ? "harder than your usual pace" : "easier than your usual pace"
        return "\(durationText) • \(abs(paceDelta).adaptivePercentString) \(paceDirection)"
    }
}

// MARK: - Text

private extension SQWorkoutScoreService {
    func performanceDetailModel(
        for sample: RunningSample,
        breakdown: PerformanceBreakdown
    ) -> SQWorkoutPremiumInsightDetailModel {
        .init(
            title: "Performance Score",
            subtitle: "How strong this run was for pace and distance output.",
            summary: "Performance blends a stable global score with a personalized score based on your own run history.",
            scoreCards: [
                .init(
                    id: "global-performance",
                    title: "Global",
                    value: "\(breakdown.globalScore)/100",
                    caption: "Stable VDOT-style output score. This does not drift as you log more runs.",
                    accentColor: .dashboardGlowBlue
                ),
                .init(
                    id: "personalized-performance",
                    title: "Personalized",
                    value: "\(breakdown.personalizedScore)/100",
                    caption: "Current ranking against \(max(breakdown.historicalRunCount, 1)) run(s) in your history. This can shift as your baseline evolves.",
                    accentColor: .dashboardGlowMint
                )
            ],
            components: [
                .init(
                    id: "overall",
                    title: "Displayed score",
                    value: "\(breakdown.finalScore)/100",
                    detail: "\(breakdown.personalizedWeight)% personalized + \(breakdown.globalWeight)% global.",
                    accentColor: .dashboardGlowBlue
                ),
                .init(
                    id: "vdot",
                    title: "VDOT estimate",
                    value: breakdown.vdot.sqStringRoundedTo(places: 1),
                    detail: "Derived from pace and duration using a Daniels-style running model.",
                    accentColor: .accentNeutral1
                ),
                .init(
                    id: "pace",
                    title: "Pace",
                    value: "\(sample.paceSecondsPerMile.timeCode())/mi",
                    detail: "Faster sustained pace improves both VDOT and the global score.",
                    accentColor: .accentNeutral4
                ),
                .init(
                    id: "distance",
                    title: "Distance",
                    value: "\(sample.distanceMiles.sqStringRoundedTo(places: 1)) mi",
                    detail: "Meaningful distance gives the pace effort more weight than a very short burst.",
                    accentColor: .dashboardGlowMint
                )
            ],
            examples: [
                .init(
                    id: "performance-95",
                    range: "90-100",
                    title: "Elite output",
                    detail: "Usually race-level or highly trained running output for that effort duration."
                ),
                .init(
                    id: "performance-70",
                    range: "65-80",
                    title: "Strong recreational run",
                    detail: "A well-trained runner putting together a meaningfully strong session."
                ),
                .init(
                    id: "performance-45",
                    range: "40-55",
                    title: "Developing base",
                    detail: "A steady developing fitness level with room to build pace and endurance."
                )
            ],
            footnote: "Global performance stays stable for old runs. Personalized performance is relative to your current run history, so it can move over time."
        )
    }

    func difficultyDetailModel(
        for sample: RunningSample,
        breakdown: DifficultyBreakdown
    ) -> SQWorkoutPremiumInsightDetailModel {
        var components: [SQWorkoutPremiumInsightDetailModel.Component] = [
            .init(
                id: "distance-load",
                title: "Distance load",
                value: loadString(for: breakdown.distanceLoad, isFallback: breakdown.usedFallback),
                detail: "Longer-than-usual runs increase difficulty quickly.",
                accentColor: .dashboardTrendWarm
            ),
            .init(
                id: "duration-load",
                title: "Duration load",
                value: loadString(for: breakdown.durationLoad, isFallback: breakdown.usedFallback),
                detail: "More total time on feet adds fatigue even at easier paces.",
                accentColor: .accentNeutral4
            ),
            .init(
                id: "pace-load",
                title: "Pace load",
                value: loadString(for: breakdown.paceLoad, isFallback: breakdown.usedFallback),
                detail: "Faster-than-usual pace raises difficulty even if distance is modest.",
                accentColor: .dashboardGlowBlue
            )
        ]

        if let heartRateLoad = breakdown.heartRateLoad {
            components.append(
                .init(
                    id: "heart-load",
                    title: "Heart rate load",
                    value: loadString(for: heartRateLoad, isFallback: breakdown.usedFallback),
                    detail: "Higher average heart rate generally means the session was more demanding.",
                    accentColor: .dashboardGlowMint
                )
            )
        }

        return .init(
            title: "Difficulty Score",
            subtitle: "How taxing this run was for you, not just how fast it looked.",
            summary: "Difficulty compares this run to your own baseline for distance, duration, pace, and heart rate.",
            scoreCards: [
                .init(
                    id: "difficulty-overall",
                    title: "Overall difficulty",
                    value: "\(breakdown.finalScore)/100",
                    caption: breakdown.usedFallback
                        ? "Using fallback heuristics until more run history is available."
                        : "Measured relative to your personal running baseline.",
                    accentColor: .dashboardTrendWarm
                )
            ],
            components: components,
            examples: [
                .init(
                    id: "difficulty-95",
                    range: "90-100",
                    title: "Near your peak",
                    detail: "Race-like or extremely demanding. Use extra recovery if this becomes frequent."
                ),
                .init(
                    id: "difficulty-70",
                    range: "65-80",
                    title: "Hard session",
                    detail: "A meaningful quality workout, tempo effort, or long challenging run."
                ),
                .init(
                    id: "difficulty-40",
                    range: "35-50",
                    title: "Easy aerobic work",
                    detail: "Manageable load that should feel sustainable and recovery-friendly."
                )
            ],
            footnote: "Difficulty is intentionally personal. As your fitness improves, the same run can score as less difficult."
        )
    }

    func lockedPerformanceDetailModel() -> SQWorkoutPremiumInsightDetailModel {
        .init(
            title: "Performance Score",
            subtitle: "How strong a run was for pace and distance output.",
            summary: "Performance combines a stable global score with a personalized score based on your own running history.",
            scoreCards: [
                .init(
                    id: "global-performance",
                    title: "Global",
                    value: "--/100",
                    caption: "Stable VDOT-style score you can compare across runs.",
                    accentColor: .dashboardGlowBlue
                ),
                .init(
                    id: "personalized-performance",
                    title: "Personalized",
                    value: "--/100",
                    caption: "Relative to your own running history and baseline.",
                    accentColor: .dashboardGlowMint
                )
            ],
            components: [
                .init(
                    id: "pace",
                    title: "Pace",
                    value: "Included",
                    detail: "Faster sustained pace lifts the performance estimate.",
                    accentColor: .dashboardGlowBlue
                ),
                .init(
                    id: "distance",
                    title: "Distance",
                    value: "Included",
                    detail: "A stronger pace over a meaningful distance scores better than a short burst.",
                    accentColor: .dashboardGlowMint
                )
            ],
            examples: [
                .init(id: "performance-95", range: "90-100", title: "Elite output", detail: "Highly trained or race-level running output."),
                .init(id: "performance-70", range: "65-80", title: "Strong recreational run", detail: "A confident, well-trained session."),
                .init(id: "performance-45", range: "40-55", title: "Developing base", detail: "Steady fitness with room to build.")
            ],
            footnote: "Unlock premium to see your actual global and personalized performance breakdown."
        )
    }

    func lockedDifficultyDetailModel() -> SQWorkoutPremiumInsightDetailModel {
        .init(
            title: "Difficulty Score",
            subtitle: "How taxing a run was for you.",
            summary: "Difficulty compares your run to your personal baseline for distance, duration, pace, and heart rate.",
            scoreCards: [
                .init(
                    id: "difficulty-overall",
                    title: "Overall difficulty",
                    value: "--/100",
                    caption: "Personalized to your own training history.",
                    accentColor: .dashboardTrendWarm
                )
            ],
            components: [
                .init(id: "distance-load", title: "Distance load", value: "Included", detail: "Longer-than-usual runs score harder.", accentColor: .dashboardTrendWarm),
                .init(id: "duration-load", title: "Duration load", value: "Included", detail: "More total time raises fatigue.", accentColor: .accentNeutral4),
                .init(id: "pace-load", title: "Pace load", value: "Included", detail: "Faster efforts increase strain.", accentColor: .dashboardGlowBlue)
            ],
            examples: [
                .init(id: "difficulty-95", range: "90-100", title: "Near your peak", detail: "Race-like or extremely demanding."),
                .init(id: "difficulty-70", range: "65-80", title: "Hard session", detail: "A challenging quality workout."),
                .init(id: "difficulty-40", range: "35-50", title: "Easy aerobic work", detail: "Manageable and recovery-friendly.")
            ],
            footnote: "Unlock premium to see your actual difficulty breakdown."
        )
    }

    func dashboardSubtitle(for sample: RunningSample, footerContext: FooterContext) -> String {
        let dateText = sample.workout.startDate?.formattedString(with: .medium) ?? "Recent run"
        switch footerContext {
        case .dashboard:
            return "Running • \(sample.distanceMiles.sqStringRoundedTo(places: 1)) mi • \(sample.paceSecondsPerMile.timeCode())/mi • \(dateText)"
        case .singleWorkout:
            return "\(sample.distanceMiles.sqStringRoundedTo(places: 1)) mi • \(sample.paceSecondsPerMile.timeCode())/mi • \(dateText)"
        }
    }

    func footerText(
        performanceValue: Int,
        difficultyValue: Int,
        activityType: HKWorkoutActivityType,
        context: FooterContext
    ) -> String {
        let performanceSummary: String
        switch performanceValue {
        case 80...:
            performanceSummary = "well above your recent running baseline"
        case 60...:
            performanceSummary = "solid relative to your recent running baseline"
        default:
            performanceSummary = "closer to an easy or maintenance effort"
        }

        let difficultySummary: String
        switch difficultyValue {
        case 80...:
            difficultySummary = "a high-load session"
        case 60...:
            difficultySummary = "a meaningfully challenging session"
        default:
            difficultySummary = "a manageable training load"
        }

        let activityName = activityType.name.lowercased()
        switch context {
        case .dashboard:
            return "Latest \(activityName) insight: performance looked \(performanceSummary), while difficulty landed as \(difficultySummary)."
        case .singleWorkout:
            return "This \(activityName) workout graded \(performanceSummary) for output, and registered as \(difficultySummary)."
        }
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

    func loadString(for value: Double, isFallback: Bool) -> String {
        if isFallback {
            return "\(Int((value * 100).rounded()))%"
        }

        let deltaFromBaseline = (value - 1) * 100
        let prefix = deltaFromBaseline >= 0 ? "+" : ""
        return "\(prefix)\(Int(deltaFromBaseline.rounded()))%"
    }
}

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
    private let heartRateService: SQHeartRateServicing

    /// Normalized running inputs used by both premium scores.
    ///
    /// `Performance` is driven primarily by the derived `vdot`.
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
        let percentileRank: Double?
        let vdot: Double
        let historicalRunCount: Int
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
                lockedTitle: "Premium workout insights",
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
            guard let scoredWorkout = await supportedWorkoutScores(
                for: latestWorkout,
                allTimeWorkouts: allTimeWorkouts,
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
                : scoredWorkout.scores.map { lockedPreviewScore(for: $0.kind) },
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
        async let historicalRunSamplesTask = makeRunningSamples(
            from: allTimeWorkouts.filter { $0.activityType == .running }
        )
        async let historicalDifficultySamplesTask = makeDifficultySamples(from: allTimeWorkouts)

        let historicalRunSamples = await historicalRunSamplesTask
        let historicalDifficultySamples = await historicalDifficultySamplesTask

        return await supportedWorkoutScores(
            for: workout,
            historicalRunSamples: historicalRunSamples,
            historicalDifficultySamples: historicalDifficultySamples,
            footerContext: footerContext
        )
    }

    func supportedWorkoutScores(
        for workout: SQWorkoutSessionable,
        historicalRunSamples: [RunningSample],
        historicalDifficultySamples: [DifficultySample],
        footerContext: FooterContext
    ) async -> SupportedWorkoutScores? {
        async let runningSampleTask = makeRunningSample(for: workout)
        async let difficultySampleTask = makeDifficultySample(for: workout)

        let runningSample = await runningSampleTask
        let difficultySample = await difficultySampleTask

        var scores = [SQWorkoutPremiumInsightScore]()

        if let runningSample {
            let performanceBreakdown = performanceBreakdown(
                for: runningSample,
                historicalSamples: historicalRunSamples
            )
            scores.append(makePerformanceScore(sample: runningSample, breakdown: performanceBreakdown))
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
                runningSample: runningSample,
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
        async let historicalRunSamplesTask = makeRunningSamples(
            from: allTimeWorkouts.filter { $0.activityType == .running }
        )
        async let historicalDifficultySamplesTask = makeDifficultySamples(from: allTimeWorkouts)

        let historicalRunSamples = await historicalRunSamplesTask
        let historicalDifficultySamples = await historicalDifficultySamplesTask
        var results = [SupportedWorkoutScores]()

        for workout in workouts {
            if let scoredWorkout = await supportedWorkoutScores(
                for: workout,
                historicalRunSamples: historicalRunSamples,
                historicalDifficultySamples: historicalDifficultySamples,
                footerContext: footerContext
            ) {
                results.append(scoredWorkout)
            }
        }
        return results
    }

    func lockedPreviewScore(for kind: SQWorkoutScoreKind) -> SQWorkoutPremiumInsightScore {
        switch kind {
        case .performance:
            return .init(
                id: "performance-preview",
                kind: .performance,
                title: "Performance",
                value: 84,
                headline: "Strong effort",
                detail: "VDOT-inspired pace and distance score.",
                accentColor: .dashboardGlowBlue,
                detailModel: lockedPerformanceDetailModel()
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
    func performanceBreakdown(for sample: RunningSample, historicalSamples: [RunningSample]) -> PerformanceBreakdown {
        let historicalVdots = historicalSamples.map(\.vdot)
        let percentileRank = SQPercentileCalculator.calculatePercentile(
            currentBest: sample.vdot,
            historicalValues: historicalVdots,
            isLowerBetter: false
        )
        let usedFallback = percentileRank == nil
        let finalScore = Int(clamp(((percentileRank ?? 0.5) * 100).rounded(), min: 1, max: 100))

        return .init(
            finalScore: finalScore,
            percentileRank: percentileRank,
            vdot: sample.vdot,
            historicalRunCount: historicalVdots.count,
            usedFallback: usedFallback
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
        return "\(durationText) • top \(topPercent)% HR load"
    }
}

// MARK: - Text

private extension SQWorkoutScoreService {
    func performanceDetailModel(
        for sample: RunningSample,
        breakdown: PerformanceBreakdown
    ) -> SQWorkoutPremiumInsightDetailModel {
        let percentileText: String = {
            guard let percentileRank = breakdown.percentileRank else { return "Not enough run history yet." }
            let topPercent = Int(((1 - percentileRank) * 100).rounded())
            return "This run's VDOT ranks in your top \(topPercent)% of \(breakdown.historicalRunCount) logged run(s)."
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
                    value: breakdown.vdot.sqStringRoundedTo(places: 1),
                    detail: "Derived from pace and duration using a Daniels-style running model. This is the main input behind your performance score.",
                    accentColor: .accentNeutral1
                ),
                .init(
                    id: "pace",
                    title: "Pace",
                    value: "\(sample.paceSecondsPerMile.timeCode())/mi",
                    detail: "Faster sustained pace raises your VDOT and usually lifts the score quickly.",
                    accentColor: .accentNeutral4
                ),
                .init(
                    id: "distance",
                    title: "Distance",
                    value: "\(sample.distanceMiles.sqStringRoundedTo(places: 1)) mi",
                    detail: "Meaningful distance makes the pace effort more representative than a very short burst.",
                    accentColor: .dashboardGlowMint
                ),
                .init(
                    id: "vdot-guide",
                    title: "VDOT ranges",
                    value: "Guide",
                    detail: "60+: elite-level endurance output. 50-59: advanced recreational range. 40-49: strong healthy recreational range. 30-39: developing aerobic base. Under 30: early-stage endurance fitness.",
                    accentColor: .dashboardGlowBlue
                )
            ],
            examples: [],
            footnote: breakdown.usedFallback
                ? "Performance needs at least two scored runs before it can rank this effort against your own history. Until then, the score stays neutral and the VDOT estimate is shown for context."
                : "Because performance is relative to your own run history, the same VDOT can score differently as your baseline improves."
        )
    }

    func difficultyDetailModel(
        for sample: DifficultySample,
        breakdown: DifficultyBreakdown
    ) -> SQWorkoutPremiumInsightDetailModel {
        let percentileText: String = {
            guard let percentileRank = breakdown.percentileRank else {
                return "Not enough HR-tracked workout history yet. Using an absolute zone-load estimate for now."
            }
            let topPercent = Int(((1 - percentileRank) * 100).rounded())
            return "This workout's HR load ranks in your top \(topPercent)% of \(breakdown.historicalWorkoutCount) HR-tracked workout(s)."
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
            summary: "Difficulty is driven by time in heart-rate zones. Higher zones count much more than easy aerobic time, and the final score ranks that weighted load against your other HR-tracked workouts.",
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
            footnote: "This model is intentionally personal. As your fitness improves, the same heart-rate load can move lower in your historical difficulty rankings."
        )
    }

    func lockedPerformanceDetailModel() -> SQWorkoutPremiumInsightDetailModel {
        .init(
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
                    accentColor: .dashboardGlowBlue
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
                ),
                .init(
                    id: "vdot-guide",
                    title: "VDOT ranges",
                    value: "Guide",
                    detail: "60+: elite-level endurance output. 50-59: advanced recreational range. 40-49: strong healthy recreational range. 30-39: developing aerobic base. Under 30: early-stage endurance fitness.",
                    accentColor: .dashboardGlowBlue
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
            summary: "Difficulty is driven by time in heart-rate zones, with harder zones carrying much more load than easy aerobic time.",
            scoreCards: [],
            components: [
                .init(id: "overall-difficulty", title: "Difficulty score", value: "--/100", detail: "Ranked against your own HR-tracked workout history.", accentColor: .dashboardTrendWarm),
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

    func insightsTitle(
        for scores: [SQWorkoutPremiumInsightScore],
        footerContext: FooterContext
    ) -> String {
        switch footerContext {
        case .dashboard:
            return "Workout Insights"
        case .singleWorkout:
            if scores.count == 2 {
                return "Performance & Difficulty"
            }
            return "\(scores.first?.title ?? "Workout") Score"
        }
    }

    func insightsSubtitle(
        for workout: SQWorkoutSessionable,
        runningSample: RunningSample?,
        difficultySample: DifficultySample?,
        footerContext: FooterContext
    ) -> String {
        let dateText = workout.startDate?.formattedString(with: .medium) ?? "Recent workout"

        if let runningSample {
            switch footerContext {
            case .dashboard:
                return "\(workout.activityType.name) • \(runningSample.distanceMiles.sqStringRoundedTo(places: 1)) mi • \(runningSample.paceSecondsPerMile.timeCode())/mi • \(dateText)"
            case .singleWorkout:
                return "\(runningSample.distanceMiles.sqStringRoundedTo(places: 1)) mi • \(runningSample.paceSecondsPerMile.timeCode())/mi • \(dateText)"
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
        let activityName = workout.activityType.name.lowercased()
        let hasPerformance = scores.contains { $0.kind == .performance }
        let difficultySummary: String? = scores.first(where: { $0.kind == .difficulty }).map { difficultyScore in
            switch difficultyScore.value {
            case 85...:
                return "one of your highest recent HR loads"
            case 65...:
                return "a meaningfully hard session"
            case 40...:
                return "a moderate training load"
            default:
                return "an easier or recovery-friendly load"
            }
        }

        if hasPerformance, let performanceScore = scores.first(where: { $0.kind == .performance }), let difficultySummary {
            let performanceSummary: String
            switch performanceScore.value {
            case 80...:
                performanceSummary = "well above your recent running baseline"
            case 60...:
                performanceSummary = "solid relative to your recent running baseline"
            default:
                performanceSummary = "closer to an easy or maintenance effort"
            }
            return "This \(activityName) workout graded \(performanceSummary) for output and registered as \(difficultySummary)."
        }

        if let difficultySummary, let difficultySample {
            let peakHeartRate = Int(difficultySample.zoneSummary.maximumObservedHeartRate.rounded())
            return "This \(activityName) workout registered as \(difficultySummary), driven by time spent across your heart-rate zones. Peak observed HR was \(peakHeartRate) bpm."
        }

        return "This workout insight is based on your available workout output and training load."
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

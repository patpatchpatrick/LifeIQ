//
//  SQWorkoutScoreService.swift
//  BeastFitness
//

import Foundation
import HealthKit
import BeastFitnessCore

enum SQWorkoutPremiumInsightAvailability: Equatable {
    case available
    case locked
}

struct SQWorkoutPremiumInsightScore: Identifiable {
    let id: String
    let title: String
    let value: Int
    let headline: String
    let detail: String
    let accentColor: SQColor
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
}

@MainActor
final class SQWorkoutScoreService: SQWorkoutScoreServicing {
    fileprivate struct RunningSample {
        let workout: SQWorkoutSessionable
        let distanceMiles: Double
        let paceSecondsPerMile: Double
        let durationSeconds: Double
        let averageHeartRate: Double?
        let calories: Double?
        let vdot: Double
    }

    func insights(
        for workout: SQWorkoutSessionable,
        allTimeWorkouts: [SQWorkoutSessionable],
        isPremiumUnlocked: Bool
    ) async -> SQWorkoutPremiumInsightsModel? {
        guard workout.activityType == .running else { return nil }
        guard let sample = await makeRunningSample(for: workout) else { return nil }

        let historicalSamples = await makeRunningSamples(
            from: allTimeWorkouts.filter { $0.activityType == .running }
        )

        return buildInsightsModel(
            sample: sample,
            historicalSamples: historicalSamples,
            isPremiumUnlocked: isPremiumUnlocked,
            title: "Performance & Difficulty",
            subtitle: workoutSubtitle(for: sample),
            footerContext: .singleWorkout
        )
    }

    func dashboardInsights(
        for workouts: [SQWorkoutSessionable],
        allTimeWorkouts: [SQWorkoutSessionable],
        isPremiumUnlocked: Bool
    ) async -> SQWorkoutPremiumInsightsModel? {
        let runningWorkouts = workouts
            .filter { $0.activityType == .running }
            .sorted { ($0.startDate ?? .distantPast) > ($1.startDate ?? .distantPast) }

        guard let latestRun = runningWorkouts.first,
              let sample = await makeRunningSample(for: latestRun) else {
            return nil
        }

        let historicalSamples = await makeRunningSamples(
            from: allTimeWorkouts.filter { $0.activityType == .running }
        )

        return buildInsightsModel(
            sample: sample,
            historicalSamples: historicalSamples,
            isPremiumUnlocked: isPremiumUnlocked,
            title: "Latest Run",
            subtitle: workoutSubtitle(for: sample),
            footerContext: .dashboard
        )
    }
}

// MARK: - Insight Construction

private extension SQWorkoutScoreService {
    fileprivate enum FooterContext {
        case dashboard
        case singleWorkout
    }

    func buildInsightsModel(
        sample: RunningSample,
        historicalSamples: [RunningSample],
        isPremiumUnlocked: Bool,
        title: String,
        subtitle: String,
        footerContext: FooterContext
    ) -> SQWorkoutPremiumInsightsModel {
        let performanceValue = performanceScore(for: sample, historicalSamples: historicalSamples)
        let difficultyValue = difficultyScore(for: sample, historicalSamples: historicalSamples)

        let performanceScore = SQWorkoutPremiumInsightScore(
            id: "performance",
            title: "Performance",
            value: performanceValue,
            headline: performanceHeadline(for: performanceValue),
            detail: performanceDetailText(for: sample),
            accentColor: .dashboardGlowBlue
        )

        let difficultyScore = SQWorkoutPremiumInsightScore(
            id: "difficulty",
            title: "Difficulty",
            value: difficultyValue,
            headline: difficultyHeadline(for: difficultyValue),
            detail: difficultyDetailText(for: sample, historicalSamples: historicalSamples),
            accentColor: .dashboardTrendWarm
        )

        let availability: SQWorkoutPremiumInsightAvailability = isPremiumUnlocked ? .available : .locked

        return SQWorkoutPremiumInsightsModel(
            title: title,
            subtitle: subtitle,
            badgeTitle: "Premium Insight",
            availability: availability,
            scores: isPremiumUnlocked ? [performanceScore, difficultyScore] : lockedPreviewScores(),
            footer: isPremiumUnlocked
                ? footerText(
                    performanceValue: performanceValue,
                    difficultyValue: difficultyValue,
                    context: footerContext
                )
                : "Unlock personalized running insights built from your pace, distance, and training load.",
            lockedTitle: isPremiumUnlocked ? nil : "Premium running insights",
            lockedSubtitle: isPremiumUnlocked ? nil : "Unlock performance and difficulty scores for your runs."
        )
    }

    func lockedPreviewScores() -> [SQWorkoutPremiumInsightScore] {
        [
            .init(
                id: "performance-preview",
                title: "Performance",
                value: 84,
                headline: "Strong effort",
                detail: "VDOT-inspired pace and distance score.",
                accentColor: .dashboardGlowBlue
            ),
            .init(
                id: "difficulty-preview",
                title: "Difficulty",
                value: 71,
                headline: "Challenging",
                detail: "Training load based on pace, duration, and heart rate.",
                accentColor: .dashboardTrendWarm
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
    func performanceScore(for sample: RunningSample, historicalSamples: [RunningSample]) -> Int {
        let historicalVdots = historicalSamples.map(\.vdot)
        let absoluteComponent = normalized(
            value: sample.vdot,
            minValue: 28,
            maxValue: 70
        ) * 100

        let percentileComponent = (SQPercentileCalculator.calculatePercentile(
            currentBest: sample.vdot,
            historicalValues: historicalVdots,
            isLowerBetter: false
        ) ?? (absoluteComponent / 100)) * 100

        let blendedScore: Double
        if historicalVdots.count >= 5 {
            blendedScore = (percentileComponent * 0.65) + (absoluteComponent * 0.35)
        } else {
            blendedScore = (percentileComponent * 0.35) + (absoluteComponent * 0.65)
        }

        return Int(clamp(blendedScore.rounded(), min: 1, max: 100))
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
    func difficultyScore(for sample: RunningSample, historicalSamples: [RunningSample]) -> Int {
        let comparisonSamples = historicalSamples.filter { $0.workout.id != sample.workout.id }
        guard !comparisonSamples.isEmpty else {
            return fallbackDifficultyScore(for: sample)
        }

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

        let normalizedScore = normalized(value: blendedLoad, minValue: 0.65, maxValue: 1.45) * 100
        return Int(clamp(normalizedScore.rounded(), min: 1, max: 100))
    }

    func fallbackDifficultyScore(for sample: RunningSample) -> Int {
        let distanceComponent = normalized(value: sample.distanceMiles, minValue: 1, maxValue: 10) * 35
        let durationComponent = normalized(value: sample.durationSeconds, minValue: 15 * 60, maxValue: 90 * 60) * 25
        let paceComponent = normalized(value: 11 * 60 - sample.paceSecondsPerMile, minValue: 0, maxValue: 5 * 60) * 25
        let heartRateComponent = normalized(value: sample.averageHeartRate ?? 130, minValue: 120, maxValue: 180) * 15
        let score = distanceComponent + durationComponent + paceComponent + heartRateComponent
        return Int(clamp(score.rounded(), min: 1, max: 100))
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

    func difficultyDetailText(for sample: RunningSample, historicalSamples: [RunningSample]) -> String {
        let durationText = sample.durationSeconds.readableTime()
        let heartRateText = sample.averageHeartRate.map { "\($0.sqStringRoundedTo(places: 0)) bpm avg HR" } ?? "\(sample.distanceMiles.sqStringRoundedTo(places: 1)) mi run"

        let comparisonSamples = historicalSamples.filter { $0.workout.id != sample.workout.id }
        guard let baselinePace = average(of: comparisonSamples.map(\.paceSecondsPerMile)) else {
            return "\(durationText) • \(heartRateText)"
        }

        let paceDelta = ((baselinePace - sample.paceSecondsPerMile) / baselinePace) * 100
        let paceDirection = paceDelta >= 0 ? "faster" : "easier"
        return "\(durationText) • \(abs(paceDelta).adaptivePercentString) \(paceDirection) than your baseline"
    }
}

// MARK: - Text

private extension SQWorkoutScoreService {
    func workoutSubtitle(for sample: RunningSample) -> String {
        let dateText = sample.workout.startDate?.formattedString(with: .medium) ?? "Recent run"
        return "\(sample.distanceMiles.sqStringRoundedTo(places: 1)) mi • \(sample.paceSecondsPerMile.timeCode())/mi • \(dateText)"
    }

    func footerText(
        performanceValue: Int,
        difficultyValue: Int,
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
            difficultySummary = "a meaningfully challenging run"
        default:
            difficultySummary = "a manageable training load"
        }

        switch context {
        case .dashboard:
            return "Latest running insight: performance looked \(performanceSummary), while difficulty landed as \(difficultySummary)."
        case .singleWorkout:
            return "This run graded \(performanceSummary) for output, and registered as \(difficultySummary)."
        }
    }
}

// MARK: - Helpers

private extension SQWorkoutScoreService {
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

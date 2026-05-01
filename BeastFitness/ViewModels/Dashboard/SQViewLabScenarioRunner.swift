//
//  SQViewLabScenarioRunner.swift
//  BeastFitness
//
//  Created by Codex on 4/24/26.
//

import Foundation
import HealthKit

struct SQViewLabScenarioRuntime {
    enum Content {
        case lifeScoreInsights(SQViewLabLifeScoreInsightsRuntime)
    }

    let scenarioId: String
    let content: Content
}

struct SQViewLabLifeScoreInsightsRuntime {
    let input: SQHealthIntelligenceInput
    let timeRange: AppTimeRange
    let insightsResult: SQInsightsResult
    let lifeScoreViewModel: SQLifeScoreViewModel
}

enum SQViewLabSimulationDayCount: Int, CaseIterable, Identifiable {
    case thirty = 30
    case sixty = 60
    case ninety = 90

    var id: Int { rawValue }

    var title: String {
        "\(rawValue) Days"
    }
}

struct SQViewLabSimulationActivityWeight: Identifiable {
    let activityType: HKWorkoutActivityType
    let weight: Double

    var id: UInt {
        activityType.rawValue
    }
}

struct SQViewLabSimulationPersona: Identifiable {
    let id: String
    let title: String
    let subtitle: String
    let notes: [String]
    let morningCompletionProbability: Double
    let eveningCompletionProbability: Double
    let restingHeartRateAvailability: Double
    let workoutProbability: Double
    let hardWorkoutProbability: Double
    let weekendViceMultiplier: Double
    let stressSpikeProbability: Double
    let sleepHoursRange: ClosedRange<Float>
    let sleepQualityRange: ClosedRange<Float>
    let energyRange: ClosedRange<Float>
    let moodRange: ClosedRange<Float>
    let mentalClarityRange: ClosedRange<Float>
    let motivationRange: ClosedRange<Float>
    let stressRange: ClosedRange<Float>
    let anxietyRange: ClosedRange<Float>
    let sorenessRange: ClosedRange<Float>
    let alcoholProbability: Double
    let alcoholRange: ClosedRange<Float>
    let caffeineProbability: Double
    let caffeineRange: ClosedRange<Float>
    let weedProbability: Double
    let weedRange: ClosedRange<Float>
    let nicotineProbability: Double
    let nicotineRange: ClosedRange<Float>
    let restingHeartRateBaselineRange: ClosedRange<Double>
    let activityMix: [SQViewLabSimulationActivityWeight]
}

struct SQViewLabSimulationRequest {
    let persona: SQViewLabSimulationPersona
    let dayCount: SQViewLabSimulationDayCount
    let seed: Int
    let referenceDate: Date
    let metricDefinitions: [SQMetricDefinition]
}

struct SQViewLabSimulationDistributionRow: Identifiable {
    let label: String
    let count: Int
    let percentage: Double

    var id: String { label }
}

struct SQViewLabSimulationDayOutput: Identifiable {
    let date: Date
    let score: Int?
    let stateTitle: String
    let heroSummary: String
    let heroAction: String
    let heroFamilyKey: String
    let surfacedInsightTitles: [String]
    let scoreDelta: Int?
    let componentScores: [String: Int]
    let topDriverTitles: [String]
    let topChangeTitles: [String]
    let actionRecommendationFamilies: [String]
    let surfacedCustomMetric: Bool
    let healthKitFallbackMetricIds: [String]
    let morningValues: [String: Float]
    let eveningValues: [String: Float]
    let restingHeartRate: Double?
    let workoutDescriptions: [String]
    let completedMorningCheckIn: Bool
    let completedEveningCheckIn: Bool

    var id: String {
        date.firebaseDailyDateKey
    }
}

struct SQViewLabSimulationReport {
    let persona: SQViewLabSimulationPersona
    let dayCount: Int
    let seed: Int
    let referenceDate: Date
    let averageScore: Double?
    let minimumScore: Int?
    let maximumScore: Int?
    let workoutDayPercentage: Double
    let morningCheckInCompletionPercentage: Double
    let eveningCheckInCompletionPercentage: Double
    let averageSleepHours: Double?
    let averageSleepQuality: Double?
    let averageAlcohol: Double?
    let averageCaffeine: Double?
    let averageRestingHeartRate: Double?
    let stateDistribution: [SQViewLabSimulationDistributionRow]
    let heroSummaryDistribution: [SQViewLabSimulationDistributionRow]
    let heroActionDistribution: [SQViewLabSimulationDistributionRow]
    let heroFamilyDistribution: [SQViewLabSimulationDistributionRow]
    let surfacedInsightDistribution: [SQViewLabSimulationDistributionRow]
    let scoreDeltaDistribution: [SQViewLabSimulationDistributionRow]
    let componentScoreDistribution: [SQViewLabSimulationDistributionRow]
    let topDriverDistribution: [SQViewLabSimulationDistributionRow]
    let topChangeDistribution: [SQViewLabSimulationDistributionRow]
    let actionRecommendationFamilyDistribution: [SQViewLabSimulationDistributionRow]
    let customMetricSurfacePercentage: Double
    let healthKitFallbackUsageByMetric: [SQViewLabSimulationDistributionRow]
    let lifeScoreComponentAvailability: [SQViewLabSimulationDistributionRow]
    let longestHeroSummaryRepeatStreak: Int
    let longestHeroActionRepeatStreak: Int
    let longestHeroFamilyRepeatStreak: Int
    let days: [SQViewLabSimulationDayOutput]
}

@MainActor
protocol SQViewLabScenarioRunning {
    func runtime(for scenario: SQViewLabController.Scenario) -> SQViewLabScenarioRuntime
    func simulationReport(for request: SQViewLabSimulationRequest) -> SQViewLabSimulationReport
}

@MainActor
struct SQViewLabScenarioRunner: SQViewLabScenarioRunning {
    private let insightsService: SQInsightsServicing
    private let lifeScoreBuilder: SQLifeScoreBuilding

    init(
        insightsService: SQInsightsServicing? = nil,
        lifeScoreBuilder: SQLifeScoreBuilding? = nil
    ) {
        self.insightsService = insightsService ?? SQInsightsService(
            surfacingMemoryStore: SQNoOpInsightSurfacingMemoryStore()
        )
        self.lifeScoreBuilder = lifeScoreBuilder ?? SQLifeScoreBuilder(
            sleepAggregationService: .init()
        )
    }

    func runtime(for scenario: SQViewLabController.Scenario) -> SQViewLabScenarioRuntime {
        switch scenario.content {
        case .lifeScoreInsights(let input):
            let insightsResult = insightsService.dashboardInsights(input: input)

            let lifeScoreViewModel = lifeScoreBuilder.buildViewModel(
                input: .init(
                    intelligenceInput: input,
                    insightsResult: insightsResult
                )
            )

            return .init(
                scenarioId: scenario.id,
                content: .lifeScoreInsights(
                    .init(
                        input: input,
                        timeRange: input.timeRange,
                        insightsResult: insightsResult,
                        lifeScoreViewModel: lifeScoreViewModel
                    )
                )
            )
        }
    }

    func simulationReport(for request: SQViewLabSimulationRequest) -> SQViewLabSimulationReport {
        let generatedDays = makeGeneratedDays(for: request)
        let surfacingMemoryStore = SQInMemoryInsightSurfacingMemoryStore()
        let simulationInsightsService = SQInsightsService(
            surfacingMemoryStore: surfacingMemoryStore
        )

        var outputs = [SQViewLabSimulationDayOutput]()
        let customMetricIds = Set(request.metricDefinitions.filter { !$0.isPreset }.map(\.id))

        for index in generatedDays.indices {
            let currentDay = generatedDays[index]
            let completedDays = Array(generatedDays[...index])
            let checkIns = completedDays.flatMap(\.checkIns).sorted { $0.date < $1.date }
            let sleepCheckIns = completedDays.flatMap(\.sleepCheckIns).sorted { $0.date < $1.date }
            let workouts = completedDays.flatMap(\.workouts).sorted {
                ($0.startDate ?? .distantPast) < ($1.startDate ?? .distantPast)
            }
            let restingHeartRateSummaries = completedDays.compactMap(\.restingHeartRateSummary).sorted { $0.date < $1.date }

            let input = SQHealthIntelligenceInput(
                referenceDate: currentDay.date,
                timeRange: .today,
                metricDefinitions: request.metricDefinitions,
                checkIns: checkIns,
                sleepCheckIns: sleepCheckIns,
                workouts: workouts,
                sleepData: currentDay.sleepData,
                restingHeartRateSummaries: restingHeartRateSummaries,
                currentCheckInPromptPeriod: .morning,
                hasCompletedCurrentPromptCheckIn: currentDay.completedMorningCheckIn,
                isLoggedIn: true
            )

            let insightsResult = simulationInsightsService.dashboardInsights(input: input)
            let lifeScoreViewModel = lifeScoreBuilder.buildViewModel(
                input: .init(
                    intelligenceInput: input,
                    insightsResult: insightsResult
                )
            )
            let surfacedSignalIds = insightsResult.insights.flatMap { insight in
                [insight.inputSignalId, insight.outputSignalId].compactMap { $0 }
            }

            outputs.append(
                .init(
                    date: currentDay.date,
                    score: lifeScoreViewModel.score,
                    stateTitle: lifeScoreViewModel.state.title,
                    heroSummary: punctuatedSentence(
                        lifeScoreViewModel.headlineText
                            ?? lifeScoreViewModel.primaryInsight?.title
                            ?? lifeScoreViewModel.state.summary
                    ),
                    heroAction: punctuatedSentence(
                        lifeScoreViewModel.actions.first?.summary ?? "No action."
                    ),
                    heroFamilyKey: "lifeScore.state.\(lifeScoreViewModel.state.title)",
                    surfacedInsightTitles: insightsResult.insights.map(\.title),
                    scoreDelta: lifeScoreViewModel.scoreDeltaFromPreviousDay,
                    componentScores: Dictionary(
                        uniqueKeysWithValues: lifeScoreViewModel.components.map { ($0.title, $0.score) }
                    ),
                    topDriverTitles: lifeScoreViewModel.drivers.prefix(3).map(\.title),
                    topChangeTitles: lifeScoreViewModel.changes.prefix(3).map(\.title),
                    actionRecommendationFamilies: insightsResult.insights.compactMap { insight in
                        insight.recommendationFamily.map { String(describing: $0) }
                    },
                    surfacedCustomMetric: surfacedSignalIds.contains { customMetricIds.contains($0) },
                    healthKitFallbackMetricIds: healthKitFallbackMetricIds(for: currentDay),
                    morningValues: currentDay.morningValues,
                    eveningValues: currentDay.eveningValues,
                    restingHeartRate: currentDay.restingHeartRateSummary?.average,
                    workoutDescriptions: currentDay.workouts.map {
                        "\($0.activityType.name) • perf \(formattedOptionalFloat($0.ratingUserPerformance)) • diff \(formattedOptionalFloat($0.ratingDifficulty))"
                    },
                    completedMorningCheckIn: currentDay.completedMorningCheckIn,
                    completedEveningCheckIn: currentDay.completedEveningCheckIn
                )
            )
        }

        return .init(
            persona: request.persona,
            dayCount: request.dayCount.rawValue,
            seed: request.seed,
            referenceDate: request.referenceDate,
            averageScore: outputs.compactMap(\.score).map(Double.init).average,
            minimumScore: outputs.compactMap(\.score).min(),
            maximumScore: outputs.compactMap(\.score).max(),
            workoutDayPercentage: percentage(
                matchingCount: outputs.filter { !$0.workoutDescriptions.isEmpty }.count,
                total: outputs.count
            ),
            morningCheckInCompletionPercentage: percentage(
                matchingCount: outputs.filter(\.completedMorningCheckIn).count,
                total: outputs.count
            ),
            eveningCheckInCompletionPercentage: percentage(
                matchingCount: outputs.filter(\.completedEveningCheckIn).count,
                total: outputs.count
            ),
            averageSleepHours: averageMetricValue(
                for: SQMetricId.sleepHours,
                in: outputs.map(\.morningValues)
            ),
            averageSleepQuality: averageMetricValue(
                for: SQMetricId.sleepQuality,
                in: outputs.map(\.morningValues)
            ),
            averageAlcohol: averageMetricValue(
                for: SQMetricId.alcohol,
                in: outputs.map(\.eveningValues)
            ),
            averageCaffeine: averageMetricValue(
                for: SQMetricId.caffeine,
                in: outputs.map(\.eveningValues)
            ),
            averageRestingHeartRate: outputs.compactMap(\.restingHeartRate).average,
            stateDistribution: distributionRows(for: outputs.map(\.stateTitle)),
            heroSummaryDistribution: distributionRows(for: outputs.map(\.heroSummary)),
            heroActionDistribution: distributionRows(for: outputs.map(\.heroAction)),
            heroFamilyDistribution: distributionRows(for: outputs.map(\.heroFamilyKey)),
            surfacedInsightDistribution: distributionRows(for: outputs.flatMap(\.surfacedInsightTitles)),
            scoreDeltaDistribution: distributionRows(for: outputs.map { scoreDeltaBucket($0.scoreDelta) }),
            componentScoreDistribution: distributionRows(
                for: outputs.flatMap { output in
                    output.componentScores.map { title, score in
                        "\(title): \(scoreBand(for: score))"
                    }
                }
            ),
            topDriverDistribution: distributionRows(for: outputs.map { $0.topDriverTitles.first ?? "None" }),
            topChangeDistribution: distributionRows(for: outputs.map { $0.topChangeTitles.first ?? "None" }),
            actionRecommendationFamilyDistribution: distributionRows(
                for: outputs.map { $0.actionRecommendationFamilies.first ?? "None" }
            ),
            customMetricSurfacePercentage: percentage(
                matchingCount: outputs.filter(\.surfacedCustomMetric).count,
                total: outputs.count
            ),
            healthKitFallbackUsageByMetric: distributionRows(
                for: Dictionary(grouping: outputs.flatMap(\.healthKitFallbackMetricIds), by: { $0 }).mapValues(\.count),
                total: outputs.count
            ),
            lifeScoreComponentAvailability: distributionRows(
                for: Dictionary(grouping: outputs.flatMap { Array($0.componentScores.keys) }, by: { $0 }).mapValues(\.count),
                total: outputs.count
            ),
            longestHeroSummaryRepeatStreak: longestRepeatStreak(for: outputs.map(\.heroSummary)),
            longestHeroActionRepeatStreak: longestRepeatStreak(for: outputs.map(\.heroAction)),
            longestHeroFamilyRepeatStreak: longestRepeatStreak(for: outputs.map(\.heroFamilyKey)),
            days: outputs
        )
    }
}

private extension SQViewLabScenarioRunner {
    struct GeneratedSimulationDay {
        let date: Date
        let morningValues: [String: Float]
        let eveningValues: [String: Float]
        let checkIns: [SQDailyCheckInStats]
        let sleepCheckIns: [SQDailyCheckInStats]
        let workouts: [SQWorkoutSessionable]
        let restingHeartRateSummary: SQHeartRateDailySummary?
        let sleepData: SQSleepDashboardData?
        let completedMorningCheckIn: Bool
        let completedEveningCheckIn: Bool
    }

    struct SeededRNG {
        private var state: UInt64

        init(seed: Int) {
            let resolvedSeed = seed == 0 ? 1 : seed
            self.state = UInt64(bitPattern: Int64(resolvedSeed))
        }

        mutating func nextUnit() -> Double {
            state = state &* 6364136223846793005 &+ 1442695040888963407
            let shifted = state >> 11
            return Double(shifted) / Double(1 << 53)
        }

        mutating func bool(probability: Double) -> Bool {
            nextUnit() < probability
        }

        mutating func double(in range: ClosedRange<Double>) -> Double {
            range.lowerBound + (range.upperBound - range.lowerBound) * nextUnit()
        }

        mutating func float(in range: ClosedRange<Float>) -> Float {
            Float(double(in: Double(range.lowerBound)...Double(range.upperBound)))
        }

        mutating func pickActivity(from weights: [SQViewLabSimulationActivityWeight]) -> HKWorkoutActivityType {
            let totalWeight = max(0.001, weights.map(\.weight).reduce(0, +))
            var cursor = nextUnit() * totalWeight

            for weight in weights {
                cursor -= weight.weight
                if cursor <= 0 {
                    return weight.activityType
                }
            }

            return weights.last?.activityType ?? .running
        }
    }

    func makeGeneratedDays(
        for request: SQViewLabSimulationRequest
    ) -> [GeneratedSimulationDay] {
        let calendar = Calendar.current
        let startOfReferenceDay = calendar.startOfDay(for: request.referenceDate)
        let definitionsById = Dictionary(uniqueKeysWithValues: request.metricDefinitions.map { ($0.id, $0) })
        let persona = request.persona
        var rng = SeededRNG(seed: request.seed)
        var generatedDays = [GeneratedSimulationDay]()

        var previousAlcohol: Float = 0
        var previousWeed: Float = 0
        var previousNicotine: Float = 0
        var previousCaffeine: Float = 0
        var previousWorkoutDifficulty: Float = 0
        var previousWorkoutCount = 0

        for offset in stride(from: request.dayCount.rawValue - 1, through: 0, by: -1) {
            let date = calendar.date(byAdding: .day, value: -offset, to: startOfReferenceDay) ?? startOfReferenceDay
            let weekday = calendar.component(.weekday, from: date)
            let isWeekend = weekday == 1 || weekday == 7
            let weekendMultiplier = isWeekend ? persona.weekendViceMultiplier : 1.0
            let stressSpike = rng.bool(probability: persona.stressSpikeProbability)

            let viceCarry = Double(previousAlcohol * 0.35) + Double(previousWeed * 0.22) + Double(previousNicotine * 0.18)
            let caffeineCarry = max(0, Double(previousCaffeine) - 160) / 180
            let workoutCarry = Double(previousWorkoutDifficulty) * 0.38 + Double(previousWorkoutCount) * 0.6
            let stressSpikePenalty = stressSpike ? 1.1 : 0.0

            let sleepHours = clamp(
                Double(rng.float(in: persona.sleepHoursRange)) - viceCarry * 0.10 - workoutCarry * 0.05 - stressSpikePenalty * 0.22,
                min: 3.8,
                max: 9.2
            )
            let sleepQuality = clamp(
                Double(rng.float(in: persona.sleepQualityRange)) - viceCarry * 0.22 - caffeineCarry * 0.18 - workoutCarry * 0.08 - stressSpikePenalty * 0.25,
                min: 1.5,
                max: 9.8
            )

            let soreness = clamp(
                Double(rng.float(in: persona.sorenessRange)) + Double(previousWorkoutDifficulty) * 0.28 - (sleepQuality - 6.0) * 0.10,
                min: 0.5,
                max: 9.8
            )
            let stress = clamp(
                Double(rng.float(in: persona.stressRange)) + stressSpikePenalty + viceCarry * 0.08 + max(0, 6.0 - sleepQuality) * 0.12,
                min: 0.5,
                max: 9.9
            )
            let anxiety = clamp(
                Double(rng.float(in: persona.anxietyRange)) + stressSpikePenalty * 0.7 + Double(previousNicotine) * 0.14 + max(0, 6.0 - sleepQuality) * 0.08,
                min: 0.5,
                max: 9.9
            )
            let energy = clamp(
                Double(rng.float(in: persona.energyRange)) + (sleepQuality - 6.5) * 0.34 + (sleepHours - 7.0) * 0.22 - stress * 0.12 - soreness * 0.08,
                min: 1.0,
                max: 9.9
            )
            let mood = clamp(
                Double(rng.float(in: persona.moodRange)) + (sleepQuality - 6.5) * 0.18 - stress * 0.10 - anxiety * 0.08 - viceCarry * 0.05,
                min: 1.0,
                max: 9.9
            )
            let mentalClarity = clamp(
                Double(rng.float(in: persona.mentalClarityRange)) + (sleepQuality - 6.5) * 0.24 - stress * 0.10 - Double(previousAlcohol) * 0.18 - Double(previousWeed) * 0.15,
                min: 1.0,
                max: 9.9
            )
            let motivation = clamp(
                Double(rng.float(in: persona.motivationRange)) + (energy - 6.0) * 0.18 - stress * 0.06 - soreness * 0.04,
                min: 1.0,
                max: 9.9
            )

            let restingHeartRate = rng.bool(probability: persona.restingHeartRateAvailability)
            ? clamp(
                rng.double(in: persona.restingHeartRateBaselineRange)
                + workoutCarry * 0.55
                + viceCarry * 0.45
                + max(0, 6.0 - sleepQuality) * 0.55
                + stressSpikePenalty * 1.4,
                min: 40,
                max: 95
            )
            : nil

            let workoutReadiness = (sleepQuality * 0.30) + (energy * 0.25) + (motivation * 0.18) + (mentalClarity * 0.10) - (stress * 0.10) - (soreness * 0.13)
            let workoutProbability = clampDouble(
                persona.workoutProbability + ((workoutReadiness - 6.0) * 0.04),
                min: 0.05,
                max: 0.95
            )
            let hasWorkout = rng.bool(probability: workoutProbability)

            var workouts = [SQWorkoutSessionable]()
            var workoutCount = 0
            var workoutDifficultyForCarry: Float = 0

            if hasWorkout {
                let isHardWorkout = rng.bool(
                    probability: clampDouble(
                        persona.hardWorkoutProbability + ((energy - 6.0) * 0.03) - ((soreness - 5.0) * 0.03),
                        min: 0.05,
                        max: 0.95
                    )
                )
                let activityType = rng.pickActivity(from: persona.activityMix)
                let difficulty = clamp(
                    rng.double(in: isHardWorkout ? 7.0...9.2 : 4.6...7.2)
                    + max(0, 6.2 - sleepQuality) * 0.10
                    + max(0, soreness - 5.5) * 0.08,
                    min: 1.0,
                    max: 10
                )
                let performance = clamp(
                    6.2
                    + (sleepQuality - 6.2) * 0.28
                    + (energy - 6.0) * 0.36
                    + (motivation - 6.0) * 0.18
                    - (stress - 4.5) * 0.12
                    - (soreness - 4.5) * 0.18
                    + rng.double(in: -0.4...0.4),
                    min: 1.5,
                    max: 9.8
                )
                let durationMinutes = workoutDurationMinutes(
                    activityType: activityType,
                    hardWorkout: isHardWorkout,
                    rng: &rng
                )
                let calories = Double(durationMinutes) * workoutCalorieMultiplier(for: activityType)
                let workout = makeWorkoutSession(
                    date: date,
                    startHour: isWeekend ? 9 : 7,
                    activityType: activityType,
                    performance: Float(performance),
                    difficulty: Float(difficulty),
                    durationMinutes: durationMinutes,
                    calories: calories
                )
                workouts = [workout]
                workoutCount = 1
                workoutDifficultyForCarry = Float(difficulty)
            }

            let lowEnergyBoost = max(0, 6.0 - energy) * 0.04
            let caffeine = rng.bool(
                probability: clampDouble(
                    persona.caffeineProbability + lowEnergyBoost + (stressSpike ? 0.08 : 0),
                    min: 0.0,
                    max: 0.98
                )
            )
            ? Float(clamp(
                rng.double(in: Double(persona.caffeineRange.lowerBound)...Double(persona.caffeineRange.upperBound))
                + max(0, 6.0 - energy) * 18,
                min: 0,
                max: 500
            ))
            : 0
            let alcohol = rng.bool(
                probability: clampDouble(
                    persona.alcoholProbability * weekendMultiplier + (stressSpike ? 0.06 : 0),
                    min: 0.0,
                    max: 0.98
                )
            )
            ? Float(clamp(
                rng.double(in: Double(persona.alcoholRange.lowerBound)...Double(persona.alcoholRange.upperBound)) * weekendMultiplier,
                min: 0,
                max: 10
            ))
            : 0
            let weed = rng.bool(
                probability: clampDouble(
                    persona.weedProbability * weekendMultiplier + (stressSpike ? 0.05 : 0),
                    min: 0.0,
                    max: 0.95
                )
            )
            ? Float(clamp(
                rng.double(in: Double(persona.weedRange.lowerBound)...Double(persona.weedRange.upperBound)),
                min: 0,
                max: 10
            ))
            : 0
            let nicotine = rng.bool(
                probability: clampDouble(
                    persona.nicotineProbability + (stressSpike ? 0.07 : 0),
                    min: 0.0,
                    max: 0.95
                )
            )
            ? Float(clamp(
                rng.double(in: Double(persona.nicotineRange.lowerBound)...Double(persona.nicotineRange.upperBound)),
                min: 0,
                max: 10
            ))
            : 0

            let morningValues: [String: Float] = [
                SQMetricId.sleepHours: Float(sleepHours),
                SQMetricId.sleepQuality: Float(sleepQuality),
                SQMetricId.energy: Float(energy),
                SQMetricId.mood: Float(mood),
                SQMetricId.mentalClarity: Float(mentalClarity),
                SQMetricId.motivation: Float(motivation),
                SQMetricId.stress: Float(stress),
                SQMetricId.anxiety: Float(anxiety),
                SQMetricId.soreness: Float(soreness)
            ]
            let eveningValues: [String: Float] = [
                SQMetricId.alcohol: alcohol,
                SQMetricId.caffeine: caffeine,
                SQMetricId.weed: weed,
                SQMetricId.nicotine: nicotine
            ]

            let completedMorningCheckIn = rng.bool(probability: persona.morningCompletionProbability)
            let completedEveningCheckIn = rng.bool(probability: persona.eveningCompletionProbability)

            let morningCheckIn = completedMorningCheckIn
            ? makeCheckIn(
                date: calendar.date(byAdding: .hour, value: 8, to: date) ?? date,
                period: .morning,
                values: morningValues,
                definitionsById: definitionsById
            )
            : nil
            let eveningCheckIn = completedEveningCheckIn
            ? makeCheckIn(
                date: calendar.date(byAdding: .hour, value: 20, to: date) ?? date,
                period: .evening,
                values: eveningValues,
                definitionsById: definitionsById
            )
            : nil

            generatedDays.append(
                .init(
                    date: date,
                    morningValues: completedMorningCheckIn ? morningValues : [:],
                    eveningValues: completedEveningCheckIn ? eveningValues : [:],
                    checkIns: [morningCheckIn, eveningCheckIn].compactMap { $0 },
                    sleepCheckIns: [morningCheckIn].compactMap { $0 },
                    workouts: workouts,
                    restingHeartRateSummary: restingHeartRate.map {
                        .init(date: date, average: $0, minimum: nil, maximum: nil)
                    },
                    sleepData: makeSleepDashboardData(
                        score: derivedSleepScore(
                            sleepHours: sleepHours,
                            sleepQuality: sleepQuality
                        )
                    ),
                    completedMorningCheckIn: completedMorningCheckIn,
                    completedEveningCheckIn: completedEveningCheckIn
                )
            )

            previousAlcohol = alcohol
            previousWeed = weed
            previousNicotine = nicotine
            previousCaffeine = caffeine
            previousWorkoutDifficulty = workoutDifficultyForCarry
            previousWorkoutCount = workoutCount
        }

        return generatedDays
    }

    func makeCheckIn(
        date: Date,
        period: SQMetricPeriod,
        values: [String: Float],
        definitionsById: [String: SQMetricDefinition]
    ) -> SQDailyCheckInStats {
        let metricValues = values.reduce(into: [String: SQMetricLoggedValue]()) { partialResult, pair in
            guard let definition = definitionsById[pair.key] else { return }
            let mode: SQMetricValueMode = definition.kind == .number ? .quantity : .scale
            partialResult[pair.key] = SQMetricEntry.loggedValue(
                rawValue: pair.value,
                enteredMode: mode,
                definition: definition
            )
        }

        return .init(
            date: date,
            period: period,
            values: values,
            metricValues: metricValues,
            notes: nil
        )
    }

    func makeWorkoutSession(
        date: Date,
        startHour: Int,
        activityType: HKWorkoutActivityType,
        performance: Float,
        difficulty: Float,
        durationMinutes: Double,
        calories: Double
    ) -> SQWorkoutSessionable {
        let calendar = Calendar.current
        let startDate = calendar.date(byAdding: .hour, value: startHour, to: date) ?? date
        let endDate = startDate.addingTimeInterval(durationMinutes * 60)

        let manualWorkout = SQManualWorkout(
            sourceId: "simulation-\(activityType.rawValue)-\(date.firebaseDailyDateKey)-\(startHour)",
            activityType: activityType,
            device: SQWorkoutDevice(name: "Simulation"),
            startDate: startDate,
            endDate: endDate,
            activeDuration: durationMinutes * 60,
            averageHeartRate: 142,
            totalCalories: calories,
            details: nil
        )

        let session = SQWorkoutSession(
            id: manualWorkout.sourceId,
            workoutSource: .manual(manualWorkout),
            overrideData: nil,
            hkWorkoutId: nil
        )
        session.setReviewData(
            notes: nil,
            ratingUserPerformance: performance,
            ratingDifficulty: difficulty,
            temperature: nil
        )
        return session
    }

    func workoutDurationMinutes(
        activityType: HKWorkoutActivityType,
        hardWorkout: Bool,
        rng: inout SeededRNG
    ) -> Double {
        switch activityType {
        case .running:
            return hardWorkout ? rng.double(in: 48...72) : rng.double(in: 32...52)
        case .cycling:
            return hardWorkout ? rng.double(in: 55...90) : rng.double(in: 40...70)
        case .walking:
            return hardWorkout ? rng.double(in: 40...60) : rng.double(in: 25...45)
        case .pickleball:
            return hardWorkout ? rng.double(in: 65...95) : rng.double(in: 45...75)
        default:
            return hardWorkout ? rng.double(in: 40...65) : rng.double(in: 25...50)
        }
    }

    func workoutCalorieMultiplier(for activityType: HKWorkoutActivityType) -> Double {
        switch activityType {
        case .running:
            return 10.5
        case .cycling:
            return 8.2
        case .walking:
            return 5.4
        case .pickleball:
            return 7.2
        default:
            return 6.8
        }
    }

    func derivedSleepScore(
        sleepHours: Double,
        sleepQuality: Double
    ) -> Double {
        let durationScore = sleepDurationScore(hours: sleepHours)
        let qualityScore = clamp(sleepQuality * 10, min: 0, max: 100)
        return clamp((qualityScore * 0.75) + (durationScore * 0.25), min: 0, max: 100)
    }

    func sleepDurationScore(hours: Double) -> Double {
        switch hours {
        case 8...:
            return 95
        case 7..<8:
            return 85
        case 6..<7:
            return 70
        case 5..<6:
            return 52
        default:
            return 38
        }
    }

    func makeSleepDashboardData(score: Double) -> SQSleepDashboardData {
        let clampedScore = clamp(score, min: 0, max: 100)
        let breakdown = SQSleepScoreBreakdown(
            durationScore: min(clampedScore * 0.40, SQSleepScoreBreakdown.maxDurationScore),
            efficiencyScore: min(clampedScore * 0.25, SQSleepScoreBreakdown.maxEfficiencyScore),
            fragmentationScore: min(clampedScore * 0.20, SQSleepScoreBreakdown.maxFragmentationScore),
            architectureScore: min(clampedScore * 0.15, SQSleepScoreBreakdown.maxArchitectureScore)
        )

        return .init(
            currentNights: [],
            priorNights: [],
            latestNight: nil,
            averageScore: breakdown,
            phaseAggregates: []
        )
    }

    func punctuatedSentence(_ text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return trimmed }
        if let lastCharacter = trimmed.last, [".", "!", "?"].contains(lastCharacter) {
            return trimmed
        }
        return trimmed + "."
    }

    func formattedOptionalFloat(_ value: Float?) -> String {
        guard let value else { return "n/a" }
        if value.rounded() == value {
            return String(Int(value))
        }
        return String(format: "%.1f", value)
    }

    func averageMetricValue(
        for metricId: String,
        in valueSets: [[String: Float]]
    ) -> Double? {
        valueSets.compactMap { $0[metricId].map(Double.init) }.average
    }

    func healthKitFallbackMetricIds(for day: GeneratedSimulationDay) -> [String] {
        guard day.sleepData != nil else { return [] }

        var metricIds = [String]()
        if !day.completedMorningCheckIn || day.morningValues[SQMetricId.sleepQuality] == nil {
            metricIds.append(SQMetricId.sleepQuality)
        }
        if !day.completedMorningCheckIn || day.morningValues[SQMetricId.sleepHours] == nil {
            metricIds.append(SQMetricId.sleepHours)
        }
        return metricIds
    }

    func scoreDeltaBucket(_ delta: Int?) -> String {
        guard let delta else { return "No prior score" }

        if delta <= -10 {
            return "Large drop (<= -10)"
        } else if delta <= -5 {
            return "Moderate drop (-5 to -9)"
        } else if delta <= -1 {
            return "Small drop (-1 to -4)"
        } else if delta == 0 {
            return "No change"
        } else if delta <= 4 {
            return "Small lift (+1 to +4)"
        } else if delta <= 9 {
            return "Moderate lift (+5 to +9)"
        } else {
            return "Large lift (>= +10)"
        }
    }

    func scoreBand(for score: Int) -> String {
        switch score {
        case ..<40:
            return "<40"
        case 40..<50:
            return "40-49"
        case 50..<60:
            return "50-59"
        case 60..<70:
            return "60-69"
        case 70..<80:
            return "70-79"
        case 80..<90:
            return "80-89"
        default:
            return "90+"
        }
    }

    func distributionRows(for values: [String]) -> [SQViewLabSimulationDistributionRow] {
        let total = max(values.count, 1)
        let counts = Dictionary(grouping: values, by: { $0 }).mapValues(\.count)

        return distributionRows(for: counts, total: total)
    }

    func distributionRows(
        for counts: [String: Int],
        total: Int
    ) -> [SQViewLabSimulationDistributionRow] {
        let resolvedTotal = max(total, 1)
        return counts
            .map { key, count in
                SQViewLabSimulationDistributionRow(
                    label: key,
                    count: count,
                    percentage: (Double(count) / Double(resolvedTotal)) * 100
                )
            }
            .sorted {
                if $0.count != $1.count {
                    return $0.count > $1.count
                }
                return $0.label < $1.label
            }
    }

    func longestRepeatStreak(for values: [String]) -> Int {
        guard let firstValue = values.first else { return 0 }

        var longest = 1
        var current = 1
        var previousValue = firstValue

        for value in values.dropFirst() {
            if value == previousValue {
                current += 1
            } else {
                longest = max(longest, current)
                current = 1
                previousValue = value
            }
        }

        return max(longest, current)
    }

    func percentage(
        matchingCount: Int,
        total: Int
    ) -> Double {
        guard total > 0 else { return 0 }
        return (Double(matchingCount) / Double(total)) * 100
    }

    func clamp(_ value: Double, min minimum: Double, max maximum: Double) -> Double {
        Swift.max(minimum, Swift.min(maximum, value))
    }

    func clampDouble(_ value: Double, min minimum: Double, max maximum: Double) -> Double {
        clamp(value, min: minimum, max: maximum)
    }
}

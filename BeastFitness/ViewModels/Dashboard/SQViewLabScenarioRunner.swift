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

enum SQViewLabCustomMetricId {
    static let violinPerformance = "custom.violinPerformance"
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
    let includesCustomPerformerMetric: Bool
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

struct SQViewLabShadowContributorAggregateRow: Identifiable {
    let metricId: String
    let title: String
    let daysAppeared: Int
    let averageContribution: Double
    let averageAbsoluteContribution: Double
    let positiveDays: Int
    let negativeDays: Int

    var id: String { metricId }
}

struct SQViewLabDynamicMetricCandidate: Identifiable, Hashable {
    let id: String
    let metricId: String
    let title: String
    let label: String
    let isCustom: Bool
    let effect: SQLifeScoreSignalEffect
    let sampleCount: Int
    let strength: Double
}

struct SQViewLabExploratoryRelationshipCandidate: Identifiable, Hashable {
    let id: String
    let inputSignalId: String
    let inputTitle: String
    let outputSignalId: String
    let outputTitle: String
    let timing: String
    let effectSize: Double
    let sampleCount: Int
    let confidence: String
    let isCustomOutput: Bool

    var label: String {
        "\(inputTitle) -> \(outputTitle) (\(timing))"
    }
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
    let signalSourceLabels: [String]
    let semanticRoleLabels: [String]
    let surfacedCustomMetric: Bool
    let customMetricValues: [String: Double]
    let healthKitFallbackMetricIds: [String]
    let shadowAdjustedScore: Int?
    let shadowDiagnosticContributionTotal: Double
    let shadowIncrementalContributionTotal: Double
    let shadowCustomContributionTotal: Double
    let shadowSensitiveContributionTotal: Double
    let shadowBehaviorContributionTotal: Double
    let diagnosticShadowContributors: [SQLifeScoreMetricContributor]
    let incrementalShadowContributors: [SQLifeScoreMetricContributor]
    let topDiagnosticShadowContributorTexts: [String]
    let topIncrementalShadowContributorTexts: [String]
    let topCustomIncrementalShadowContributorTexts: [String]
    let dynamicMetricDriverCandidateLabels: [String]
    let dynamicMetricChangeCandidateLabels: [String]
    let customMetricCandidateLabels: [String]
    let exploratoryRelationshipCandidateLabels: [String]
    let customOutputRelationshipCandidateLabels: [String]
    let topCustomRelationshipCandidateTexts: [String]
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
    let primaryActionRecommendationFamilyDistribution: [SQViewLabSimulationDistributionRow]
    let allActionRecommendationFamilyDistribution: [SQViewLabSimulationDistributionRow]
    let signalSourceDistribution: [SQViewLabSimulationDistributionRow]
    let semanticRoleDistribution: [SQViewLabSimulationDistributionRow]
    let customMetricLoggedDays: Int
    let averageCustomMetricValue: Double?
    let customMetricSurfacePercentage: Double
    let healthKitFallbackUsageByMetric: [SQViewLabSimulationDistributionRow]
    let lifeScoreComponentAvailability: [SQViewLabSimulationDistributionRow]
    let averageShadowAdjustedScore: Double?
    let averageShadowScoreDelta: Double?
    let averageShadowDiagnosticContributionTotal: Double
    let averageShadowIncrementalContributionTotal: Double
    let averageShadowCustomContributionTotal: Double
    let averageShadowSensitiveContributionTotal: Double
    let averageShadowBehaviorContributionTotal: Double
    let diagnosticShadowContributorAggregates: [SQViewLabShadowContributorAggregateRow]
    let incrementalShadowContributorAggregates: [SQViewLabShadowContributorAggregateRow]
    let customIncrementalShadowContributorAggregates: [SQViewLabShadowContributorAggregateRow]
    let dynamicMetricDriverCandidateDistribution: [SQViewLabSimulationDistributionRow]
    let dynamicMetricChangeCandidateDistribution: [SQViewLabSimulationDistributionRow]
    let customMetricDriverChangeCandidateDistribution: [SQViewLabSimulationDistributionRow]
    let exploratoryRelationshipCandidateDistribution: [SQViewLabSimulationDistributionRow]
    let customOutputRelationshipCandidateDistribution: [SQViewLabSimulationDistributionRow]
    let topCustomRelationshipCandidates: [SQViewLabExploratoryRelationshipCandidate]
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
        let featureBuilder = SQInsightFeatureBuilder()
        let shadowContributorBuilder = SQLifeScoreShadowMetricContributorBuilder()
        let dynamicMetricCandidateBuilder = DynamicMetricCandidateBuilder()
        let relationshipCandidateBuilder = ExploratoryRelationshipCandidateBuilder()

        var outputs = [SQViewLabSimulationDayOutput]()
        var latestCustomRelationshipCandidates = [SQViewLabExploratoryRelationshipCandidate]()
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
            let featureSnapshots = featureBuilder.makeFeatureSnapshots(
                checkIns: checkIns,
                workouts: workouts,
                metricDefinitions: request.metricDefinitions,
                sleepData: currentDay.sleepData,
                restingHeartRateSummaries: restingHeartRateSummaries
            )
            let currentSnapshot = featureSnapshots.first { $0.anchorDayKey == currentDay.date.firebaseDailyDateKey }
            let signalFeatures = currentSnapshot?.signalFeatures ?? [:]
            let shadowResult = shadowContributorBuilder.buildContributors(
                from: currentSnapshot,
                metricDefinitions: request.metricDefinitions
            )
            let shadowAdjustedScore = shadowAdjustedScore(
                baseScore: lifeScoreViewModel.score,
                contributionTotal: shadowResult.incrementalContributionTotal
            )
            let dynamicCandidates = dynamicMetricCandidateBuilder.candidates(
                from: featureSnapshots,
                metricDefinitions: request.metricDefinitions
            )
            let relationshipCandidates = relationshipCandidateBuilder.candidates(
                from: featureSnapshots,
                metricDefinitions: request.metricDefinitions
            )
            latestCustomRelationshipCandidates = Array(relationshipCandidates.filter(\.isCustomOutput).prefix(8))
            let surfacedSignalIds = insightsResult.insights.flatMap { insight in
                [insight.inputSignalId, insight.outputSignalId].compactMap { $0 }
            }
            let customMetricValues = signalFeatures.reduce(into: [String: Double]()) { partialResult, pair in
                guard customMetricIds.contains(pair.key) else { return }
                partialResult[pair.key] = pair.value.rawValue
            }

            let stateTitle = lifeScoreViewModel.state.title
            let heroSummary = punctuatedSentence(
                lifeScoreViewModel.headlineText
                    ?? lifeScoreViewModel.primaryInsight?.title
                    ?? lifeScoreViewModel.state.summary
            )
            let heroAction = punctuatedSentence(
                lifeScoreViewModel.actions.first?.summary ?? "No action."
            )
            let heroFamilyKey = "lifeScore.state.\(stateTitle)"
            let surfacedInsightTitles = insightsResult.insights.map(\.title)
            let componentScores = Dictionary(
                uniqueKeysWithValues: lifeScoreViewModel.components.map { ($0.title, $0.score) }
            )
            let topDriverTitles = lifeScoreViewModel.drivers.prefix(3).map(\.title)
            let topChangeTitles = lifeScoreViewModel.changes.prefix(3).map(\.title)
            let actionRecommendationFamilies = insightsResult.insights.compactMap { insight in
                insight.recommendationFamily.map { String(describing: $0) }
            }
            let signalSourceLabels = signalFeatures.values.map { String(describing: $0.source) }
            let semanticRoleLabels = signalFeatures.values.map { String(describing: $0.signalRole) }
            let surfacedCustomMetric = surfacedSignalIds.contains { customMetricIds.contains($0) }
            let healthKitFallbackMetricIds = signalFeatures.values
                .filter { $0.source == .healthKitFallback }
                .map(\.signalId)
                .sorted()
            let topDiagnosticShadowContributorTexts = shadowResult.diagnosticContributors
                .prefix(5)
                .map(shadowContributorText)
            let topIncrementalShadowContributorTexts = shadowResult.incrementalContributors
                .prefix(5)
                .map(shadowContributorText)
            let topCustomIncrementalShadowContributorTexts = shadowResult.incrementalContributors
                .filter(\.isCustom)
                .prefix(5)
                .map(shadowContributorText)
            let dynamicMetricDriverCandidateLabels = dynamicCandidates.drivers.prefix(5).map(\.label)
            let dynamicMetricChangeCandidateLabels = dynamicCandidates.changes.prefix(5).map(\.label)
            let customMetricCandidateLabels = (dynamicCandidates.drivers + dynamicCandidates.changes)
                .filter(\.isCustom)
                .prefix(8)
                .map(\.label)
            let exploratoryRelationshipCandidateLabels = relationshipCandidates.prefix(8).map(\.label)
            let customOutputRelationshipCandidateLabels = relationshipCandidates
                .filter(\.isCustomOutput)
                .prefix(8)
                .map(\.label)
            let topCustomRelationshipCandidateTexts = relationshipCandidates
                .filter(\.isCustomOutput)
                .prefix(5)
                .map(relationshipCandidateText)
            let workoutDescriptions = currentDay.workouts.map {
                "\($0.activityType.name) • perf \(formattedOptionalFloat($0.ratingUserPerformance)) • diff \(formattedOptionalFloat($0.ratingDifficulty))"
            }

            let output = SQViewLabSimulationDayOutput(
                date: currentDay.date,
                score: lifeScoreViewModel.score,
                stateTitle: stateTitle,
                heroSummary: heroSummary,
                heroAction: heroAction,
                heroFamilyKey: heroFamilyKey,
                surfacedInsightTitles: surfacedInsightTitles,
                scoreDelta: lifeScoreViewModel.scoreDeltaFromPreviousDay,
                componentScores: componentScores,
                topDriverTitles: topDriverTitles,
                topChangeTitles: topChangeTitles,
                actionRecommendationFamilies: actionRecommendationFamilies,
                signalSourceLabels: signalSourceLabels,
                semanticRoleLabels: semanticRoleLabels,
                surfacedCustomMetric: surfacedCustomMetric,
                customMetricValues: customMetricValues,
                healthKitFallbackMetricIds: healthKitFallbackMetricIds,
                shadowAdjustedScore: shadowAdjustedScore,
                shadowDiagnosticContributionTotal: shadowResult.diagnosticContributionTotal,
                shadowIncrementalContributionTotal: shadowResult.incrementalContributionTotal,
                shadowCustomContributionTotal: shadowResult.customMetricContributionTotal,
                shadowSensitiveContributionTotal: shadowResult.sensitiveMetricContributionTotal,
                shadowBehaviorContributionTotal: shadowResult.behaviorMetricContributionTotal,
                diagnosticShadowContributors: shadowResult.diagnosticContributors,
                incrementalShadowContributors: shadowResult.incrementalContributors,
                topDiagnosticShadowContributorTexts: topDiagnosticShadowContributorTexts,
                topIncrementalShadowContributorTexts: topIncrementalShadowContributorTexts,
                topCustomIncrementalShadowContributorTexts: topCustomIncrementalShadowContributorTexts,
                dynamicMetricDriverCandidateLabels: dynamicMetricDriverCandidateLabels,
                dynamicMetricChangeCandidateLabels: dynamicMetricChangeCandidateLabels,
                customMetricCandidateLabels: customMetricCandidateLabels,
                exploratoryRelationshipCandidateLabels: exploratoryRelationshipCandidateLabels,
                customOutputRelationshipCandidateLabels: customOutputRelationshipCandidateLabels,
                topCustomRelationshipCandidateTexts: topCustomRelationshipCandidateTexts,
                morningValues: currentDay.morningValues,
                eveningValues: currentDay.eveningValues,
                restingHeartRate: currentDay.restingHeartRateSummary?.average,
                workoutDescriptions: workoutDescriptions,
                completedMorningCheckIn: currentDay.completedMorningCheckIn,
                completedEveningCheckIn: currentDay.completedEveningCheckIn
            )
            outputs.append(output)
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
            primaryActionRecommendationFamilyDistribution: distributionRows(
                for: outputs.map { $0.actionRecommendationFamilies.first ?? "None" }
            ),
            allActionRecommendationFamilyDistribution: distributionRows(
                for: outputs.flatMap(\.actionRecommendationFamilies)
            ),
            signalSourceDistribution: distributionRows(for: outputs.flatMap(\.signalSourceLabels)),
            semanticRoleDistribution: distributionRows(for: outputs.flatMap(\.semanticRoleLabels)),
            customMetricLoggedDays: outputs.filter { !$0.customMetricValues.isEmpty }.count,
            averageCustomMetricValue: outputs
                .flatMap { $0.customMetricValues.values }
                .average,
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
            averageShadowAdjustedScore: outputs.compactMap(\.shadowAdjustedScore).map(Double.init).average,
            averageShadowScoreDelta: outputs.compactMap { output in
                guard let score = output.score, let shadowAdjustedScore = output.shadowAdjustedScore else { return nil }
                return Double(shadowAdjustedScore - score)
            }.average,
            averageShadowDiagnosticContributionTotal: outputs.map(\.shadowDiagnosticContributionTotal).average ?? 0,
            averageShadowIncrementalContributionTotal: outputs.map(\.shadowIncrementalContributionTotal).average ?? 0,
            averageShadowCustomContributionTotal: outputs.map(\.shadowCustomContributionTotal).average ?? 0,
            averageShadowSensitiveContributionTotal: outputs.map(\.shadowSensitiveContributionTotal).average ?? 0,
            averageShadowBehaviorContributionTotal: outputs.map(\.shadowBehaviorContributionTotal).average ?? 0,
            diagnosticShadowContributorAggregates: shadowContributorAggregateRows(
                for: outputs.flatMap(\.diagnosticShadowContributors)
            ),
            incrementalShadowContributorAggregates: shadowContributorAggregateRows(
                for: outputs.flatMap(\.incrementalShadowContributors)
            ),
            customIncrementalShadowContributorAggregates: shadowContributorAggregateRows(
                for: outputs.flatMap(\.incrementalShadowContributors).filter(\.isCustom)
            ),
            dynamicMetricDriverCandidateDistribution: distributionRows(
                for: outputs.flatMap(\.dynamicMetricDriverCandidateLabels)
            ),
            dynamicMetricChangeCandidateDistribution: distributionRows(
                for: outputs.flatMap(\.dynamicMetricChangeCandidateLabels)
            ),
            customMetricDriverChangeCandidateDistribution: distributionRows(
                for: outputs.flatMap(\.customMetricCandidateLabels)
            ),
            exploratoryRelationshipCandidateDistribution: distributionRows(
                for: outputs.flatMap(\.exploratoryRelationshipCandidateLabels)
            ),
            customOutputRelationshipCandidateDistribution: distributionRows(
                for: outputs.flatMap(\.customOutputRelationshipCandidateLabels)
            ),
            topCustomRelationshipCandidates: latestCustomRelationshipCandidates,
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

    struct DynamicMetricCandidateBuilder {
        private let semanticResolver = SQMetricSemanticResolver()

        func candidates(
            from snapshots: [SQInsightFeatureSnapshot],
            metricDefinitions: [SQMetricDefinition]
        ) -> (drivers: [SQViewLabDynamicMetricCandidate], changes: [SQViewLabDynamicMetricCandidate]) {
            var drivers = [SQViewLabDynamicMetricCandidate]()
            var changes = [SQViewLabDynamicMetricCandidate]()

            for definition in metricDefinitions where definition.isEnabled && !definition.isArchived {
                guard definition.insightMode != .off else { continue }
                let role = semanticResolver.signalRole(for: definition)
                guard isCandidateEligible(role: role) else { continue }

                let points = signalPoints(metricId: definition.id, snapshots: snapshots)
                guard points.count >= 14, hasEnoughVariance(points.map(\.value)) else { continue }

                if let driver = driverCandidate(
                    definition: definition,
                    points: points,
                    isCustom: !definition.isPreset
                ) {
                    drivers.append(driver)
                }

                if let change = changeCandidate(
                    definition: definition,
                    points: points,
                    isCustom: !definition.isPreset
                ) {
                    changes.append(change)
                }
            }

            return (
                drivers: drivers.sorted { $0.strength > $1.strength },
                changes: changes.sorted { $0.strength > $1.strength }
            )
        }

        private func signalPoints(
            metricId: String,
            snapshots: [SQInsightFeatureSnapshot]
        ) -> [(date: Date, value: Double)] {
            snapshots.compactMap { snapshot in
                guard let feature = snapshot.signalFeatures[metricId],
                      let value = feature.goalUtilityScore ?? feature.normalizedValue.map({ $0 * 100 }) else {
                    return nil
                }
                return (snapshot.date, value)
            }
            .sorted { $0.date < $1.date }
        }

        private func driverCandidate(
            definition: SQMetricDefinition,
            points: [(date: Date, value: Double)],
            isCustom: Bool
        ) -> SQViewLabDynamicMetricCandidate? {
            guard let latest = points.last else { return nil }
            let baseline = points.dropLast().suffix(21).map(\.value)
            guard baseline.count >= 10 else { return nil }

            let baselineAverage = baseline.reduce(0, +) / Double(baseline.count)
            let delta = latest.value - baselineAverage
            guard abs(delta) >= 8 else { return nil }

            let directionText = delta >= 0 ? "above baseline" : "below baseline"
            return .init(
                id: "driver-\(definition.id)-\(directionText)",
                metricId: definition.id,
                title: definition.title,
                label: "\(definition.title) \(directionText)",
                isCustom: isCustom,
                effect: delta >= 0 ? .positive : .negative,
                sampleCount: points.count,
                strength: abs(delta)
            )
        }

        private func changeCandidate(
            definition: SQMetricDefinition,
            points: [(date: Date, value: Double)],
            isCustom: Bool
        ) -> SQViewLabDynamicMetricCandidate? {
            let recent = points.suffix(7).map(\.value)
            let prior = points.dropLast(recent.count).suffix(14).map(\.value)
            guard recent.count >= 4, prior.count >= 8 else { return nil }

            let recentAverage = recent.reduce(0, +) / Double(recent.count)
            let priorAverage = prior.reduce(0, +) / Double(prior.count)
            let delta = recentAverage - priorAverage
            guard abs(delta) >= 6 else { return nil }

            let directionText = delta >= 0 ? "trending better" : "trending worse"
            return .init(
                id: "change-\(definition.id)-\(directionText)",
                metricId: definition.id,
                title: definition.title,
                label: "\(definition.title) \(directionText)",
                isCustom: isCustom,
                effect: delta >= 0 ? .positive : .negative,
                sampleCount: recent.count + prior.count,
                strength: abs(delta)
            )
        }

        private func isCandidateEligible(role: SQMetricSignalRole) -> Bool {
            switch role {
            case .outcome, .symptom, .bodyStat, .behavior:
                return true
            case .context, .automatic, .unknown:
                return false
            }
        }

        private func hasEnoughVariance(_ values: [Double]) -> Bool {
            guard let min = values.min(), let max = values.max() else { return false }
            return max - min >= 5
        }
    }

    struct ExploratoryRelationshipCandidateBuilder {
        private let semanticResolver = SQMetricSemanticResolver()

        func candidates(
            from snapshots: [SQInsightFeatureSnapshot],
            metricDefinitions: [SQMetricDefinition]
        ) -> [SQViewLabExploratoryRelationshipCandidate] {
            let customOutputDefinitions = metricDefinitions.filter {
                $0.isEnabled
                    && !$0.isArchived
                    && !$0.isPreset
                    && isOutputEligible(definition: $0)
            }
            guard !customOutputDefinitions.isEmpty else { return [] }

            var candidates = [SQViewLabExploratoryRelationshipCandidate]()

            for outputDefinition in customOutputDefinitions {
                for inputDefinition in metricDefinitions where inputDefinition.id != outputDefinition.id {
                    guard inputDefinition.isEnabled,
                          !inputDefinition.isArchived,
                          isInputEligible(definition: inputDefinition) else {
                        continue
                    }

                    if let sameDayCandidate = relationshipCandidate(
                        inputDefinition: inputDefinition,
                        outputDefinition: outputDefinition,
                        snapshots: snapshots,
                        timing: "same day",
                        dayShift: 0
                    ) {
                        candidates.append(sameDayCandidate)
                    }

                    if semanticResolver.signalRole(for: inputDefinition) == .behavior,
                       let nextDayCandidate = relationshipCandidate(
                        inputDefinition: inputDefinition,
                        outputDefinition: outputDefinition,
                        snapshots: snapshots,
                        timing: "next day",
                        dayShift: 1
                       ) {
                        candidates.append(nextDayCandidate)
                    }
                }
            }

            return candidates.sorted {
                if abs($0.effectSize) != abs($1.effectSize) {
                    return abs($0.effectSize) > abs($1.effectSize)
                }
                return $0.sampleCount > $1.sampleCount
            }
        }

        private func relationshipCandidate(
            inputDefinition: SQMetricDefinition,
            outputDefinition: SQMetricDefinition,
            snapshots: [SQInsightFeatureSnapshot],
            timing: String,
            dayShift: Int
        ) -> SQViewLabExploratoryRelationshipCandidate? {
            let snapshotsByDay = Dictionary(uniqueKeysWithValues: snapshots.map { ($0.anchorDayKey, $0) })
            let calendar = Calendar.current

            let samples = snapshots.compactMap { inputSnapshot -> (input: Double, output: Double)? in
                let outputDate = calendar.date(byAdding: .day, value: dayShift, to: inputSnapshot.date) ?? inputSnapshot.date
                let outputDayKey = outputDate.firebaseDailyDateKey
                guard let inputFeature = inputSnapshot.signalFeatures[inputDefinition.id],
                      let outputFeature = snapshotsByDay[outputDayKey]?.signalFeatures[outputDefinition.id],
                      let outputValue = outputFeature.goalUtilityScore ?? outputFeature.normalizedValue.map({ $0 * 100 }) else {
                    return nil
                }

                let inputValue = inputFeature.normalizedValue.map { $0 * 100 } ?? inputFeature.rawValue
                return (inputValue, outputValue)
            }

            guard samples.count >= 14 else { return nil }
            let outputValues = samples.map(\.output)
            guard hasEnoughVariance(outputValues) else { return nil }

            let lowHigh = bucketedSamples(
                samples,
                inputDefinition: inputDefinition
            )
            guard lowHigh.low.count >= 4, lowHigh.high.count >= 4 else { return nil }

            let lowAverage = lowHigh.low.reduce(0, +) / Double(lowHigh.low.count)
            let highAverage = lowHigh.high.reduce(0, +) / Double(lowHigh.high.count)
            let effectSize = highAverage - lowAverage
            guard abs(effectSize) >= 5 else { return nil }

            return .init(
                id: "\(inputDefinition.id)->\(outputDefinition.id)-\(timing)",
                inputSignalId: inputDefinition.id,
                inputTitle: inputDefinition.title,
                outputSignalId: outputDefinition.id,
                outputTitle: outputDefinition.title,
                timing: timing,
                effectSize: effectSize,
                sampleCount: samples.count,
                confidence: confidence(sampleCount: samples.count, effectSize: effectSize),
                isCustomOutput: !outputDefinition.isPreset
            )
        }

        private func bucketedSamples(
            _ samples: [(input: Double, output: Double)],
            inputDefinition: SQMetricDefinition
        ) -> (low: [Double], high: [Double]) {
            if inputDefinition.goalStyle == .avoidIt {
                return (
                    low: samples.filter { $0.input <= 0.01 }.map(\.output),
                    high: samples.filter { $0.input > 0.01 }.map(\.output)
                )
            }

            let sortedInputs = samples.map(\.input).sorted()
            let median = sortedInputs[sortedInputs.count / 2]
            return (
                low: samples.filter { $0.input <= median }.map(\.output),
                high: samples.filter { $0.input > median }.map(\.output)
            )
        }

        private func isInputEligible(definition: SQMetricDefinition) -> Bool {
            switch semanticResolver.signalRole(for: definition) {
            case .behavior, .bodyStat, .context:
                return true
            case .symptom:
                return [
                    SQMetricId.stress,
                    SQMetricId.anxiety,
                    SQMetricId.soreness
                ].contains(definition.id)
            case .outcome:
                return [
                    SQMetricId.sleepQuality,
                    SQMetricId.sleepHours,
                    SQMetricId.energy,
                    SQMetricId.mentalClarity,
                    SQMetricId.mood
                ].contains(definition.id)
            case .automatic, .unknown:
                return false
            }
        }

        private func isOutputEligible(definition: SQMetricDefinition) -> Bool {
            switch semanticResolver.signalRole(for: definition) {
            case .outcome, .symptom:
                return true
            case .behavior, .bodyStat, .context, .automatic, .unknown:
                return false
            }
        }

        private func hasEnoughVariance(_ values: [Double]) -> Bool {
            guard let min = values.min(), let max = values.max() else { return false }
            return max - min >= 5
        }

        private func confidence(sampleCount: Int, effectSize: Double) -> String {
            if sampleCount >= 28 && abs(effectSize) >= 9 {
                return "high"
            }

            if sampleCount >= 21 && abs(effectSize) >= 7 {
                return "medium"
            }

            return "low"
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
            var eveningValues: [String: Float] = [
                SQMetricId.alcohol: alcohol,
                SQMetricId.caffeine: caffeine,
                SQMetricId.weed: weed,
                SQMetricId.nicotine: nicotine
            ]

            if persona.includesCustomPerformerMetric,
               definitionsById[SQViewLabCustomMetricId.violinPerformance] != nil {
                let violinPerformance = clamp(
                    7.2
                    + (sleepQuality - 7.0) * 0.34
                    + (sleepHours - 7.0) * 0.18
                    - stress * 0.16
                    - Double(alcohol) * 0.24
                    - viceCarry * 0.10
                    + rng.double(in: -0.65...0.65),
                    min: 1.0,
                    max: 10.0
                )
                eveningValues[SQViewLabCustomMetricId.violinPerformance] = Float(violinPerformance)
            }

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
                        wakeDay: date,
                        sleepHours: sleepHours,
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

    func makeSleepDashboardData(
        wakeDay: Date,
        sleepHours: Double,
        score: Double
    ) -> SQSleepDashboardData {
        let calendar = Calendar.current
        let wakeDayStart = calendar.startOfDay(for: wakeDay)
        let wakeDate = calendar.date(byAdding: .hour, value: 7, to: wakeDayStart) ?? wakeDayStart
        let sleepStartDate = wakeDate.addingTimeInterval(-(sleepHours + 0.25) * 3600)
        let deepEndDate = sleepStartDate.addingTimeInterval(sleepHours * 3600 * 0.20)
        let coreEndDate = deepEndDate.addingTimeInterval(sleepHours * 3600 * 0.55)
        let remEndDate = coreEndDate.addingTimeInterval(sleepHours * 3600 * 0.25)
        let night = SQSleepNight(
            wakeDay: wakeDayStart,
            sleepStartDate: sleepStartDate,
            wakeDate: wakeDate,
            segments: [
                .init(phase: .deep, startDate: sleepStartDate, endDate: deepEndDate),
                .init(phase: .core, startDate: deepEndDate, endDate: coreEndDate),
                .init(phase: .rem, startDate: coreEndDate, endDate: remEndDate)
            ]
        )
        let clampedScore = clamp(score, min: 0, max: 100)
        let breakdown = SQSleepScoreBreakdown(
            durationScore: min(clampedScore * 0.40, SQSleepScoreBreakdown.maxDurationScore),
            efficiencyScore: min(clampedScore * 0.25, SQSleepScoreBreakdown.maxEfficiencyScore),
            fragmentationScore: min(clampedScore * 0.20, SQSleepScoreBreakdown.maxFragmentationScore),
            architectureScore: min(clampedScore * 0.15, SQSleepScoreBreakdown.maxArchitectureScore)
        )

        return .init(
            currentNights: [night],
            priorNights: [],
            latestNight: night,
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

    func shadowAdjustedScore(
        baseScore: Int?,
        contributionTotal: Double
    ) -> Int? {
        guard let baseScore else { return nil }
        return Int(clamp(Double(baseScore) + contributionTotal, min: 0, max: 100).rounded())
    }

    func shadowContributorText(_ contributor: SQLifeScoreMetricContributor) -> String {
        "\(contributor.title): \(signedDecimal(contributor.contributionPoints))"
    }

    func relationshipCandidateText(_ candidate: SQViewLabExploratoryRelationshipCandidate) -> String {
        "\(candidate.inputTitle) -> \(candidate.outputTitle) \(candidate.timing) • effect \(signedDecimal(candidate.effectSize)) • n=\(candidate.sampleCount) • \(candidate.confidence)"
    }

    func signedDecimal(_ value: Double) -> String {
        let prefix = value >= 0 ? "+" : ""
        return prefix + String(format: "%.1f", value)
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

    func shadowContributorAggregateRows(
        for contributors: [SQLifeScoreMetricContributor]
    ) -> [SQViewLabShadowContributorAggregateRow] {
        Dictionary(grouping: contributors, by: \.metricId)
            .compactMap { metricId, contributors -> SQViewLabShadowContributorAggregateRow? in
                guard let first = contributors.first else { return nil }
                let contributions = contributors.map(\.contributionPoints)
                let daysAppeared = contributors.count
                let averageContribution = contributions.reduce(0, +) / Double(daysAppeared)
                let averageAbsoluteContribution = contributions.map(abs).reduce(0, +) / Double(daysAppeared)

                return .init(
                    metricId: metricId,
                    title: first.title,
                    daysAppeared: daysAppeared,
                    averageContribution: averageContribution,
                    averageAbsoluteContribution: averageAbsoluteContribution,
                    positiveDays: contributions.filter { $0 > 0.05 }.count,
                    negativeDays: contributions.filter { $0 < -0.05 }.count
                )
            }
            .sorted {
                if $0.daysAppeared != $1.daysAppeared {
                    return $0.daysAppeared > $1.daysAppeared
                }
                return $0.averageAbsoluteContribution > $1.averageAbsoluteContribution
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

//
//  SQViewLabController.swift
//  BeastFitness
//
//  Created by Codex on 4/24/26.
//

import Foundation
import HealthKit
import UIKit

@MainActor
@Observable final class SQViewLabController: Identifiable {
    enum Mode: String, CaseIterable, Identifiable {
        case gallery = "Gallery"
        case scenario = "Scenario"
        case simulation = "Simulation"

        var id: String { rawValue }
    }

    enum Domain: String, CaseIterable, Identifiable {
        case lifeScoreInsights = "Life Score & Insights"

        var id: String { rawValue }

        var subtitle: String {
            switch self {
            case .lifeScoreInsights:
                return "Run shared scenario inputs through the real insight engine and Life Score builder, then preview the same production UI the dashboard uses."
            }
        }
    }

    struct Scenario: Identifiable {
        let id: String
        let domain: Domain
        let title: String
        let subtitle: String
        let tags: [String]
        let notes: [String]
        let content: Content
    }

    enum Content {
        case lifeScoreInsights(SQHealthIntelligenceInput)
    }

    let id = UUID().uuidString
    static let allSimulationPersonasId = "__all_simulation_personas__"

    private let hub: EventHub
    private let scenarioRunner: SQViewLabScenarioRunning
    @ObservationIgnored private var runtimeCache = [String: SQViewLabScenarioRuntime]()
    @ObservationIgnored private var simulationCache = [String: SQViewLabSimulationReport]()
    var previewMarkdown: String?
    var previewTitle: String = "Scenario Audit"

    var selectedMode: Mode = .gallery
    var selectedDomain: Domain = .lifeScoreInsights {
        didSet {
            guard selectedDomain != oldValue else { return }
            if !scenarios(for: selectedDomain).contains(where: { $0.id == selectedScenarioId }) {
                selectedScenarioId = scenarios(for: selectedDomain).first?.id ?? ""
            }
        }
    }
    var selectedScenarioId: String
    var selectedSimulationPersonaId: String
    var selectedSimulationDayCount: SQViewLabSimulationDayCount = .thirty
    var selectedSimulationSeed: Int = 41
    var selectedSimulationReferenceDate: Date = Calendar.current.startOfDay(for: .now)

    let scenarios: [Scenario]
    let simulationPersonas: [SQViewLabSimulationPersona]

    init(
        hub: EventHub? = nil,
        scenarioRunner: SQViewLabScenarioRunning? = nil,
        scenarios: [Scenario]? = nil,
        simulationPersonas: [SQViewLabSimulationPersona]? = nil
    ) {
        let resolvedScenarios = scenarios ?? Self.defaultScenarios()
        let resolvedSimulationPersonas = simulationPersonas ?? Self.defaultSimulationPersonas()

        self.hub = hub ?? SQAppState.shared.hub
        self.scenarioRunner = scenarioRunner ?? SQViewLabScenarioRunner()
        self.scenarios = resolvedScenarios
        self.simulationPersonas = resolvedSimulationPersonas
        self.selectedScenarioId = resolvedScenarios.first?.id ?? ""
        self.selectedSimulationPersonaId = resolvedSimulationPersonas.first?.id ?? ""
    }

    var currentScenarios: [Scenario] {
        scenarios(for: selectedDomain)
    }

    var selectedScenario: Scenario? {
        currentScenarios.first(where: { $0.id == selectedScenarioId }) ?? currentScenarios.first
    }

    var selectedScenarioRuntime: SQViewLabScenarioRuntime? {
        guard let selectedScenario else { return nil }
        return runtime(for: selectedScenario)
    }

    var selectedSimulationPersona: SQViewLabSimulationPersona? {
        guard selectedSimulationPersonaId != Self.allSimulationPersonasId else { return nil }
        return simulationPersonas.first(where: { $0.id == selectedSimulationPersonaId }) ?? simulationPersonas.first
    }

    var isAllSimulationPersonasSelected: Bool {
        selectedSimulationPersonaId == Self.allSimulationPersonasId
    }

    var selectedSimulationRequest: SQViewLabSimulationRequest? {
        guard let selectedSimulationPersona else { return nil }

        return simulationRequest(for: selectedSimulationPersona)
    }

    var selectedSimulationReport: SQViewLabSimulationReport? {
        guard let selectedSimulationRequest else { return nil }
        return simulationReport(for: selectedSimulationRequest)
    }

    var selectedSimulationReports: [SQViewLabSimulationReport] {
        if isAllSimulationPersonasSelected {
            return simulationPersonas.map { persona in
                let request = simulationRequest(for: persona)
                return simulationReport(for: request)
            }
        }

        return selectedSimulationReport.map { [$0] } ?? []
    }

    func scenarios(for domain: Domain) -> [Scenario] {
        scenarios.filter { $0.domain == domain }
    }

    func runtime(for scenario: Scenario) -> SQViewLabScenarioRuntime {
        if let cachedRuntime = runtimeCache[scenario.id] {
            return cachedRuntime
        }

        let runtime = scenarioRunner.runtime(for: scenario)
        runtimeCache[scenario.id] = runtime
        return runtime
    }

    func simulationReport(for request: SQViewLabSimulationRequest) -> SQViewLabSimulationReport {
        let metricKey = request.metricDefinitions.map(\.id).joined(separator: ",")
        let cacheKey = "\(request.persona.id)-\(request.dayCount.rawValue)-\(request.seed)-\(request.referenceDate.firebaseDailyDateKey)-\(metricKey)"
        if let cachedReport = simulationCache[cacheKey] {
            return cachedReport
        }

        let report = scenarioRunner.simulationReport(for: request)
        simulationCache[cacheKey] = report
        return report
    }

    func simulationRequest(for persona: SQViewLabSimulationPersona) -> SQViewLabSimulationRequest {
        .init(
            persona: persona,
            dayCount: selectedSimulationDayCount,
            seed: selectedSimulationSeed,
            referenceDate: selectedSimulationReferenceDate,
            metricDefinitions: Self.defaultMetricDefinitions(for: persona)
        )
    }

    func focus(on scenario: Scenario) {
        selectedDomain = scenario.domain
        selectedScenarioId = scenario.id
        selectedMode = .scenario
    }

    func openDetail(for runtime: SQViewLabScenarioRuntime) {
        switch runtime.content {
        case .lifeScoreInsights(let content):
            hub.domainEvents.send(.pushDashboardRoute(.lifeScoreDetail(controller: .init(viewModel: content.lifeScoreViewModel))))
        }
    }

    func previewDomainAudit() {
        previewTitle = "Scenario Audit"
        previewMarkdown = auditMarkdown(for: currentScenarios)
    }

    func previewSelectedScenarioAudit() {
        guard let selectedScenario else { return }
        previewTitle = "Scenario Audit"
        previewMarkdown = auditMarkdown(for: [selectedScenario])
    }

    func previewSimulationReport() {
        let reports = selectedSimulationReports
        guard !reports.isEmpty else { return }
        previewTitle = isAllSimulationPersonasSelected ? "All Persona Simulation Reports" : "Simulation Report"
        previewMarkdown = simulationMarkdown(for: reports)
    }

    func clearAuditPreview() {
        previewMarkdown = nil
    }

    func copyDomainAudit() {
        let markdown = auditMarkdown(for: currentScenarios)
        UIPasteboard.general.string = markdown
        hub.toastEvents.send(.present(.init(title: "Scenario audit copied", style: .success)))
    }

    func copyAuditPreview() {
        guard let previewMarkdown else { return }
        UIPasteboard.general.string = previewMarkdown
        hub.toastEvents.send(.present(.init(title: "Audit copied", style: .success)))
    }

    func copySimulationReport() {
        let reports = selectedSimulationReports
        guard !reports.isEmpty else { return }
        UIPasteboard.general.string = simulationMarkdown(for: reports)
        let title = isAllSimulationPersonasSelected ? "All persona reports copied" : "Simulation report copied"
        hub.toastEvents.send(.present(.init(title: title, style: .success)))
    }

    private func auditMarkdown(for scenarios: [Scenario]) -> String {
        var lines = [String]()
        lines.append("# View Lab Scenario Audit")
        lines.append("")
        lines.append("- Domain: \(selectedDomain.rawValue)")
        lines.append("- Scenario Count: \(scenarios.count)")
        lines.append("")

        for scenario in scenarios {
            lines.append(contentsOf: auditMarkdownLines(for: scenario))
            lines.append("")
        }

        return lines.joined(separator: "\n")
    }

    private func simulationMarkdown(for report: SQViewLabSimulationReport) -> String {
        simulationMarkdownLines(for: report).joined(separator: "\n")
    }

    private func simulationMarkdown(for reports: [SQViewLabSimulationReport]) -> String {
        guard reports.count > 1 else {
            return reports.first.map { simulationMarkdown(for: $0) } ?? ""
        }

        var lines = [String]()
        lines.append("# View Lab Simulation Reports")
        lines.append("")
        lines.append("- Persona Count: \(reports.count)")
        lines.append("- Simulated Days: \(reports.first?.dayCount ?? 0)")
        lines.append("- Seed: \(reports.first?.seed ?? selectedSimulationSeed)")
        lines.append("- Reference Date: \(reports.first?.referenceDate.formattedString(with: .medium) ?? selectedSimulationReferenceDate.formattedString(with: .medium))")
        lines.append("- Note: Use the same seed and reference date for before/after algorithm comparisons.")
        lines.append("")

        for report in reports {
            lines.append("---")
            lines.append("")
            lines.append("## \(report.persona.title)")
            lines.append("")
            let reportLines = simulationMarkdownLines(for: report)
            lines.append(contentsOf: reportLines.dropFirst(2))
            lines.append("")
        }

        return lines.joined(separator: "\n")
    }

    private func simulationMarkdownLines(for report: SQViewLabSimulationReport) -> [String] {
        var lines = [String]()
        lines.append("# View Lab Simulation Report")
        lines.append("")
        lines.append("- Persona: \(report.persona.title)")
        lines.append("- Subtitle: \(report.persona.subtitle)")
        lines.append("- Simulated Days: \(report.dayCount)")
        lines.append("- Seed: \(report.seed)")
        lines.append("- Reference Date: \(report.referenceDate.formattedString(with: .medium))")
        lines.append("- Note: Use the same seed and reference date for before/after algorithm comparisons.")
        lines.append("")

        if !report.persona.notes.isEmpty {
            lines.append("## Intended Coverage")
            for note in report.persona.notes {
                lines.append("- \(note)")
            }
            lines.append("")
        }

        lines.append("## Persona Inputs")
        lines.append("- Morning check-in completion: \(formattedPercent(report.persona.morningCompletionProbability * 100))")
        lines.append("- Evening check-in completion: \(formattedPercent(report.persona.eveningCompletionProbability * 100))")
        lines.append("- Workout probability: \(formattedPercent(report.persona.workoutProbability * 100))")
        lines.append("- Hard workout probability: \(formattedPercent(report.persona.hardWorkoutProbability * 100))")
        lines.append("- Includes custom performer metric: \(report.persona.includesCustomPerformerMetric ? "yes" : "no")")
        lines.append("- Stress spike probability: \(formattedPercent(report.persona.stressSpikeProbability * 100))")
        lines.append("- Weekend vice multiplier: \(formattedDouble(report.persona.weekendViceMultiplier))x")
        lines.append("- Baseline sleep hours range: \(formattedFloat(report.persona.sleepHoursRange.lowerBound))-\(formattedFloat(report.persona.sleepHoursRange.upperBound))")
        lines.append("- Baseline sleep quality range: \(formattedFloat(report.persona.sleepQualityRange.lowerBound))-\(formattedFloat(report.persona.sleepQualityRange.upperBound))")
        lines.append("- Baseline energy range: \(formattedFloat(report.persona.energyRange.lowerBound))-\(formattedFloat(report.persona.energyRange.upperBound))")
        lines.append("- Baseline mood range: \(formattedFloat(report.persona.moodRange.lowerBound))-\(formattedFloat(report.persona.moodRange.upperBound))")
        lines.append("- Baseline stress range: \(formattedFloat(report.persona.stressRange.lowerBound))-\(formattedFloat(report.persona.stressRange.upperBound))")
        lines.append("- Baseline anxiety range: \(formattedFloat(report.persona.anxietyRange.lowerBound))-\(formattedFloat(report.persona.anxietyRange.upperBound))")
        lines.append("- Baseline soreness range: \(formattedFloat(report.persona.sorenessRange.lowerBound))-\(formattedFloat(report.persona.sorenessRange.upperBound))")
        lines.append("- Alcohol probability/range: \(formattedPercent(report.persona.alcoholProbability * 100)) / \(formattedFloat(report.persona.alcoholRange.lowerBound))-\(formattedFloat(report.persona.alcoholRange.upperBound))")
        lines.append("- Caffeine probability/range: \(formattedPercent(report.persona.caffeineProbability * 100)) / \(formattedFloat(report.persona.caffeineRange.lowerBound))-\(formattedFloat(report.persona.caffeineRange.upperBound)) mg")
        lines.append("- Weed probability/range: \(formattedPercent(report.persona.weedProbability * 100)) / \(formattedFloat(report.persona.weedRange.lowerBound))-\(formattedFloat(report.persona.weedRange.upperBound))")
        lines.append("- Nicotine probability/range: \(formattedPercent(report.persona.nicotineProbability * 100)) / \(formattedFloat(report.persona.nicotineRange.lowerBound))-\(formattedFloat(report.persona.nicotineRange.upperBound))")
        lines.append("- Resting HR baseline range: \(formattedDouble(report.persona.restingHeartRateBaselineRange.lowerBound))-\(formattedDouble(report.persona.restingHeartRateBaselineRange.upperBound))")
        lines.append("- Activity mix: \(report.persona.activityMix.map { "\($0.activityType.name) \(formattedPercent($0.weight * 100))" }.joined(separator: ", "))")
        lines.append("")

        lines.append("## Aggregate Outputs")
        lines.append("- Average Life Score: \(report.averageScore.map(formattedDouble) ?? "n/a")")
        if let minimumScore = report.minimumScore, let maximumScore = report.maximumScore {
            lines.append("- Score range: \(minimumScore)-\(maximumScore)")
        }
        lines.append("- Workout days: \(formattedPercent(report.workoutDayPercentage))")
        lines.append("- Morning completion: \(formattedPercent(report.morningCheckInCompletionPercentage))")
        lines.append("- Evening completion: \(formattedPercent(report.eveningCheckInCompletionPercentage))")
        lines.append("- Avg sleep hours: \(report.averageSleepHours.map(formattedDouble) ?? "n/a")")
        lines.append("- Avg sleep quality: \(report.averageSleepQuality.map(formattedDouble) ?? "n/a")")
        lines.append("- Avg alcohol: \(report.averageAlcohol.map(formattedDouble) ?? "n/a")")
        lines.append("- Avg caffeine: \(report.averageCaffeine.map(formattedDouble) ?? "n/a")")
        lines.append("- Avg resting HR: \(report.averageRestingHeartRate.map(formattedDouble) ?? "n/a")")
        lines.append("- Custom metric logged days: \(report.customMetricLoggedDays)")
        lines.append("- Avg custom metric value: \(report.averageCustomMetricValue.map(formattedDouble) ?? "n/a")")
        lines.append("- Custom metric surfaced: \(formattedPercent(report.customMetricSurfacePercentage))")
        lines.append("- Avg personalized adjusted score: \(report.averageShadowAdjustedScore.map(formattedDouble) ?? "n/a")")
        lines.append("- Avg personalized score delta: \(report.averageShadowScoreDelta.map(formattedDouble) ?? "n/a")")
        lines.append("- Avg diagnostic contribution total: \(formattedDouble(report.averageShadowDiagnosticContributionTotal))")
        lines.append("- Avg incremental contribution total: \(formattedDouble(report.averageShadowIncrementalContributionTotal))")
        lines.append("- Avg custom incremental contribution: \(formattedDouble(report.averageShadowCustomContributionTotal))")
        lines.append("- Avg sensitive incremental contribution: \(formattedDouble(report.averageShadowSensitiveContributionTotal))")
        lines.append("- Avg behavior incremental contribution: \(formattedDouble(report.averageShadowBehaviorContributionTotal))")
        lines.append("- Longest repeated hero summary streak: \(report.longestHeroSummaryRepeatStreak) days")
        lines.append("- Longest repeated hero action streak: \(report.longestHeroActionRepeatStreak) days")
        lines.append("- Longest repeated hero family streak: \(report.longestHeroFamilyRepeatStreak) days")
        lines.append("")

        lines.append("## State Distribution")
        lines.append(contentsOf: simulationDistributionLines(report.stateDistribution))
        lines.append("")
        lines.append("## Hero Summary Distribution")
        lines.append(contentsOf: simulationDistributionLines(report.heroSummaryDistribution))
        lines.append("")
        lines.append("## Hero Action Distribution")
        lines.append(contentsOf: simulationDistributionLines(report.heroActionDistribution))
        lines.append("")
        lines.append("## Hero Family Distribution")
        lines.append(contentsOf: simulationDistributionLines(report.heroFamilyDistribution))
        lines.append("")
        lines.append("## Surfaced Insight Distribution")
        lines.append(contentsOf: simulationDistributionLines(report.surfacedInsightDistribution))
        lines.append("")
        lines.append("## Custom Surfaced Insight Distribution")
        lines.append(contentsOf: simulationDistributionLines(report.surfacedCustomInsightDistribution))
        lines.append("")
        lines.append("## Generated Custom Metric Insight Candidates")
        lines.append(contentsOf: simulationDistributionLines(report.generatedCustomMetricInsightCandidateDistribution))
        lines.append("")
        lines.append("## Custom Metric Insight Rejection Reasons")
        lines.append(contentsOf: simulationDistributionLines(report.customMetricInsightRejectionReasonDistribution))
        lines.append("")
        lines.append("## Score Delta Distribution")
        lines.append(contentsOf: simulationDistributionLines(report.scoreDeltaDistribution))
        lines.append("")
        lines.append("## Component Score Distribution")
        lines.append(contentsOf: simulationDistributionLines(report.componentScoreDistribution))
        lines.append("")
        lines.append("## Top Driver Distribution")
        lines.append(contentsOf: simulationDistributionLines(report.topDriverDistribution))
        lines.append("")
        lines.append("## Top Change Distribution")
        lines.append(contentsOf: simulationDistributionLines(report.topChangeDistribution))
        lines.append("")
        lines.append("## Primary Action Recommendation Family Distribution")
        lines.append(contentsOf: simulationDistributionLines(report.primaryActionRecommendationFamilyDistribution))
        lines.append("")
        lines.append("## All Action Recommendation Family Distribution")
        lines.append(contentsOf: simulationDistributionLines(report.allActionRecommendationFamilyDistribution))
        lines.append("")
        lines.append("## Signal Source Distribution")
        lines.append(contentsOf: simulationDistributionLines(report.signalSourceDistribution))
        lines.append("")
        lines.append("## Semantic Role Distribution")
        lines.append(contentsOf: simulationDistributionLines(report.semanticRoleDistribution))
        lines.append("")
        lines.append("## HealthKit Fallback Usage")
        lines.append(contentsOf: simulationDistributionLines(report.healthKitFallbackUsageByMetric))
        lines.append("")
        lines.append("## Life Score Component Availability")
        lines.append(contentsOf: simulationDistributionLines(report.lifeScoreComponentAvailability))
        lines.append("")
        lines.append("## Diagnostic Shadow Contributors")
        lines.append(contentsOf: shadowContributorAggregateLines(report.diagnosticShadowContributorAggregates))
        lines.append("")
        lines.append("## Incremental Shadow Contributors")
        lines.append(contentsOf: shadowContributorAggregateLines(report.incrementalShadowContributorAggregates))
        lines.append("")
        lines.append("## Custom Incremental Shadow Contributors")
        lines.append(contentsOf: shadowContributorAggregateLines(report.customIncrementalShadowContributorAggregates))
        lines.append("")
        lines.append("## Dynamic Metric Driver Candidate Distribution")
        lines.append(contentsOf: simulationDistributionLines(report.dynamicMetricDriverCandidateDistribution))
        lines.append("")
        lines.append("## Dynamic Metric Change Candidate Distribution")
        lines.append(contentsOf: simulationDistributionLines(report.dynamicMetricChangeCandidateDistribution))
        lines.append("")
        lines.append("## Custom Metric Driver/Change Candidate Distribution")
        lines.append(contentsOf: simulationDistributionLines(report.customMetricDriverChangeCandidateDistribution))
        lines.append("")
        lines.append("## Exploratory Relationship Candidate Distribution")
        lines.append(contentsOf: simulationDistributionLines(report.exploratoryRelationshipCandidateDistribution))
        lines.append("")
        lines.append("## Custom Output Relationship Candidate Distribution")
        lines.append(contentsOf: simulationDistributionLines(report.customOutputRelationshipCandidateDistribution))
        lines.append("")
        lines.append("## Actionable Custom Relationship Candidates")
        lines.append(contentsOf: simulationDistributionLines(report.actionableCustomRelationshipCandidateDistribution))
        lines.append("")
        lines.append("## Co-Movement Custom Relationship Candidates")
        lines.append(contentsOf: simulationDistributionLines(report.coMovementCustomRelationshipCandidateDistribution))
        lines.append("")
        lines.append("## Timing-Ambiguous Custom Relationship Candidates")
        lines.append(contentsOf: simulationDistributionLines(report.timingAmbiguousCustomRelationshipCandidateDistribution))
        lines.append("")
        lines.append("## Top Custom Relationship Candidates")
        lines.append(contentsOf: customRelationshipCandidateLines(report.topCustomRelationshipCandidates))
        lines.append("")
        lines.append("## Near-Miss Custom Relationship Candidates")
        lines.append(contentsOf: customRelationshipCandidateLines(report.nearMissCustomRelationshipCandidates))
        lines.append("")
        lines.append("## Would Surface Custom Relationship Insights")
        lines.append(contentsOf: simulationDistributionLines(report.wouldSurfaceCustomRelationshipDistribution))
        lines.append("")
        lines.append("## Would Surface Custom Relationship Details")
        lines.append(contentsOf: customRelationshipCandidateLines(report.wouldSurfaceCustomRelationshipCandidates))
        lines.append("")
        lines.append("## Rejected Relationship Surfacing Reasons")
        lines.append(contentsOf: simulationDistributionLines(report.rejectedRelationshipSurfacingReasonDistribution))
        lines.append("")

        lines.append("## Daily Log")
        for day in report.days {
            lines.append("- \(day.date.formattedString(with: .medium)) | score \(day.score.map(String.init) ?? "n/a") | state \(day.stateTitle)")
            lines.append("  - score delta: \(day.scoreDelta.map(String.init) ?? "n/a")")
            lines.append("  - personalized adjusted score: \(day.shadowAdjustedScore.map(String.init) ?? "n/a")")
            lines.append("  - diagnostic contribution total: \(formattedDouble(day.shadowDiagnosticContributionTotal))")
            lines.append("  - incremental contribution total: \(formattedDouble(day.shadowIncrementalContributionTotal))")
            lines.append("  - custom incremental contribution: \(formattedDouble(day.shadowCustomContributionTotal))")
            lines.append("  - sensitive incremental contribution: \(formattedDouble(day.shadowSensitiveContributionTotal))")
            lines.append("  - behavior incremental contribution: \(formattedDouble(day.shadowBehaviorContributionTotal))")
            lines.append("  - top diagnostic contributors: \(day.topDiagnosticShadowContributorTexts.isEmpty ? "none" : day.topDiagnosticShadowContributorTexts.joined(separator: " | "))")
            lines.append("  - top incremental contributors: \(day.topIncrementalShadowContributorTexts.isEmpty ? "none" : day.topIncrementalShadowContributorTexts.joined(separator: " | "))")
            lines.append("  - top custom incremental contributors: \(day.topCustomIncrementalShadowContributorTexts.isEmpty ? "none" : day.topCustomIncrementalShadowContributorTexts.joined(separator: " | "))")
            lines.append("  - dynamic driver candidates: \(day.dynamicMetricDriverCandidateLabels.isEmpty ? "none" : day.dynamicMetricDriverCandidateLabels.joined(separator: " | "))")
            lines.append("  - dynamic change candidates: \(day.dynamicMetricChangeCandidateLabels.isEmpty ? "none" : day.dynamicMetricChangeCandidateLabels.joined(separator: " | "))")
            lines.append("  - custom metric candidates: \(day.customMetricCandidateLabels.isEmpty ? "none" : day.customMetricCandidateLabels.joined(separator: " | "))")
            lines.append("  - generated custom metric insights: \(day.generatedCustomMetricInsightCandidateTitles.isEmpty ? "none" : day.generatedCustomMetricInsightCandidateTitles.joined(separator: " | "))")
            lines.append("  - custom metric insight rejections: \(day.customMetricInsightRejectionReasons.isEmpty ? "none" : day.customMetricInsightRejectionReasons.joined(separator: " | "))")
            lines.append("  - exploratory relationship candidates: \(day.exploratoryRelationshipCandidateLabels.isEmpty ? "none" : day.exploratoryRelationshipCandidateLabels.joined(separator: " | "))")
            lines.append("  - custom output relationship candidates: \(day.customOutputRelationshipCandidateLabels.isEmpty ? "none" : day.customOutputRelationshipCandidateLabels.joined(separator: " | "))")
            lines.append("  - actionable custom relationships: \(day.actionableCustomRelationshipCandidateLabels.isEmpty ? "none" : day.actionableCustomRelationshipCandidateLabels.joined(separator: " | "))")
            lines.append("  - co-movement custom relationships: \(day.coMovementCustomRelationshipCandidateLabels.isEmpty ? "none" : day.coMovementCustomRelationshipCandidateLabels.joined(separator: " | "))")
            lines.append("  - timing-ambiguous custom relationships: \(day.timingAmbiguousCustomRelationshipCandidateLabels.isEmpty ? "none" : day.timingAmbiguousCustomRelationshipCandidateLabels.joined(separator: " | "))")
            lines.append("  - top custom relationship details: \(day.topCustomRelationshipCandidateTexts.isEmpty ? "none" : day.topCustomRelationshipCandidateTexts.joined(separator: " | "))")
            lines.append("  - near-miss custom relationships: \(day.nearMissCustomRelationshipCandidateLabels.isEmpty ? "none" : day.nearMissCustomRelationshipCandidateLabels.joined(separator: " | "))")
            lines.append("  - near-miss custom relationship details: \(day.nearMissCustomRelationshipCandidateTexts.isEmpty ? "none" : day.nearMissCustomRelationshipCandidateTexts.joined(separator: " | "))")
            lines.append("  - would-surface custom relationships: \(day.wouldSurfaceCustomRelationshipTitles.isEmpty ? "none" : day.wouldSurfaceCustomRelationshipTitles.joined(separator: " | "))")
            lines.append("  - rejected relationship surfacing reasons: \(day.rejectedRelationshipSurfacingReasons.isEmpty ? "none" : day.rejectedRelationshipSurfacingReasons.joined(separator: " | "))")
            lines.append("  - hero summary: \(day.heroSummary)")
            lines.append("  - hero action: \(day.heroAction)")
            lines.append("  - hero family: \(day.heroFamilyKey)")
            lines.append("  - component scores: \(componentScoreText(day.componentScores))")
            lines.append("  - top drivers: \(day.topDriverTitles.isEmpty ? "none" : day.topDriverTitles.joined(separator: " | "))")
            lines.append("  - top changes: \(day.topChangeTitles.isEmpty ? "none" : day.topChangeTitles.joined(separator: " | "))")
            lines.append("  - recommendation families: \(day.actionRecommendationFamilies.isEmpty ? "none" : day.actionRecommendationFamilies.joined(separator: " | "))")
            lines.append("  - signal sources: \(day.signalSourceLabels.isEmpty ? "none" : day.signalSourceLabels.joined(separator: " | "))")
            lines.append("  - semantic roles: \(day.semanticRoleLabels.isEmpty ? "none" : day.semanticRoleLabels.joined(separator: " | "))")
            lines.append("  - custom metric surfaced: \(day.surfacedCustomMetric ? "yes" : "no")")
            lines.append("  - custom metric values: \(doubleDictionaryText(day.customMetricValues))")
            lines.append("  - HealthKit fallback metrics: \(day.healthKitFallbackMetricIds.isEmpty ? "none" : day.healthKitFallbackMetricIds.joined(separator: ", "))")
            lines.append("  - morning check-in complete: \(day.completedMorningCheckIn ? "yes" : "no")")
            lines.append("  - evening check-in complete: \(day.completedEveningCheckIn ? "yes" : "no")")
            lines.append("  - morning values: \(metricDictionaryText(day.morningValues))")
            lines.append("  - evening values: \(metricDictionaryText(day.eveningValues))")
            lines.append("  - resting HR: \(day.restingHeartRate.map(formattedDouble) ?? "n/a")")
            lines.append("  - workouts: \(day.workoutDescriptions.isEmpty ? "none" : day.workoutDescriptions.joined(separator: " | "))")
            lines.append("  - surfaced insights: \(day.surfacedInsightTitles.isEmpty ? "none" : day.surfacedInsightTitles.joined(separator: " | "))")
            lines.append("  - custom surfaced insights: \(day.surfacedCustomInsightTitles.isEmpty ? "none" : day.surfacedCustomInsightTitles.joined(separator: " | "))")
        }

        return lines
    }

    private func auditMarkdownLines(for scenario: Scenario) -> [String] {
        let runtime = runtime(for: scenario)
        var lines = [String]()

        lines.append("## \(scenario.title)")
        lines.append("")
        lines.append("- Subtitle: \(scenario.subtitle)")

        if !scenario.tags.isEmpty {
            lines.append("- Tags: \(scenario.tags.joined(separator: ", "))")
        }

        if !scenario.notes.isEmpty {
            lines.append("- Intended coverage:")
            for note in scenario.notes {
                lines.append("  - \(note)")
            }
        }

        switch runtime.content {
        case .lifeScoreInsights(let content):
            lines.append("")
            lines.append("### Trigger Inputs")
            lines.append(contentsOf: triggerInputLines(for: content))
            lines.append("")
            lines.append("### Life Score Output")
            lines.append(contentsOf: lifeScoreAuditLines(for: content))
            lines.append("")
            lines.append("### Surfaced Insights")
            if content.insightsResult.insights.isEmpty {
                lines.append("- None")
            } else {
                for insight in content.insightsResult.insights {
                    lines.append(contentsOf: insightAuditLines(insight))
                }
            }
            lines.append("")
            lines.append("### Drivers")
            if content.insightsResult.drivers.isEmpty {
                lines.append("- None")
            } else {
                for driver in content.insightsResult.drivers {
                    lines.append(driverAuditLine(driver))
                }
            }
            lines.append("")
            lines.append("### Recent Changes")
            if content.insightsResult.changes.isEmpty {
                lines.append("- None")
            } else {
                for change in content.insightsResult.changes {
                    lines.append(changeAuditLine(change))
                }
            }
            lines.append("")
            lines.append("### Actions")
            if content.insightsResult.actions.isEmpty {
                lines.append("- None")
            } else {
                for action in content.insightsResult.actions {
                    lines.append(actionAuditLine(action))
                }
            }
        }

        return lines
    }

    private func triggerInputLines(for content: SQViewLabLifeScoreInsightsRuntime) -> [String] {
        let input = content.input
        let calendar = Calendar.current
        let referenceDay = calendar.startOfDay(for: input.referenceDate)
        let latestMorning = input.checkIns.first(where: {
            calendar.isDate($0.date, inSameDayAs: referenceDay) && $0.period == .morning
        })
        let latestEvening = input.checkIns.first(where: {
            calendar.isDate($0.date, inSameDayAs: referenceDay) && $0.period == .evening
        })
        let recentWorkouts = input.workouts
            .filter { workout in
                guard let startDate = workout.startDate else { return false }
                let startOfWorkoutDay = calendar.startOfDay(for: startDate)
                let dayDifference = calendar.dateComponents([.day], from: startOfWorkoutDay, to: referenceDay).day ?? .max
                return dayDifference >= 0 && dayDifference <= 2
            }
            .sorted { ($0.startDate ?? .distantPast) > ($1.startDate ?? .distantPast) }

        var lines = [String]()
        lines.append("- Time range: \(input.timeRange.rawValue)")
        lines.append("- Check-ins: \(input.checkIns.count)")
        lines.append("- Workouts: \(input.workouts.count)")
        lines.append("- Sleep data provided: \(input.sleepData == nil ? "no" : "yes")")
        lines.append("- Resting HR summaries: \(input.restingHeartRateSummaries.count)")

        if let latestMorning {
            lines.append("- Morning check-in:")
            lines.append(contentsOf: metricValueLines(
                values: latestMorning.values,
                definitions: input.metricDefinitions,
                prefix: "  - "
            ))
        }

        if let latestEvening {
            lines.append("- Evening check-in:")
            lines.append(contentsOf: metricValueLines(
                values: latestEvening.values,
                definitions: input.metricDefinitions,
                prefix: "  - "
            ))
        }

        if recentWorkouts.isEmpty {
            lines.append("- Recent workouts (last 3 days): none")
        } else {
            lines.append("- Recent workouts (last 3 days):")
            for workout in recentWorkouts {
                lines.append("  - \(workout.activityType.name) • perf \(formattedOptionalFloat(workout.ratingUserPerformance)) • diff \(formattedOptionalFloat(workout.ratingDifficulty)) • duration \(formattedDuration(workout.activeDuration))")
            }
        }

        return lines
    }

    private func lifeScoreAuditLines(for content: SQViewLabLifeScoreInsightsRuntime) -> [String] {
        let viewModel = content.lifeScoreViewModel
        var lines = [String]()
        lines.append("- Score: \(viewModel.score.map(String.init) ?? "Calibrating")")
        lines.append("- State: \(viewModel.state.title)")
        lines.append("- Delta vs yesterday: \(viewModel.scoreDeltaText ?? "None")")
        lines.append("- Hero summary: \(viewModel.headlineText ?? viewModel.primaryInsight?.title ?? viewModel.state.summary)")
        lines.append("- Hero action: \(viewModel.actions.first?.summary ?? "None")")
        if let refinementPromptText = viewModel.refinementPromptText {
            lines.append("- Refinement prompt: \(refinementPromptText)")
        }
        if !viewModel.drivers.isEmpty {
            lines.append("- Hero drivers: \(viewModel.drivers.map(\.title).joined(separator: ", "))")
        }
        return lines
    }

    private func insightAuditLines(_ insight: SQInsight) -> [String] {
        [
            "- \(insight.title)",
            "  - summary: \(insight.summary)",
            "  - actionText: \(insight.actionText)",
            "  - familyKey: \(insight.familyKey)",
            "  - class: \(String(describing: insight.insightClass))",
            "  - category: \(insight.category.rawValue)",
            "  - effect: \(formattedEffect(insight.effect))",
            "  - confidence: \(insight.confidence.rawValue)",
            "  - inputSignalId: \(insight.inputSignalId ?? "nil")",
            "  - outputSignalId: \(insight.outputSignalId ?? "nil")",
            "  - recommendationFamily: \(insight.recommendationFamily.map { String(describing: $0) } ?? "nil")",
            "  - driverText: \(insight.driverText)",
            "  - outcomeText: \(insight.outcomeText)",
            "  - deltaText: \(insight.deltaText)",
            "  - sampleCount: \(insight.sampleCount)",
            "  - rankingScore: \(formattedDouble(insight.rankingScore))"
        ]
    }

    private func driverAuditLine(_ driver: SQInsightDriver) -> String {
        "- \(driver.direction == .supportive ? "+" : "-") \(driver.title) • signalId=\(driver.signalId) • delta=\(driver.deltaText) • recent=\(formattedDouble(driver.recentAverage)) • baseline=\(formattedDouble(driver.baselineAverage)) • summary=\(driver.summary)"
    }

    private func changeAuditLine(_ change: SQInsightChange) -> String {
        "- \(change.direction == .improved ? "↑" : "↓") \(change.title) • signalId=\(change.signalId) • delta=\(change.deltaText) • recent=\(formattedDouble(change.recentAverage)) • prior=\(formattedDouble(change.priorAverage)) • timeframe=\(change.timeframeText)"
    }

    private func actionAuditLine(_ action: SQInsightAction) -> String {
        "- \(action.summary) • title=\(action.title) • tone=\(String(describing: action.tone)) • rankingScore=\(formattedDouble(action.rankingScore))"
    }

    private func metricValueLines(
        values: [String: Float],
        definitions: [SQMetricDefinition],
        prefix: String
    ) -> [String] {
        values.keys.sorted().compactMap { metricId in
            guard let value = values[metricId] else { return nil }
            let title = definitions.first(where: { $0.id == metricId })?.title ?? metricId
            return "\(prefix)\(title): \(formattedFloat(value))"
        }
    }

    private func formattedFloat(_ value: Float) -> String {
        if value.rounded() == value {
            return String(Int(value))
        }
        return String(format: "%.1f", value)
    }

    private func formattedOptionalFloat(_ value: Float?) -> String {
        guard let value else { return "n/a" }
        return formattedFloat(value)
    }

    private func formattedDouble(_ value: Double) -> String {
        if value.rounded() == value {
            return String(Int(value))
        }
        return String(format: "%.1f", value)
    }

    private func formattedSignedDouble(_ value: Double) -> String {
        let prefix = value >= 0 ? "+" : ""
        return prefix + formattedDouble(value)
    }

    private func formattedDuration(_ duration: Double?) -> String {
        guard let duration else { return "n/a" }
        let minutes = Int((duration / 60).rounded())
        return "\(minutes)m"
    }

    private func formattedEffect(_ effect: SQInsightEffect) -> String {
        switch effect {
        case .positive:
            return "positive"
        case .negative:
            return "negative"
        case .neutral:
            return "neutral"
        }
    }

    private func formattedPercent(_ value: Double) -> String {
        String(format: "%.1f%%", value)
    }

    private func simulationDistributionLines(
        _ rows: [SQViewLabSimulationDistributionRow]
    ) -> [String] {
        guard !rows.isEmpty else { return ["- None"] }

        return rows.map { row in
            "- \(row.label) — \(row.count) days (\(formattedPercent(row.percentage)))"
        }
    }

    private func shadowContributorAggregateLines(
        _ rows: [SQViewLabShadowContributorAggregateRow]
    ) -> [String] {
        guard !rows.isEmpty else { return ["- None"] }

        return rows.map { row in
            "- \(row.title) — \(row.daysAppeared) days, avg \(formattedSignedDouble(row.averageContribution)), avg abs \(formattedDouble(row.averageAbsoluteContribution)), positive \(row.positiveDays), negative \(row.negativeDays)"
        }
    }

    private func customRelationshipCandidateLines(
        _ candidates: [SQViewLabExploratoryRelationshipCandidate]
    ) -> [String] {
        guard !candidates.isEmpty else { return ["- None"] }

        return candidates.map { candidate in
            let lowAverage = candidate.lowBucketAverage.map(formattedDouble) ?? "n/a"
            let highAverage = candidate.highBucketAverage.map(formattedDouble) ?? "n/a"
            let rejectionText = candidate.rejectionReason.map { ", rejected=\($0)" } ?? ""
            return "- \(candidate.inputTitle) -> \(candidate.outputTitle) (\(candidate.timing)) — \(candidate.candidateType.title), effect \(formattedSignedDouble(candidate.effectSize)), n=\(candidate.sampleCount), low \(candidate.lowBucketCount) avg \(lowAverage), high \(candidate.highBucketCount) avg \(highAverage), confidence=\(candidate.confidence), confidenceReason=\(candidate.confidenceExplanation)\(rejectionText)"
        }
    }

    private func metricDictionaryText(_ values: [String: Float]) -> String {
        guard !values.isEmpty else { return "none" }

        let definitionsById = Dictionary(
            uniqueKeysWithValues: (Self.defaultMetricDefinitions() + [Self.customViolinPerformanceMetricDefinition(sortOrder: 999)])
                .map { ($0.id, $0.title) }
        )

        return values.keys.sorted().compactMap { metricId in
            guard let value = values[metricId] else { return nil }
            let title = definitionsById[metricId] ?? metricId
            return "\(title) \(formattedFloat(value))"
        }
        .joined(separator: " • ")
    }

    private func doubleDictionaryText(_ values: [String: Double]) -> String {
        guard !values.isEmpty else { return "none" }

        let definitionsById = Dictionary(
            uniqueKeysWithValues: (Self.defaultMetricDefinitions() + [Self.customViolinPerformanceMetricDefinition(sortOrder: 999)])
                .map { ($0.id, $0.title) }
        )

        return values.keys.sorted().compactMap { metricId in
            guard let value = values[metricId] else { return nil }
            let title = definitionsById[metricId] ?? metricId
            return "\(title) \(formattedDouble(value))"
        }
        .joined(separator: " • ")
    }

    private func componentScoreText(_ values: [String: Int]) -> String {
        guard !values.isEmpty else { return "none" }

        return values.keys.sorted().compactMap { title in
            guard let score = values[title] else { return nil }
            return "\(title) \(score)"
        }
        .joined(separator: " • ")
    }
}

private extension SQViewLabController {
    struct ScenarioDay {
        let offset: Int
        let morning: [String: Float]
        let evening: [String: Float]
    }

    struct WorkoutSpec {
        let offset: Int
        let activityType: HKWorkoutActivityType
        let performance: Float?
        let difficulty: Float?
        let startHour: Int
        let durationMinutes: Double
        let calories: Double
    }

    static func defaultSimulationPersonas() -> [SQViewLabSimulationPersona] {
        [
            .init(
                id: "balanced-builder",
                title: "Balanced Builder",
                subtitle: "A fairly consistent user with decent sleep, moderate training, and low vice load.",
                notes: [
                    "Use this as the baseline persona for healthy but realistic daily variation.",
                    "The hero should rotate between sleep, readiness, and moderate caution instead of over-firing habits."
                ],
                morningCompletionProbability: 0.96,
                eveningCompletionProbability: 0.90,
                restingHeartRateAvailability: 0.95,
                workoutProbability: 0.58,
                hardWorkoutProbability: 0.34,
                weekendViceMultiplier: 1.25,
                stressSpikeProbability: 0.12,
                sleepHoursRange: 6.9...8.2,
                sleepQualityRange: 6.9...8.5,
                energyRange: 6.2...8.2,
                moodRange: 6.0...8.0,
                mentalClarityRange: 6.1...8.3,
                motivationRange: 6.0...8.4,
                stressRange: 2.1...4.8,
                anxietyRange: 1.8...4.2,
                sorenessRange: 2.0...5.8,
                alcoholProbability: 0.18,
                alcoholRange: 0.8...2.8,
                caffeineProbability: 0.78,
                caffeineRange: 85...180,
                weedProbability: 0.05,
                weedRange: 0.5...1.5,
                nicotineProbability: 0.02,
                nicotineRange: 0.5...1.0,
                restingHeartRateBaselineRange: 53...59,
                activityMix: [
                    .init(activityType: .running, weight: 0.48),
                    .init(activityType: .cycling, weight: 0.22),
                    .init(activityType: .walking, weight: 0.12),
                    .init(activityType: .pickleball, weight: 0.18)
                ],
                includesCustomPerformerMetric: false
            ),
            .init(
                id: "custom-performer",
                title: "Custom Performer",
                subtitle: "A consistent user tracking Violin Performance as a custom outcome metric.",
                notes: [
                    "Use this to verify custom metric values flow through check-ins, feature snapshots, and shadow contributors.",
                    "Violin Performance should be affected by sleep, stress, and alcohol in the generated data, without enabling custom relationships yet."
                ],
                morningCompletionProbability: 0.96,
                eveningCompletionProbability: 0.92,
                restingHeartRateAvailability: 0.95,
                workoutProbability: 0.48,
                hardWorkoutProbability: 0.26,
                weekendViceMultiplier: 1.22,
                stressSpikeProbability: 0.14,
                sleepHoursRange: 6.8...8.3,
                sleepQualityRange: 6.7...8.5,
                energyRange: 6.1...8.1,
                moodRange: 6.0...8.0,
                mentalClarityRange: 6.0...8.3,
                motivationRange: 6.1...8.4,
                stressRange: 2.2...5.0,
                anxietyRange: 1.8...4.4,
                sorenessRange: 1.8...5.4,
                alcoholProbability: 0.18,
                alcoholRange: 0.8...2.8,
                caffeineProbability: 0.76,
                caffeineRange: 80...175,
                weedProbability: 0.04,
                weedRange: 0.5...1.4,
                nicotineProbability: 0.01,
                nicotineRange: 0.5...1.0,
                restingHeartRateBaselineRange: 53...60,
                activityMix: [
                    .init(activityType: .running, weight: 0.36),
                    .init(activityType: .cycling, weight: 0.18),
                    .init(activityType: .walking, weight: 0.18),
                    .init(activityType: .pickleball, weight: 0.28)
                ],
                includesCustomPerformerMetric: true
            ),
            .init(
                id: "vice-heavy",
                title: "Vice-Heavy User",
                subtitle: "A user with heavier alcohol/caffeine/weed patterns and softer sleep quality.",
                notes: [
                    "Helpful for checking whether harmful habit trends surface when they actually define the day.",
                    "Life Score should not stay unrealistically high when vice-heavy nights stack together."
                ],
                morningCompletionProbability: 0.90,
                eveningCompletionProbability: 0.78,
                restingHeartRateAvailability: 0.88,
                workoutProbability: 0.34,
                hardWorkoutProbability: 0.20,
                weekendViceMultiplier: 1.65,
                stressSpikeProbability: 0.20,
                sleepHoursRange: 5.7...7.2,
                sleepQualityRange: 4.6...7.0,
                energyRange: 4.8...7.1,
                moodRange: 4.6...7.0,
                mentalClarityRange: 4.4...6.8,
                motivationRange: 4.5...7.0,
                stressRange: 3.4...6.6,
                anxietyRange: 2.8...6.2,
                sorenessRange: 2.2...5.5,
                alcoholProbability: 0.44,
                alcoholRange: 1.5...4.8,
                caffeineProbability: 0.92,
                caffeineRange: 140...280,
                weedProbability: 0.30,
                weedRange: 1.0...3.8,
                nicotineProbability: 0.24,
                nicotineRange: 0.8...3.6,
                restingHeartRateBaselineRange: 58...66,
                activityMix: [
                    .init(activityType: .running, weight: 0.30),
                    .init(activityType: .cycling, weight: 0.18),
                    .init(activityType: .walking, weight: 0.24),
                    .init(activityType: .pickleball, weight: 0.28)
                ],
                includesCustomPerformerMetric: false
            ),
            .init(
                id: "training-block",
                title: "Hard Training Block",
                subtitle: "A user training frequently enough that strain, soreness, and readiness should matter a lot.",
                notes: [
                    "Use this to pressure-test push-vs-moderate actions.",
                    "Recovery-positive heroes should still downgrade when fatigue signals pile up."
                ],
                morningCompletionProbability: 0.97,
                eveningCompletionProbability: 0.93,
                restingHeartRateAvailability: 0.97,
                workoutProbability: 0.78,
                hardWorkoutProbability: 0.54,
                weekendViceMultiplier: 1.10,
                stressSpikeProbability: 0.10,
                sleepHoursRange: 6.6...7.9,
                sleepQualityRange: 6.3...8.0,
                energyRange: 5.8...8.0,
                moodRange: 5.8...7.8,
                mentalClarityRange: 5.8...7.9,
                motivationRange: 6.8...8.9,
                stressRange: 2.5...5.4,
                anxietyRange: 1.8...4.6,
                sorenessRange: 3.6...7.0,
                alcoholProbability: 0.08,
                alcoholRange: 0.5...1.6,
                caffeineProbability: 0.84,
                caffeineRange: 110...220,
                weedProbability: 0.04,
                weedRange: 0.5...1.0,
                nicotineProbability: 0.01,
                nicotineRange: 0.5...1.0,
                restingHeartRateBaselineRange: 52...60,
                activityMix: [
                    .init(activityType: .running, weight: 0.58),
                    .init(activityType: .cycling, weight: 0.22),
                    .init(activityType: .walking, weight: 0.05),
                    .init(activityType: .pickleball, weight: 0.15)
                ],
                includesCustomPerformerMetric: false
            ),
            .init(
                id: "stressed-inconsistent",
                title: "Stressed and Inconsistent",
                subtitle: "A user whose stress/anxiety and inconsistent recovery should shape the day more than habits alone.",
                notes: [
                    "Useful for validating stress/anxiety-led heroes and low-friction actions.",
                    "This should not collapse into caffeine on every bad day."
                ],
                morningCompletionProbability: 0.88,
                eveningCompletionProbability: 0.74,
                restingHeartRateAvailability: 0.84,
                workoutProbability: 0.31,
                hardWorkoutProbability: 0.18,
                weekendViceMultiplier: 1.20,
                stressSpikeProbability: 0.28,
                sleepHoursRange: 5.9...7.4,
                sleepQualityRange: 4.9...7.1,
                energyRange: 4.7...7.0,
                moodRange: 4.5...6.9,
                mentalClarityRange: 4.4...6.8,
                motivationRange: 4.8...7.1,
                stressRange: 4.4...7.4,
                anxietyRange: 4.0...7.0,
                sorenessRange: 2.6...5.8,
                alcoholProbability: 0.16,
                alcoholRange: 0.8...2.4,
                caffeineProbability: 0.86,
                caffeineRange: 150...290,
                weedProbability: 0.16,
                weedRange: 0.8...2.6,
                nicotineProbability: 0.12,
                nicotineRange: 0.8...2.8,
                restingHeartRateBaselineRange: 58...67,
                activityMix: [
                    .init(activityType: .running, weight: 0.24),
                    .init(activityType: .cycling, weight: 0.16),
                    .init(activityType: .walking, weight: 0.36),
                    .init(activityType: .pickleball, weight: 0.24)
                ],
                includesCustomPerformerMetric: false
            ),
            .init(
                id: "sparse-noisy",
                title: "Sparse and Noisy Logger",
                subtitle: "A user with inconsistent check-ins, mixed sports, and plenty of missing or contradictory signal.",
                notes: [
                    "This is for auditing not-enough-data and weird-state outputs over time.",
                    "The engine should stay honest instead of forcing false precision every day."
                ],
                morningCompletionProbability: 0.58,
                eveningCompletionProbability: 0.52,
                restingHeartRateAvailability: 0.62,
                workoutProbability: 0.42,
                hardWorkoutProbability: 0.30,
                weekendViceMultiplier: 1.35,
                stressSpikeProbability: 0.18,
                sleepHoursRange: 5.6...8.3,
                sleepQualityRange: 4.6...8.2,
                energyRange: 4.2...8.0,
                moodRange: 4.0...7.9,
                mentalClarityRange: 4.0...8.0,
                motivationRange: 4.2...8.3,
                stressRange: 2.4...7.2,
                anxietyRange: 2.0...6.8,
                sorenessRange: 1.8...6.8,
                alcoholProbability: 0.24,
                alcoholRange: 0.8...3.4,
                caffeineProbability: 0.74,
                caffeineRange: 90...250,
                weedProbability: 0.12,
                weedRange: 0.5...2.6,
                nicotineProbability: 0.08,
                nicotineRange: 0.5...2.2,
                restingHeartRateBaselineRange: 56...65,
                activityMix: [
                    .init(activityType: .running, weight: 0.25),
                    .init(activityType: .cycling, weight: 0.22),
                    .init(activityType: .walking, weight: 0.21),
                    .init(activityType: .pickleball, weight: 0.32)
                ],
                includesCustomPerformerMetric: false
            )
        ]
    }

    static func defaultScenarios() -> [Scenario] {
        let referenceDate = Calendar.current.startOfDay(for: .now)
        return [
            alignedSleepTailwindScenario(referenceDate: referenceDate),
            motivationPerformanceWindowScenario(referenceDate: referenceDate),
            strainCatchUpScenario(referenceDate: referenceDate),
            sorenessHeavyBlockScenario(referenceDate: referenceDate),
            heavyWeekendCarryoverScenario(referenceDate: referenceDate),
            energyMoodMismatchScenario(referenceDate: referenceDate),
            stressAnxietySpiralScenario(referenceDate: referenceDate),
            habitResetReboundScenario(referenceDate: referenceDate),
            sparseCalibratingScenario(referenceDate: referenceDate),
            mixedSportNoiseScenario(referenceDate: referenceDate)
        ]
    }

    static func alignedSleepTailwindScenario(referenceDate: Date) -> Scenario {
        let metricDefinitions = defaultMetricDefinitions()
        let days = (0..<14).map { offset -> ScenarioDay in
            let variant = Float(offset % 3)
            return .init(
                offset: offset,
                morning: [
                    SQMetricId.sleepHours: 7.5 + variant * 0.2,
                    SQMetricId.sleepQuality: 7.8 + variant * 0.4,
                    SQMetricId.energy: 7.1 + variant * 0.3,
                    SQMetricId.mood: 6.7 + variant * 0.2,
                    SQMetricId.mentalClarity: 7.2 + variant * 0.3,
                    SQMetricId.motivation: 7.0 + variant * 0.2,
                    SQMetricId.stress: 2.7 - variant * 0.2,
                    SQMetricId.anxiety: 2.2 - variant * 0.1,
                    SQMetricId.soreness: 3.4 - variant * 0.2
                ],
                evening: [
                    SQMetricId.alcohol: offset % 5 == 0 ? 1 : 0,
                    SQMetricId.caffeine: 110 + Float((offset % 2) * 20),
                    SQMetricId.weed: 0,
                    SQMetricId.nicotine: 0
                ]
            )
        }

        let workouts = makeWorkouts(
            referenceDate: referenceDate,
            specs: [
                .init(offset: 0, activityType: .running, performance: 8.5, difficulty: 6.7, startHour: 7, durationMinutes: 48, calories: 520),
                .init(offset: 2, activityType: .running, performance: 8.1, difficulty: 6.4, startHour: 7, durationMinutes: 42, calories: 470),
                .init(offset: 4, activityType: .cycling, performance: 7.9, difficulty: 6.0, startHour: 8, durationMinutes: 55, calories: 430),
                .init(offset: 7, activityType: .running, performance: 8.3, difficulty: 6.5, startHour: 7, durationMinutes: 50, calories: 510),
                .init(offset: 10, activityType: .running, performance: 8.0, difficulty: 6.1, startHour: 7, durationMinutes: 45, calories: 480)
            ]
        )

        return .init(
            id: "aligned-sleep-tailwind",
            domain: .lifeScoreInsights,
            title: "Aligned Sleep Tailwind",
            subtitle: "A strong, readable state where sleep and recovery should clearly lead the day.",
            tags: ["Expected", "Balanced"],
            notes: [
                "Check that the hero stays anchored to sleep and recovery instead of drifting toward habits.",
                "Recent changes should still surface behavior or training shifts without duplicating the chips."
            ],
            content: .lifeScoreInsights(
                .init(
                    referenceDate: referenceDate,
                    timeRange: .today,
                    metricDefinitions: metricDefinitions,
                    checkIns: makeCheckIns(referenceDate: referenceDate, days: days, metricDefinitions: metricDefinitions),
                    workouts: workouts,
                    sleepData: makeSleepDashboardData(score: 88),
                    restingHeartRateSummaries: makeRestingHeartRateSummaries(
                        referenceDate: referenceDate,
                        baseline: 57,
                        recentValues: [53, 54]
                    ),
                    isLoggedIn: true
                )
            )
        )
    }

    static func motivationPerformanceWindowScenario(referenceDate: Date) -> Scenario {
        let metricDefinitions = defaultMetricDefinitions()
        let days = (0..<14).map { offset -> ScenarioDay in
            let recentBoost: Float = offset <= 2 ? 0.9 : 0.3
            return .init(
                offset: offset,
                morning: [
                    SQMetricId.sleepHours: 7.3 + recentBoost * 0.2,
                    SQMetricId.sleepQuality: 7.4 + recentBoost * 0.3,
                    SQMetricId.energy: 7.2 + recentBoost * 0.4,
                    SQMetricId.mood: 6.8 + recentBoost * 0.2,
                    SQMetricId.mentalClarity: 7.5 + recentBoost * 0.3,
                    SQMetricId.motivation: 7.8 + recentBoost * 0.4,
                    SQMetricId.stress: 2.8,
                    SQMetricId.anxiety: 2.1,
                    SQMetricId.soreness: 3.0
                ],
                evening: [
                    SQMetricId.alcohol: 0,
                    SQMetricId.caffeine: 95,
                    SQMetricId.weed: 0,
                    SQMetricId.nicotine: 0
                ]
            )
        }

        let workouts = makeWorkouts(
            referenceDate: referenceDate,
            specs: [
                .init(offset: 0, activityType: .running, performance: 8.8, difficulty: 6.5, startHour: 7, durationMinutes: 46, calories: 500),
                .init(offset: 2, activityType: .running, performance: 8.4, difficulty: 6.2, startHour: 7, durationMinutes: 44, calories: 480),
                .init(offset: 5, activityType: .running, performance: 8.1, difficulty: 6.1, startHour: 7, durationMinutes: 42, calories: 465)
            ]
        )

        return .init(
            id: "motivation-performance-window",
            domain: .lifeScoreInsights,
            title: "Motivation and Performance Window",
            subtitle: "A state where motivation, clarity, and workouts should combine into a stronger training-oriented briefing.",
            tags: ["Training", "Opportunity"],
            notes: [
                "This should surface more than just sleep.",
                "Use it to tune workout-ready actions and performance-led briefings."
            ],
            content: .lifeScoreInsights(
                .init(
                    referenceDate: referenceDate,
                    timeRange: .today,
                    metricDefinitions: metricDefinitions,
                    checkIns: makeCheckIns(referenceDate: referenceDate, days: days, metricDefinitions: metricDefinitions),
                    workouts: workouts,
                    sleepData: makeSleepDashboardData(score: 86),
                    restingHeartRateSummaries: makeRestingHeartRateSummaries(
                        referenceDate: referenceDate,
                        baseline: 58,
                        recentValues: [54, 55]
                    ),
                    isLoggedIn: true
                )
            )
        )
    }

    static func strainCatchUpScenario(referenceDate: Date) -> Scenario {
        let metricDefinitions = defaultMetricDefinitions()
        let days = (0..<14).map { offset -> ScenarioDay in
            let recentDrop = offset <= 2 ? Float(2 - offset) : 0
            return .init(
                offset: offset,
                morning: [
                    SQMetricId.sleepHours: max(5.8, 7.1 - recentDrop * 0.5),
                    SQMetricId.sleepQuality: max(4.9, 7.0 - recentDrop * 0.8),
                    SQMetricId.energy: max(5.2, 6.8 - recentDrop * 0.5),
                    SQMetricId.mood: max(5.0, 6.5 - recentDrop * 0.4),
                    SQMetricId.mentalClarity: max(5.2, 7.0 - recentDrop * 0.6),
                    SQMetricId.motivation: max(4.8, 6.7 - recentDrop * 0.6),
                    SQMetricId.stress: min(8.5, 4.6 + recentDrop * 1.1),
                    SQMetricId.anxiety: min(7.5, 3.8 + recentDrop * 0.9),
                    SQMetricId.soreness: min(8.8, 4.2 + recentDrop * 1.3)
                ],
                evening: [
                    SQMetricId.alcohol: 0,
                    SQMetricId.caffeine: 140 + recentDrop * 80,
                    SQMetricId.weed: 0.4 + recentDrop * 0.2,
                    SQMetricId.nicotine: 0
                ]
            )
        }

        let workouts = makeWorkouts(
            referenceDate: referenceDate,
            specs: [
                .init(offset: 0, activityType: .running, performance: 6.0, difficulty: 8.1, startHour: 6, durationMinutes: 62, calories: 640),
                .init(offset: 1, activityType: .running, performance: 6.2, difficulty: 7.9, startHour: 6, durationMinutes: 58, calories: 610),
                .init(offset: 3, activityType: .running, performance: 7.3, difficulty: 7.1, startHour: 6, durationMinutes: 46, calories: 500),
                .init(offset: 6, activityType: .cycling, performance: 7.1, difficulty: 6.8, startHour: 7, durationMinutes: 52, calories: 440)
            ]
        )

        return .init(
            id: "strain-catching-up",
            domain: .lifeScoreInsights,
            title: "Strain Catching Up",
            subtitle: "Sleep debt and harder training should stack into a more cautionary briefing.",
            tags: ["Caution", "Training"],
            notes: [
                "The action should stay specific instead of sounding motivational.",
                "Use this to pressure test negative deltas, cautionary actions, and sleep-led drag states."
            ],
            content: .lifeScoreInsights(
                .init(
                    referenceDate: referenceDate,
                    timeRange: .today,
                    metricDefinitions: metricDefinitions,
                    checkIns: makeCheckIns(referenceDate: referenceDate, days: days, metricDefinitions: metricDefinitions),
                    workouts: workouts,
                    sleepData: makeSleepDashboardData(score: 63),
                    restingHeartRateSummaries: makeRestingHeartRateSummaries(
                        referenceDate: referenceDate,
                        baseline: 58,
                        recentValues: [65, 66]
                    ),
                    isLoggedIn: true
                )
            )
        )
    }

    static func sorenessHeavyBlockScenario(referenceDate: Date) -> Scenario {
        let metricDefinitions = defaultMetricDefinitions()
        let days = (0..<14).map { offset -> ScenarioDay in
            let blockPressure: Float = offset <= 3 ? 1.4 : 0.4
            return .init(
                offset: offset,
                morning: [
                    SQMetricId.sleepHours: 6.9,
                    SQMetricId.sleepQuality: 6.6,
                    SQMetricId.energy: 6.0 - blockPressure * 0.2,
                    SQMetricId.mood: 6.1 - blockPressure * 0.1,
                    SQMetricId.mentalClarity: 6.4 - blockPressure * 0.2,
                    SQMetricId.motivation: 6.5,
                    SQMetricId.stress: 4.8 + blockPressure * 0.3,
                    SQMetricId.anxiety: 3.4 + blockPressure * 0.2,
                    SQMetricId.soreness: 5.8 + blockPressure * 1.2
                ],
                evening: [
                    SQMetricId.alcohol: 0,
                    SQMetricId.caffeine: 130,
                    SQMetricId.weed: 0,
                    SQMetricId.nicotine: 0
                ]
            )
        }

        let workouts = makeWorkouts(
            referenceDate: referenceDate,
            specs: [
                .init(offset: 0, activityType: .running, performance: 6.3, difficulty: 8.2, startHour: 6, durationMinutes: 61, calories: 635),
                .init(offset: 1, activityType: .running, performance: 6.5, difficulty: 8.0, startHour: 6, durationMinutes: 56, calories: 590),
                .init(offset: 3, activityType: .running, performance: 6.8, difficulty: 7.6, startHour: 6, durationMinutes: 52, calories: 550),
                .init(offset: 6, activityType: .cycling, performance: 7.4, difficulty: 6.7, startHour: 7, durationMinutes: 48, calories: 420)
            ]
        )

        return .init(
            id: "soreness-heavy-block",
            domain: .lifeScoreInsights,
            title: "Soreness Heavy Block",
            subtitle: "A training block where soreness and workout difficulty should matter more than habits.",
            tags: ["Training", "Recovery"],
            notes: [
                "Use this to check soreness, workout difficulty, and cautionary workout actions.",
                "The outputs should feel training-specific rather than vice-led."
            ],
            content: .lifeScoreInsights(
                .init(
                    referenceDate: referenceDate,
                    timeRange: .today,
                    metricDefinitions: metricDefinitions,
                    checkIns: makeCheckIns(referenceDate: referenceDate, days: days, metricDefinitions: metricDefinitions),
                    workouts: workouts,
                    sleepData: makeSleepDashboardData(score: 71),
                    restingHeartRateSummaries: makeRestingHeartRateSummaries(
                        referenceDate: referenceDate,
                        baseline: 59,
                        recentValues: [64, 65]
                    ),
                    isLoggedIn: true
                )
            )
        )
    }

    static func heavyWeekendCarryoverScenario(referenceDate: Date) -> Scenario {
        let metricDefinitions = defaultMetricDefinitions()
        let days = (0..<14).map { offset -> ScenarioDay in
            let isWeekendCarryover = offset <= 2
            return .init(
                offset: offset,
                morning: [
                    SQMetricId.sleepHours: isWeekendCarryover ? 6.0 + Float(offset) * 0.1 : 7.2,
                    SQMetricId.sleepQuality: isWeekendCarryover ? 5.4 + Float(offset) * 0.3 : 7.1,
                    SQMetricId.energy: isWeekendCarryover ? 5.3 + Float(offset) * 0.2 : 6.8,
                    SQMetricId.mood: isWeekendCarryover ? 5.5 + Float(offset) * 0.2 : 6.6,
                    SQMetricId.mentalClarity: isWeekendCarryover ? 5.1 + Float(offset) * 0.3 : 7.0,
                    SQMetricId.motivation: isWeekendCarryover ? 5.3 + Float(offset) * 0.2 : 6.7,
                    SQMetricId.stress: isWeekendCarryover ? 6.6 - Float(offset) * 0.4 : 3.9,
                    SQMetricId.anxiety: isWeekendCarryover ? 5.7 - Float(offset) * 0.3 : 3.0,
                    SQMetricId.soreness: isWeekendCarryover ? 4.8 : 3.6
                ],
                evening: [
                    SQMetricId.alcohol: isWeekendCarryover ? 3.5 - Float(offset) : 0.5,
                    SQMetricId.caffeine: isWeekendCarryover ? 180 : 120,
                    SQMetricId.weed: isWeekendCarryover ? 2.2 - Float(offset) * 0.5 : 0.4,
                    SQMetricId.nicotine: isWeekendCarryover ? 1.0 : 0
                ]
            )
        }

        let workouts = makeWorkouts(
            referenceDate: referenceDate,
            specs: [
                .init(offset: 0, activityType: .running, performance: 6.4, difficulty: 7.0, startHour: 8, durationMinutes: 40, calories: 430),
                .init(offset: 4, activityType: .running, performance: 7.6, difficulty: 6.4, startHour: 7, durationMinutes: 44, calories: 470),
                .init(offset: 8, activityType: .walking, performance: 7.2, difficulty: 5.0, startHour: 18, durationMinutes: 36, calories: 230)
            ]
        )

        return .init(
            id: "heavy-weekend-carryover",
            domain: .lifeScoreInsights,
            title: "Heavy Weekend Carryover",
            subtitle: "Habit shifts should show up in recent changes while the hero stays outcome-focused.",
            tags: ["Habits", "Carryover"],
            notes: [
                "Recent behavior changes should explain the day without hijacking the hero chips.",
                "This is useful for tuning the line between habit-driven changes and outcome-driven drivers."
            ],
            content: .lifeScoreInsights(
                .init(
                    referenceDate: referenceDate,
                    timeRange: .today,
                    metricDefinitions: metricDefinitions,
                    checkIns: makeCheckIns(referenceDate: referenceDate, days: days, metricDefinitions: metricDefinitions),
                    workouts: workouts,
                    sleepData: makeSleepDashboardData(score: 60),
                    restingHeartRateSummaries: makeRestingHeartRateSummaries(
                        referenceDate: referenceDate,
                        baseline: 60,
                        recentValues: [66, 64]
                    ),
                    isLoggedIn: true
                )
            )
        )
    }

    static func energyMoodMismatchScenario(referenceDate: Date) -> Scenario {
        let metricDefinitions = defaultMetricDefinitions()
        let days = (0..<14).map { offset -> ScenarioDay in
            let recentLift: Float = offset <= 2 ? 0.8 : 0.2
            let sleepHours: Float = 7.0 + Float((offset + 1) % 2) * 0.2
            let sleepQuality: Float = 7.1 + Float((offset + 2) % 2) * 0.3
            let energy: Float = 6.8 + recentLift
            let mood: Float = offset <= 2 ? 5.5 : 6.4
            let mentalClarity: Float = offset <= 2 ? 7.3 : 6.5
            let motivation: Float = offset <= 2 ? 6.1 : 6.8
            let stress: Float = offset <= 2 ? 4.4 : 3.5
            let anxiety: Float = offset <= 2 ? 4.0 : 2.9
            let soreness: Float = 3.2
            let alcohol: Float = offset <= 2 ? 0 : 0.7
            let caffeine: Float = offset <= 2 ? 180 : 120

            return .init(
                offset: offset,
                morning: [
                    SQMetricId.sleepHours: sleepHours,
                    SQMetricId.sleepQuality: sleepQuality,
                    SQMetricId.energy: energy,
                    SQMetricId.mood: mood,
                    SQMetricId.mentalClarity: mentalClarity,
                    SQMetricId.motivation: motivation,
                    SQMetricId.stress: stress,
                    SQMetricId.anxiety: anxiety,
                    SQMetricId.soreness: soreness
                ],
                evening: [
                    SQMetricId.alcohol: alcohol,
                    SQMetricId.caffeine: caffeine,
                    SQMetricId.weed: 0,
                    SQMetricId.nicotine: 0
                ]
            )
        }

        let workouts = makeWorkouts(
            referenceDate: referenceDate,
            specs: [
                .init(offset: 0, activityType: .cycling, performance: 7.4, difficulty: 6.1, startHour: 17, durationMinutes: 55, calories: 450),
                .init(offset: 3, activityType: .running, performance: 7.0, difficulty: 6.3, startHour: 7, durationMinutes: 42, calories: 460)
            ]
        )
        let checkIns = makeCheckIns(
            referenceDate: referenceDate,
            days: days,
            metricDefinitions: metricDefinitions
        )
        let scenarioInput = SQHealthIntelligenceInput(
            referenceDate: referenceDate,
            timeRange: .today,
            metricDefinitions: metricDefinitions,
            checkIns: checkIns,
            workouts: workouts,
            sleepData: makeSleepDashboardData(score: 79),
            restingHeartRateSummaries: makeRestingHeartRateSummaries(
                referenceDate: referenceDate,
                baseline: 59,
                recentValues: [58, 57]
            ),
            isLoggedIn: true
        )

        return .init(
            id: "energy-mood-mismatch",
            domain: .lifeScoreInsights,
            title: "Energy Up, Mood Lagging",
            subtitle: "A deliberately weird state where some signals improve while others stay soft.",
            tags: ["Unexpected", "Mismatch"],
            notes: [
                "This should still feel coherent even when the user state is not cleanly positive or negative.",
                "Good for testing summary/action quality when no one theme is perfect."
            ],
            content: .lifeScoreInsights(scenarioInput)
        )
    }

    static func stressAnxietySpiralScenario(referenceDate: Date) -> Scenario {
        let metricDefinitions = defaultMetricDefinitions()
        let days = (0..<14).map { offset -> ScenarioDay in
            let recentSpike: Float = offset <= 2 ? 1.6 : 0.5
            return .init(
                offset: offset,
                morning: [
                    SQMetricId.sleepHours: 6.5 - recentSpike * 0.2,
                    SQMetricId.sleepQuality: 6.1 - recentSpike * 0.3,
                    SQMetricId.energy: 5.9 - recentSpike * 0.2,
                    SQMetricId.mood: 5.6 - recentSpike * 0.2,
                    SQMetricId.mentalClarity: 5.8 - recentSpike * 0.3,
                    SQMetricId.motivation: 5.7 - recentSpike * 0.2,
                    SQMetricId.stress: 5.6 + recentSpike * 1.0,
                    SQMetricId.anxiety: 5.0 + recentSpike * 0.9,
                    SQMetricId.soreness: 3.7
                ],
                evening: [
                    SQMetricId.alcohol: 0.6,
                    SQMetricId.caffeine: 175,
                    SQMetricId.weed: 1.4,
                    SQMetricId.nicotine: 1.6
                ]
            )
        }

        let workouts = makeWorkouts(
            referenceDate: referenceDate,
            specs: [
                .init(offset: 1, activityType: .walking, performance: 6.8, difficulty: 4.8, startHour: 18, durationMinutes: 34, calories: 210),
                .init(offset: 5, activityType: .running, performance: 7.1, difficulty: 6.2, startHour: 7, durationMinutes: 41, calories: 435)
            ]
        )

        return .init(
            id: "stress-anxiety-spiral",
            domain: .lifeScoreInsights,
            title: "Stress and Anxiety Spiral",
            subtitle: "A state where stress and anxiety should lead the day more clearly than sleep or vices alone.",
            tags: ["Mind & Body", "Unexpected"],
            notes: [
                "Use this to tune stress/anxiety actions and make sure they feel distinct from generic sleep actions.",
                "The hero should not collapse back into caffeine every time this state appears."
            ],
            content: .lifeScoreInsights(
                .init(
                    referenceDate: referenceDate,
                    timeRange: .today,
                    metricDefinitions: metricDefinitions,
                    checkIns: makeCheckIns(referenceDate: referenceDate, days: days, metricDefinitions: metricDefinitions),
                    workouts: workouts,
                    sleepData: makeSleepDashboardData(score: 67),
                    restingHeartRateSummaries: makeRestingHeartRateSummaries(
                        referenceDate: referenceDate,
                        baseline: 60,
                        recentValues: [67, 68]
                    ),
                    isLoggedIn: true
                )
            )
        )
    }

    static func habitResetReboundScenario(referenceDate: Date) -> Scenario {
        let metricDefinitions = defaultMetricDefinitions()
        let days = (0..<14).map { offset -> ScenarioDay in
            let recentImprovement: Float = offset <= 2 ? Float(2 - offset) : 0
            return .init(
                offset: offset,
                morning: [
                    SQMetricId.sleepHours: 6.8 + recentImprovement * 0.3,
                    SQMetricId.sleepQuality: 6.5 + recentImprovement * 0.5,
                    SQMetricId.energy: 6.0 + recentImprovement * 0.4,
                    SQMetricId.mood: 5.9 + recentImprovement * 0.4,
                    SQMetricId.mentalClarity: 6.1 + recentImprovement * 0.4,
                    SQMetricId.motivation: 6.0 + recentImprovement * 0.3,
                    SQMetricId.stress: 4.8 - recentImprovement * 0.4,
                    SQMetricId.anxiety: 4.2 - recentImprovement * 0.4,
                    SQMetricId.soreness: 3.4
                ],
                evening: [
                    SQMetricId.alcohol: 2.2 - recentImprovement * 0.8,
                    SQMetricId.caffeine: 180 - recentImprovement * 25,
                    SQMetricId.weed: 2.4 - recentImprovement * 0.8,
                    SQMetricId.nicotine: 1.8 - recentImprovement * 0.7
                ]
            )
        }

        let workouts = makeWorkouts(
            referenceDate: referenceDate,
            specs: [
                .init(offset: 0, activityType: .running, performance: 7.6, difficulty: 6.2, startHour: 7, durationMinutes: 43, calories: 455),
                .init(offset: 4, activityType: .running, performance: 7.1, difficulty: 6.3, startHour: 7, durationMinutes: 42, calories: 445)
            ]
        )

        return .init(
            id: "habit-reset-rebound",
            domain: .lifeScoreInsights,
            title: "Habit Reset Rebound",
            subtitle: "A scenario where reducing habits should start to unlock better recovery and mood.",
            tags: ["Habits", "Follow-Up"],
            notes: [
                "Use this to test follow-up insights and less vice-heavy hero states.",
                "The action should feel like a concrete next step, not a generic encouragement."
            ],
            content: .lifeScoreInsights(
                .init(
                    referenceDate: referenceDate,
                    timeRange: .today,
                    metricDefinitions: metricDefinitions,
                    checkIns: makeCheckIns(referenceDate: referenceDate, days: days, metricDefinitions: metricDefinitions),
                    workouts: workouts,
                    sleepData: makeSleepDashboardData(score: 80),
                    restingHeartRateSummaries: makeRestingHeartRateSummaries(
                        referenceDate: referenceDate,
                        baseline: 61,
                        recentValues: [56, 55]
                    ),
                    isLoggedIn: true
                )
            )
        )
    }

    static func sparseCalibratingScenario(referenceDate: Date) -> Scenario {
        let metricDefinitions = defaultMetricDefinitions()
        let days = [
            ScenarioDay(
                offset: 0,
                morning: [
                    SQMetricId.sleepHours: 7.1,
                    SQMetricId.sleepQuality: 7.0,
                    SQMetricId.energy: 6.5,
                    SQMetricId.mood: 6.4
                ],
                evening: [:]
            ),
            ScenarioDay(
                offset: 2,
                morning: [
                    SQMetricId.sleepHours: 6.8,
                    SQMetricId.sleepQuality: 6.7,
                    SQMetricId.energy: 6.1,
                    SQMetricId.mood: 6.0
                ],
                evening: [
                    SQMetricId.caffeine: 130
                ]
            )
        ]

        return .init(
            id: "sparse-calibrating",
            domain: .lifeScoreInsights,
            title: "Sparse / Calibrating",
            subtitle: "A low-data state where the engines should stay honest without looking broken.",
            tags: ["Sparse Data", "Empty State"],
            notes: [
                "This is mainly for checking not-enough-data behavior.",
                "The hero and detail surfaces should still feel deliberate even when the engine has little signal."
            ],
            content: .lifeScoreInsights(
                .init(
                    referenceDate: referenceDate,
                    timeRange: .today,
                    metricDefinitions: metricDefinitions,
                    checkIns: makeCheckIns(referenceDate: referenceDate, days: days, metricDefinitions: metricDefinitions),
                    workouts: [],
                    sleepData: makeSleepDashboardData(score: 70),
                    isLoggedIn: true
                )
            )
        )
    }

    static func mixedSportNoiseScenario(referenceDate: Date) -> Scenario {
        let metricDefinitions = defaultMetricDefinitions()
        let days = (0..<14).map { offset -> ScenarioDay in
            return .init(
                offset: offset,
                morning: [
                    SQMetricId.sleepHours: 7.0 + Float((offset + 1) % 3) * 0.1,
                    SQMetricId.sleepQuality: 6.8 + Float((offset + 2) % 3) * 0.2,
                    SQMetricId.energy: 6.6 + Float(offset % 2) * 0.2,
                    SQMetricId.mood: offset <= 1 ? 5.8 : 6.5,
                    SQMetricId.mentalClarity: 6.4 + Float(offset % 3) * 0.2,
                    SQMetricId.motivation: 6.6 + Float((offset + 1) % 2) * 0.2,
                    SQMetricId.stress: offset <= 1 ? 4.7 : 3.8,
                    SQMetricId.anxiety: offset <= 1 ? 4.0 : 3.1,
                    SQMetricId.soreness: 4.0 + Float(offset % 2) * 0.3
                ],
                evening: [
                    SQMetricId.alcohol: 0.4,
                    SQMetricId.caffeine: 120,
                    SQMetricId.weed: 0.3,
                    SQMetricId.nicotine: 0.2
                ]
            )
        }

        let workouts = makeWorkouts(
            referenceDate: referenceDate,
            specs: [
                .init(offset: 0, activityType: .pickleball, performance: 6.1, difficulty: 6.8, startHour: 18, durationMinutes: 70, calories: 500),
                .init(offset: 1, activityType: .cycling, performance: 7.9, difficulty: 6.3, startHour: 7, durationMinutes: 60, calories: 450),
                .init(offset: 3, activityType: .pickleball, performance: 6.3, difficulty: 6.6, startHour: 18, durationMinutes: 65, calories: 470),
                .init(offset: 5, activityType: .cycling, performance: 8.1, difficulty: 6.2, startHour: 7, durationMinutes: 58, calories: 440),
                .init(offset: 8, activityType: .running, performance: 7.2, difficulty: 6.4, startHour: 7, durationMinutes: 40, calories: 420)
            ]
        )

        return .init(
            id: "mixed-sport-noise",
            domain: .lifeScoreInsights,
            title: "Mixed-Sport Noise",
            subtitle: "A weird week where sport-specific performance does not tell one clean story.",
            tags: ["Unexpected", "Mixed Sport"],
            notes: [
                "Use this to make sure same-sport workout comparisons stay sane.",
                "Recent changes can surface sport-specific performance without forcing those exact labels into the hero."
            ],
            content: .lifeScoreInsights(
                .init(
                    referenceDate: referenceDate,
                    timeRange: .today,
                    metricDefinitions: metricDefinitions,
                    checkIns: makeCheckIns(referenceDate: referenceDate, days: days, metricDefinitions: metricDefinitions),
                    workouts: workouts,
                    sleepData: makeSleepDashboardData(score: 76),
                    restingHeartRateSummaries: makeRestingHeartRateSummaries(
                        referenceDate: referenceDate,
                        baseline: 60,
                        recentValues: [61, 60]
                    ),
                    isLoggedIn: true
                )
            )
        )
    }

    static func makeRestingHeartRateSummaries(
        referenceDate: Date,
        baseline: Double,
        recentValues: [Double],
        dayCount: Int = 14
    ) -> [SQHeartRateDailySummary] {
        let calendar = Calendar.current
        let startOfReferenceDay = calendar.startOfDay(for: referenceDate)

        return (0..<dayCount).map { offset in
            let dayDate = calendar.date(byAdding: .day, value: -offset, to: startOfReferenceDay) ?? startOfReferenceDay
            let value: Double
            if offset < recentValues.count {
                value = recentValues[offset]
            } else {
                let jitter = Double((offset % 3) - 1) * 0.6
                value = baseline + jitter
            }

            return SQHeartRateDailySummary(
                date: dayDate,
                average: value,
                minimum: nil,
                maximum: nil
            )
        }
        .sorted { $0.date < $1.date }
    }

    static func defaultMetricDefinitions(for persona: SQViewLabSimulationPersona) -> [SQMetricDefinition] {
        var definitions = defaultMetricDefinitions()
        if persona.includesCustomPerformerMetric,
           !definitions.contains(where: { $0.id == SQViewLabCustomMetricId.violinPerformance }) {
            definitions.append(customViolinPerformanceMetricDefinition(sortOrder: definitions.count))
        }
        return definitions
    }

    static func defaultMetricDefinitions() -> [SQMetricDefinition] {
        [
            .init(
                id: SQMetricId.mood,
                title: "Mood",
                kind: .scale,
                unit: .none,
                group: SQDefaultGroup.self_.rawValue,
                min: 0,
                max: 10,
                step: 1,
                isPreset: true,
                isEnabled: true,
                isDefault: true,
                sortOrder: 0,
                periods: [.morning, .evening],
                goalStyle: .buildUp,
                targetValue: 7
            ),
            .init(
                id: SQMetricId.mentalClarity,
                title: "Mental Clarity",
                kind: .scale,
                unit: .none,
                group: SQDefaultGroup.self_.rawValue,
                min: 0,
                max: 10,
                step: 1,
                isPreset: true,
                isEnabled: true,
                isDefault: true,
                sortOrder: 1,
                periods: [.morning, .evening],
                goalStyle: .buildUp,
                targetValue: 7
            ),
            .init(
                id: SQMetricId.energy,
                title: "Energy",
                kind: .scale,
                unit: .none,
                group: SQDefaultGroup.self_.rawValue,
                min: 0,
                max: 10,
                step: 1,
                isPreset: true,
                isEnabled: true,
                isDefault: true,
                sortOrder: 2,
                periods: [.morning, .evening],
                goalStyle: .buildUp,
                targetValue: 7,
                bodyBatteryEffect: .boostsWhenHigh
            ),
            .init(
                id: SQMetricId.motivation,
                title: "Motivation",
                kind: .scale,
                unit: .none,
                group: SQDefaultGroup.self_.rawValue,
                min: 0,
                max: 10,
                step: 1,
                isPreset: true,
                isEnabled: true,
                isDefault: true,
                sortOrder: 3,
                periods: [.morning, .evening],
                goalStyle: .buildUp,
                targetValue: 7
            ),
            .init(
                id: SQMetricId.stress,
                title: "Stress",
                kind: .scale,
                unit: .none,
                group: SQDefaultGroup.self_.rawValue,
                min: 0,
                max: 10,
                step: 1,
                isPreset: true,
                isEnabled: true,
                isDefault: true,
                sortOrder: 4,
                periods: [.morning, .evening],
                goalStyle: .keepLow,
                targetValue: 4,
                bodyBatteryEffect: .drainsWhenHigh
            ),
            .init(
                id: SQMetricId.anxiety,
                title: "Anxiety",
                kind: .scale,
                unit: .none,
                group: SQDefaultGroup.self_.rawValue,
                min: 0,
                max: 10,
                step: 1,
                isPreset: true,
                isEnabled: true,
                isDefault: true,
                sortOrder: 5,
                periods: [.morning, .evening],
                goalStyle: .keepLow,
                targetValue: 3,
                bodyBatteryEffect: .drainsWhenHigh
            ),
            .init(
                id: SQMetricId.soreness,
                title: "Soreness",
                kind: .scale,
                unit: .none,
                group: SQDefaultGroup.self_.rawValue,
                min: 0,
                max: 10,
                step: 1,
                isPreset: true,
                isEnabled: true,
                isDefault: true,
                sortOrder: 6,
                periods: [.morning, .evening],
                goalStyle: .keepLow,
                targetValue: 4,
                bodyBatteryEffect: .drainsWhenHigh
            ),
            .init(
                id: SQMetricId.sleepQuality,
                title: "Sleep Quality",
                kind: .scale,
                unit: .none,
                group: SQDefaultGroup.sleep.rawValue,
                min: 0,
                max: 10,
                step: 1,
                isPreset: true,
                isEnabled: true,
                isDefault: false,
                sortOrder: 7,
                periods: [.morning, .evening],
                isSingleDailyValue: true,
                goalStyle: .buildUp,
                targetValue: 7
            ),
            .init(
                id: SQMetricId.sleepHours,
                title: "Sleep Duration",
                kind: .number,
                unit: .hours,
                group: SQDefaultGroup.sleep.rawValue,
                min: 0,
                max: 24,
                step: 0.1,
                isPreset: true,
                isEnabled: true,
                isDefault: false,
                sortOrder: 8,
                periods: [.morning, .evening],
                isSingleDailyValue: true,
                goalStyle: .buildUp,
                targetValue: 7
            ),
            .init(
                id: SQMetricId.alcohol,
                title: "Alcohol",
                kind: .number,
                unit: .count,
                group: SQDefaultGroup.vices.rawValue,
                min: 0,
                max: 10,
                step: 0.1,
                isPreset: true,
                isEnabled: true,
                isDefault: true,
                sortOrder: 9,
                periods: [.morning, .evening],
                isSingleDailyValue: true,
                goalStyle: .avoidIt,
                bodyBatteryEffect: .drainsWhenHigh,
                scaleQuantityMapping: .init(quantityUnit: .count, maxQuantityValue: 10, quantityLabelOverride: "drink count")
            ),
            .init(
                id: SQMetricId.caffeine,
                title: "Caffeine",
                kind: .number,
                unit: .milligrams,
                group: SQDefaultGroup.vices.rawValue,
                min: 0,
                max: 1000,
                step: 0.1,
                isPreset: true,
                isEnabled: true,
                isDefault: true,
                sortOrder: 10,
                periods: [.morning, .evening],
                isSingleDailyValue: true,
                goalStyle: .keepLow,
                targetValue: 150,
                bodyBatteryEffect: .drainsWhenHigh,
                scaleQuantityMapping: .init(quantityUnit: .milligrams, maxQuantityValue: 200)
            ),
            .init(
                id: SQMetricId.weed,
                title: "Weed",
                kind: .number,
                unit: .count,
                group: SQDefaultGroup.vices.rawValue,
                min: 0,
                max: 10,
                step: 0.1,
                isPreset: true,
                isEnabled: true,
                isDefault: false,
                sortOrder: 11,
                periods: [.morning, .evening],
                isSingleDailyValue: true,
                goalStyle: .avoidIt,
                bodyBatteryEffect: .drainsWhenHigh
            ),
            .init(
                id: SQMetricId.nicotine,
                title: "Nicotine",
                kind: .number,
                unit: .count,
                group: SQDefaultGroup.vices.rawValue,
                min: 0,
                max: 10,
                step: 0.1,
                isPreset: true,
                isEnabled: true,
                isDefault: false,
                sortOrder: 12,
                periods: [.morning, .evening],
                isSingleDailyValue: true,
                goalStyle: .avoidIt,
                bodyBatteryEffect: .drainsWhenHigh
            )
        ]
    }

    static func customViolinPerformanceMetricDefinition(sortOrder: Int) -> SQMetricDefinition {
        .init(
            id: SQViewLabCustomMetricId.violinPerformance,
            title: "Violin Performance",
            kind: .scale,
            unit: .none,
            group: "Performance",
            min: 0,
            max: 10,
            step: 1,
            isPreset: false,
            isEnabled: true,
            isDefault: false,
            sortOrder: sortOrder,
            periods: [.evening],
            goalStyle: .buildUp,
            targetValue: 8,
            signalRole: .outcome,
            lifeScoreImpact: .light,
            insightMode: .exploratoryRelationships,
            sensitivity: .normal
        )
    }

    static func makeCheckIns(
        referenceDate: Date,
        days: [ScenarioDay],
        metricDefinitions: [SQMetricDefinition]
    ) -> [SQDailyCheckInStats] {
        let definitionsById = Dictionary(uniqueKeysWithValues: metricDefinitions.map { ($0.id, $0) })
        let calendar = Calendar.current
        let startOfReferenceDay = calendar.startOfDay(for: referenceDate)

        return days.flatMap { day in
            let targetDay = calendar.date(byAdding: .day, value: -day.offset, to: startOfReferenceDay) ?? startOfReferenceDay
            var entries = [SQDailyCheckInStats]()

            if !day.morning.isEmpty {
                let morningDate = calendar.date(byAdding: .hour, value: 8, to: targetDay) ?? targetDay
                entries.append(
                    makeCheckIn(
                        date: morningDate,
                        period: .morning,
                        values: day.morning,
                        definitionsById: definitionsById
                    )
                )
            }

            if !day.evening.isEmpty {
                let eveningDate = calendar.date(byAdding: .hour, value: 20, to: targetDay) ?? targetDay
                entries.append(
                    makeCheckIn(
                        date: eveningDate,
                        period: .evening,
                        values: day.evening,
                        definitionsById: definitionsById
                    )
                )
            }

            return entries
        }
        .sorted { $0.date < $1.date }
    }

    static func makeCheckIn(
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

    static func makeWorkouts(
        referenceDate: Date,
        specs: [WorkoutSpec]
    ) -> [SQWorkoutSessionable] {
        let calendar = Calendar.current
        let startOfReferenceDay = calendar.startOfDay(for: referenceDate)

        return specs.map { spec in
            let targetDay = calendar.date(byAdding: .day, value: -spec.offset, to: startOfReferenceDay) ?? startOfReferenceDay
            let startDate = calendar.date(byAdding: .hour, value: spec.startHour, to: targetDay) ?? targetDay
            let endDate = startDate.addingTimeInterval(spec.durationMinutes * 60)

            let manualWorkout = SQManualWorkout(
                sourceId: "lab-\(spec.activityType.rawValue)-\(spec.offset)-\(spec.startHour)",
                activityType: spec.activityType,
                device: SQWorkoutDevice(name: "View Lab"),
                startDate: startDate,
                endDate: endDate,
                activeDuration: spec.durationMinutes * 60,
                averageHeartRate: 142,
                totalCalories: spec.calories,
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
                ratingUserPerformance: spec.performance,
                ratingDifficulty: spec.difficulty,
                temperature: nil
            )
            return session
        }
    }

    static func makeSleepDashboardData(score: Double) -> SQSleepDashboardData {
        let clamped = max(0, min(100, score))
        let breakdown = SQSleepScoreBreakdown(
            durationScore: min(clamped * 0.40, SQSleepScoreBreakdown.maxDurationScore),
            efficiencyScore: min(clamped * 0.25, SQSleepScoreBreakdown.maxEfficiencyScore),
            fragmentationScore: min(clamped * 0.20, SQSleepScoreBreakdown.maxFragmentationScore),
            architectureScore: min(clamped * 0.15, SQSleepScoreBreakdown.maxArchitectureScore)
        )

        return .init(
            currentNights: [],
            priorNights: [],
            latestNight: nil,
            averageScore: breakdown,
            phaseAggregates: []
        )
    }
}

//
//  SQLifeScoreViewModel.swift
//  BeastFitness
//

import Foundation

enum SQLifeScoreSignalEffect: Hashable {
    case positive
    case negative
    case neutral

    var color: SQColor {
        switch self {
        case .positive:
            return .dashboardGlowMint
        case .negative:
            return .colorErrorRed
        case .neutral:
            return .dashboardTrendWarm
        }
    }
}

struct SQLifeScoreDetailItem: Identifiable {
    let id: String
    let title: String
    let valueText: String
    let summary: String
    let effect: SQLifeScoreSignalEffect
}

struct SQLifeScoreComponent: Identifiable {
    let id: String
    let title: String
    let score: Int
    let summary: String
    let weight: Double
    let detailItems: [SQLifeScoreDetailItem]
}

struct SQLifeScoreMetricContributor: Identifiable, Hashable {
    let metricId: String
    let title: String
    let role: SQMetricSignalRole
    let impact: SQMetricLifeScoreImpact
    let source: SQInsightSignalSource
    let utilityScore: Double?
    let contributionPoints: Double
    let effect: SQLifeScoreSignalEffect
    let componentId: String
    let isCustom: Bool
    let sensitivity: SQMetricSensitivity

    var id: String { metricId }
}

struct SQLifeScoreShadowMetricContributionResult: Hashable {
    let diagnosticContributors: [SQLifeScoreMetricContributor]
    let incrementalContributors: [SQLifeScoreMetricContributor]
    let customMetricContributionTotal: Double
    let sensitiveMetricContributionTotal: Double
    let behaviorMetricContributionTotal: Double

    var diagnosticContributionTotal: Double {
        diagnosticContributors.reduce(0) { $0 + $1.contributionPoints }
    }

    var incrementalContributionTotal: Double {
        incrementalContributors.reduce(0) { $0 + $1.contributionPoints }
    }
}

struct SQLifeScoreShadowMetricContributorBuilder {
    private let semanticResolver = SQMetricSemanticResolver()

    func buildContributors(
        from snapshot: SQInsightFeatureSnapshot?,
        metricDefinitions: [SQMetricDefinition]
    ) -> SQLifeScoreShadowMetricContributionResult {
        guard let snapshot else {
            return .init(
                diagnosticContributors: [],
                incrementalContributors: [],
                customMetricContributionTotal: 0,
                sensitiveMetricContributionTotal: 0,
                behaviorMetricContributionTotal: 0
            )
        }

        let definitionsById = Dictionary(uniqueKeysWithValues: metricDefinitions.map { ($0.id, $0) })
        let diagnosticContributors = snapshot.signalFeatures.values.compactMap { feature -> SQLifeScoreMetricContributor? in
            guard let definition = definitionsById[feature.signalId],
                  let utilityScore = feature.goalUtilityScore else {
                return nil
            }

            let impact = effectiveImpact(for: definition)
            guard impact != .none else { return nil }

            let maxPoints = maxContributionPoints(
                impact: impact,
                isCustom: !definition.isPreset
            )
            let contribution = rawContributionPoints(
                utilityScore: utilityScore,
                maxPoints: maxPoints,
                goalStyle: definition.goalStyle
            )

            guard abs(contribution) >= 0.05 else { return nil }

            return .init(
                metricId: feature.signalId,
                title: feature.title,
                role: feature.signalRole,
                impact: impact,
                source: feature.source,
                utilityScore: utilityScore,
                contributionPoints: contribution,
                effect: effect(for: contribution),
                componentId: componentId(for: feature.signalRole),
                isCustom: !definition.isPreset,
                sensitivity: feature.sensitivity
            )
        }

        let rawIncrementalContributors = diagnosticContributors.compactMap { contributor -> SQLifeScoreMetricContributor? in
            guard let definition = definitionsById[contributor.metricId],
                  isIncrementalScoreEligible(definition: definition, contributor: contributor) else {
                return nil
            }

            let incrementalContribution = incrementalContributionPoints(
                contribution: contributor.contributionPoints,
                definition: definition
            )
            guard abs(incrementalContribution) >= 0.05 else { return nil }
            return contributor.replacingContribution(incrementalContribution)
        }

        let singleCustomCapped = rawIncrementalContributors.map { contributor in
            guard contributor.isCustom else { return contributor }
            return contributor.replacingContribution(
                clamp(contributor.contributionPoints, min: -3, max: 3)
            )
        }

        let customCapped = capTotalContribution(
            singleCustomCapped,
            cap: 10,
            matching: { $0.isCustom }
        )
        let sensitiveCapped = capTotalContribution(
            customCapped,
            cap: 6,
            matching: { $0.sensitivity == .sensitive || $0.sensitivity == .medicationLike }
        )

        return .init(
            diagnosticContributors: diagnosticContributors.sorted { abs($0.contributionPoints) > abs($1.contributionPoints) },
            incrementalContributors: sensitiveCapped.sorted { abs($0.contributionPoints) > abs($1.contributionPoints) },
            customMetricContributionTotal: sensitiveCapped.filter(\.isCustom).reduce(0) { $0 + $1.contributionPoints },
            sensitiveMetricContributionTotal: sensitiveCapped
                .filter { $0.sensitivity == .sensitive || $0.sensitivity == .medicationLike }
                .reduce(0) { $0 + $1.contributionPoints },
            behaviorMetricContributionTotal: sensitiveCapped
                .filter { $0.role == .behavior }
                .reduce(0) { $0 + $1.contributionPoints }
        )
    }

    private func effectiveImpact(for definition: SQMetricDefinition) -> SQMetricLifeScoreImpact {
        let resolvedImpact = semanticResolver.lifeScoreImpact(for: definition)
        guard resolvedImpact == .automatic || resolvedImpact == .unknown else {
            return resolvedImpact
        }

        guard definition.isPreset else { return .none }

        switch semanticResolver.signalRole(for: definition) {
        case .behavior:
            return .light
        case .outcome, .symptom, .bodyStat:
            return .standard
        case .context, .automatic, .unknown:
            return .none
        }
    }

    private func isIncrementalScoreEligible(
        definition: SQMetricDefinition,
        contributor: SQLifeScoreMetricContributor
    ) -> Bool {
        if !definition.isPreset {
            return contributor.impact == .light || contributor.impact == .standard
        }

        // Automatic preset metrics are already represented by the current Life Score components.
        return definition.lifeScoreImpact == .light || definition.lifeScoreImpact == .standard
    }

    private func incrementalContributionPoints(
        contribution: Double,
        definition: SQMetricDefinition
    ) -> Double {
        guard definition.goalStyle == .avoidIt else { return contribution }

        // Avoid metrics should drag when present, but absence should not stack repeated bonuses.
        return min(0, contribution)
    }

    private func maxContributionPoints(
        impact: SQMetricLifeScoreImpact,
        isCustom: Bool
    ) -> Double {
        switch impact {
        case .light:
            return 2
        case .standard:
            return isCustom ? 3 : 2.5
        case .automatic:
            return isCustom ? 0 : 2
        case .none, .unknown:
            return 0
        }
    }

    private func rawContributionPoints(
        utilityScore: Double,
        maxPoints: Double,
        goalStyle: SQMetricGoalStyle
    ) -> Double {
        let neutralUtility = 70.0
        let bonusCap = goalStyle == .avoidIt ? maxPoints * 0.25 : maxPoints
        let dragCap = goalStyle == .avoidIt ? maxPoints * 1.2 : maxPoints

        if utilityScore >= neutralUtility {
            return ((utilityScore - neutralUtility) / (100 - neutralUtility)) * bonusCap
        }

        return -((neutralUtility - utilityScore) / neutralUtility) * dragCap
    }

    private func componentId(for role: SQMetricSignalRole) -> String {
        switch role {
        case .behavior:
            return "habits"
        case .outcome:
            return "personalState"
        case .symptom, .bodyStat:
            return "recovery"
        case .context:
            return "context"
        case .automatic, .unknown:
            return "metrics"
        }
    }

    private func effect(for contribution: Double) -> SQLifeScoreSignalEffect {
        if contribution > 0.2 {
            return .positive
        }

        if contribution < -0.2 {
            return .negative
        }

        return .neutral
    }

    private func capTotalContribution(
        _ contributors: [SQLifeScoreMetricContributor],
        cap: Double,
        matching isIncluded: (SQLifeScoreMetricContributor) -> Bool
    ) -> [SQLifeScoreMetricContributor] {
        let includedTotal = contributors
            .filter(isIncluded)
            .reduce(0) { $0 + $1.contributionPoints }
        let magnitude = abs(includedTotal)
        guard magnitude > cap, magnitude > 0 else { return contributors }

        let scale = cap / magnitude
        return contributors.map { contributor in
            guard isIncluded(contributor) else { return contributor }
            return contributor.replacingContribution(contributor.contributionPoints * scale)
        }
    }

    private func clamp(_ value: Double, min minimum: Double, max maximum: Double) -> Double {
        Swift.max(minimum, Swift.min(maximum, value))
    }
}

private extension SQLifeScoreMetricContributor {
    func replacingContribution(_ contributionPoints: Double) -> SQLifeScoreMetricContributor {
        .init(
            metricId: metricId,
            title: title,
            role: role,
            impact: impact,
            source: source,
            utilityScore: utilityScore,
            contributionPoints: contributionPoints,
            effect: contributionPoints > 0.2 ? .positive : (contributionPoints < -0.2 ? .negative : .neutral),
            componentId: componentId,
            isCustom: isCustom,
            sensitivity: sensitivity
        )
    }
}

enum SQLifeScoreState {
    case strong
    case primed
    case balanced
    case rebounding
    case slightlyOff
    case dipping
    case underPressure
    case calibrating

    var title: String {
        switch self {
        case .strong:
            return "Strong"
        case .primed:
            return "Primed"
        case .balanced:
            return "Balanced"
        case .rebounding:
            return "Rebounding"
        case .slightlyOff:
            return "Slightly Off"
        case .dipping:
            return "Dipping"
        case .underPressure:
            return "Under Pressure"
        case .calibrating:
            return "Calibrating"
        }
    }

    var primaryColor: SQColor {
        switch self {
        case .strong:
            return .dashboardGlowMint
        case .primed, .balanced, .rebounding:
            return .dashboardGlowBlue
        case .slightlyOff, .dipping:
            return .dashboardTrendWarm
        case .underPressure:
            return .colorErrorRed
        case .calibrating:
            return .accentNeutral4
        }
    }

    var secondaryColor: SQColor {
        switch self {
        case .strong, .primed, .rebounding:
            return .dashboardGlowBlue
        case .balanced:
            return .dashboardGlowMint
        case .slightlyOff:
            return .accentNeutral2
        case .dipping:
            return .colorErrorRed
        case .underPressure:
            return .dashboardTrendWarm
        case .calibrating:
            return .textSecondary
        }
    }

    var summary: String {
        switch self {
        case .strong:
            return "You're in a strong position today."
        case .primed:
            return "You're primed for a solid day."
        case .balanced:
            return "Things look steady today."
        case .rebounding:
            return "You're trending in the right direction."
        case .slightlyOff:
            return "One or two things are slightly off today."
        case .dipping:
            return "Things are slipping compared to yesterday."
        case .underPressure:
            return "The day is working against you a bit."
        case .calibrating:
            return "There isn't enough signal yet to make this feel fully personalized."
        }
    }
}

struct SQLifeScoreViewModel {
    let score: Int?
    let scoreDeltaFromPreviousDay: Int?
    let state: SQLifeScoreState
    let subtitle: String
    let refinementPromptText: String?
    let components: [SQLifeScoreComponent]
    let headlineText: String?
    let primaryInsight: SQInsight?
    let drivers: [SQInsightDriver]
    let changes: [SQInsightChange]
    let actions: [SQInsightAction]
    let availableWeight: Double

    static let mock = SQLifeScoreViewModel(
        score: 76,
        scoreDeltaFromPreviousDay: 2,
        state: .balanced,
        subtitle: "A lightweight read on how aligned your recovery, habits, and training look right now.",
        refinementPromptText: "Complete your morning check-in to refine today's score.",
        components: [],
        headlineText: nil,
        primaryInsight: .init(
            id: "mock-primary-insight",
            title: "Sleep is helping, but strain is starting to build",
            summary: "Sleep is helping, but strain is starting to build.",
            evidenceText: "",
            actionText: "Keep effort moderate today.",
            driverText: "Sleep",
            outcomeText: "Recovery",
            deltaText: "+0.8",
            category: .recovery,
            confidence: .medium,
            effect: .positive,
            sampleCount: 12,
            rankingScore: 12
        ),
        drivers: [],
        changes: [],
        actions: [],
        availableWeight: 100
    )

    var scoreText: String {
        if let score {
            return "\(score)"
        }

        return "?"
    }

    var titleText: String {
        if let score {
            return "Life Score \(score)"
        }

        return "Life Score"
    }

    var accessibilityLabel: String {
        if let score {
            return "Life Score \(score), \(state.title)"
        }

        return "Life Score, \(state.title)"
    }

    var supportiveDrivers: [SQInsightDriver] {
        drivers.filter { $0.direction == .supportive }
    }

    var dragDrivers: [SQInsightDriver] {
        drivers.filter { $0.direction == .drag }
    }

    var scoreDeltaText: String? {
        guard let scoreDeltaFromPreviousDay, scoreDeltaFromPreviousDay != 0 else { return nil }
        let direction = scoreDeltaFromPreviousDay > 0 ? "↑" : "↓"
        let signedValue = scoreDeltaFromPreviousDay > 0 ? "+\(scoreDeltaFromPreviousDay)" : "\(scoreDeltaFromPreviousDay)"
        return "\(direction) \(signedValue) vs yesterday"
    }
}

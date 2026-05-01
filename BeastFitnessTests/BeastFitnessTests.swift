//
//  BeastFitnessTests.swift
//  BeastFitnessTests
//
//  Created by Patrick Doyle on 9/25/24.
//

import XCTest
@testable import BeastFitness

final class BeastFitnessTests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testExample() throws {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct results.
        // Any test you write for XCTest can be annotated as throws and async.
        // Mark your test throws to produce an unexpected failure when your test encounters an uncaught error.
        // Mark your test async to allow awaiting for asynchronous code to complete. Check the results with assertions afterwards.
    }

    func testPerformanceExample() throws {
        // This is an example of a performance test case.
        self.measure {
            // Put the code you want to measure the time of here.
        }
    }

}

@MainActor
final class SQViewLabCalibrationTests: XCTestCase {
    private let outputDirectory = URL(fileURLWithPath: "/tmp/lifeiq_calibration", isDirectory: true)

    func testGenerateAllPersonaCalibrationReports() throws {
        let controller = SQViewLabController()
        let referenceDate = Self.referenceDate()
        let seed = 41
        let dayCount = SQViewLabSimulationDayCount.ninety
        let personas = SQViewLabController.calibrationSimulationPersonas()
        let reports = personas.map { persona in
            controller.simulationReport(
                for: .init(
                    persona: persona,
                    dayCount: dayCount,
                    seed: seed,
                    referenceDate: referenceDate,
                    metricDefinitions: SQViewLabController.calibrationMetricDefinitions(for: persona)
                )
            )
        }

        let markdown = controller.calibrationSimulationMarkdown(for: reports)
        let summary = Self.summary(
            reports: reports,
            seed: seed,
            dayCount: dayCount.rawValue,
            referenceDate: referenceDate
        )
        let scorecard = Self.scorecard(
            reports: reports,
            summary: summary
        )

        try FileManager.default.createDirectory(
            at: outputDirectory,
            withIntermediateDirectories: true
        )

        try markdown.write(
            to: outputDirectory.appendingPathComponent("simAllPersonas.md"),
            atomically: true,
            encoding: .utf8
        )
        try Self.writeJSON(
            summary,
            to: outputDirectory.appendingPathComponent("simAllPersonas.json")
        )
        try Self.writeJSON(
            scorecard,
            to: outputDirectory.appendingPathComponent("calibrationScorecard.json")
        )
        try Self.iterationLog(scorecard: scorecard).write(
            to: outputDirectory.appendingPathComponent("iterationLog.md"),
            atomically: true,
            encoding: .utf8
        )
    }

    private static func referenceDate() -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Phoenix") ?? .current
        return calendar.date(
            from: .init(
                timeZone: calendar.timeZone,
                year: 2026,
                month: 4,
                day: 30,
                hour: 12
            )
        ) ?? Date(timeIntervalSince1970: 1_777_573_600)
    }

    private static func summary(
        reports: [SQViewLabSimulationReport],
        seed: Int,
        dayCount: Int,
        referenceDate: Date
    ) -> CalibrationSummary {
        .init(
            generatedAt: Date(),
            seed: seed,
            dayCount: dayCount,
            referenceDate: referenceDate,
            personas: reports.map(PersonaCalibrationSummary.init(report:))
        )
    }

    private static func scorecard(
        reports: [SQViewLabSimulationReport],
        summary: CalibrationSummary
    ) -> CalibrationScorecard {
        var gates = [CalibrationGate]()
        let summariesById = Dictionary(uniqueKeysWithValues: summary.personas.map { ($0.id, $0) })
        let targetRanges: [String: ClosedRange<Double>] = [
            "balanced-builder": 83...88,
            "custom-performer": 83...88,
            "healthy-consistent": 86...93,
            "healthy-sparse": 82...90,
            "vice-heavy": 58...70,
            "training-block": 78...86,
            "stressed-inconsistent": 60...74,
            "sparse-noisy": 62...75
        ]

        for (personaId, range) in targetRanges.sorted(by: { $0.key < $1.key }) {
            let summary = summariesById[personaId]
            let value = summary?.v2Average
            let distance = value.map { distanceOutside($0, range: range) }
            let passed = distance.map { $0 == 0 } ?? false
            let severity: CalibrationGateSeverity = (distance ?? 3) > 2 ? .hard : .soft
            let toleranceLabel: String
            if let distance {
                if distance == 0 {
                    toleranceLabel = "in target"
                } else if distance <= 1 {
                    toleranceLabel = "near miss"
                } else if distance <= 2 {
                    toleranceLabel = "outside by \(formatted(distance))"
                } else {
                    toleranceLabel = "hard miss by \(formatted(distance))"
                }
            } else {
                toleranceLabel = "missing"
            }
            gates.append(
                .init(
                    id: "v2Average.\(personaId)",
                    title: "\(summary?.persona ?? personaId) V2 average in \(formatted(range))",
                    severity: severity,
                    passed: passed,
                    details: value.map { "actual \(formatted($0)); \(toleranceLabel)" } ?? "missing persona"
                )
            )
        }

        let topCurrentDriverCounts = countTopValues(summary.personas.map(\.topCurrentDriver))
        let topRecommendationCounts = countTopValues(summary.personas.map(\.topRecommendation))
        let topV2HealthDriverCounts = countTopValues(summary.personas.map(\.topV2HealthDriver))

        gates.append(sharedTopValueGate(
            id: "sameTopCurrentDriverAcross4PlusPersonas",
            title: "No same top current driver across 4+ personas",
            counts: topCurrentDriverCounts,
            severity: .hard
        ))
        gates.append(sharedTopValueGate(
            id: "sameTopRecommendationAcross4PlusPersonas",
            title: "No same top recommendation across 4+ personas",
            counts: topRecommendationCounts,
            severity: .hard,
            contextPass: { value, count in
                recommendationGroupAwarePass(
                    recommendation: value,
                    count: count,
                    personas: summary.personas
                )
            }
        ))
        gates.append(sharedTopValueGate(
            id: "sameTopV2HealthDriverAcross4PlusPersonas",
            title: "V2 top health driver explanatory diversity",
            counts: topV2HealthDriverCounts,
            severity: .soft
        ))

        for persona in summary.personas {
            gates.append(
                .init(
                    id: "pressureLeakage.\(persona.id)",
                    title: "\(persona.persona) pressure positive leakage <=3",
                    severity: persona.positiveLeakage > 5 ? .hard : .soft,
                    passed: persona.positiveLeakage <= 3,
                    details: "actual \(persona.positiveLeakage)"
                )
            )

            if let topInsightPercentage = persona.topSurfacedInsightPercentage {
                gates.append(
                    .init(
                        id: "topInsightConcentration.\(persona.id)",
                        title: "\(persona.persona) top exact insight <=20%",
                        severity: .soft,
                        passed: topInsightPercentage <= 20,
                        details: "\(persona.topSurfacedInsight ?? "None") at \(formatted(topInsightPercentage))%"
                    )
                )
            }

            if let topRelationshipPercentage = persona.topRelationshipFamilyPercentage {
                let enoughRelationshipVolume = persona.totalRelationshipFamilyCount >= 30
                    && persona.topRelationshipFamilyCount >= 8
                let lowDataGuidanceActive = persona.topRecommendation == "logCoreSignals"
                let concentrationIsAcceptable = topRelationshipPercentage <= 20
                    || !enoughRelationshipVolume
                    || lowDataGuidanceActive
                gates.append(
                    .init(
                        id: "relationshipFamilyConcentration.\(persona.id)",
                        title: "\(persona.persona) relationship concentration context-aware",
                        severity: .soft,
                        passed: concentrationIsAcceptable,
                        details: "\(persona.topRelationshipFamily ?? "None") at \(formatted(topRelationshipPercentage))%; \(persona.topRelationshipFamilyCount)/\(persona.totalRelationshipFamilyCount) relationship cards"
                    )
                )
            }
        }

        if let customPerformer = summariesById["custom-performer"] {
            gates.append(
                .init(
                    id: "customPerformerSurfaceRate",
                    title: "Custom Performer custom surfaced 5-15%",
                    severity: .hard,
                    passed: (5...15).contains(customPerformer.customMetricSurfacedPercent),
                    details: "actual \(formatted(customPerformer.customMetricSurfacedPercent))%"
                )
            )
            gates.append(
                .init(
                    id: "customPerformerPersonalizedDelta",
                    title: "Custom Performer personalized delta 0.5-2.0",
                    severity: .hard,
                    passed: (0.5...2.0).contains(customPerformer.personalizedDelta),
                    details: "actual \(formatted(customPerformer.personalizedDelta))"
                )
            )
            gates.append(
                .init(
                    id: "customRelationshipFlagOnCap",
                    title: "Custom relationship flag-on surfaced <=5%",
                    severity: .hard,
                    passed: customPerformer.customRelationshipFlagOnSurfacedPercent <= 5,
                    details: "actual \(formatted(customPerformer.customRelationshipFlagOnSurfacedPercent))%"
                )
            )
        }

        let nonCustomPersonas = summary.personas.filter { $0.id != "custom-performer" }
        let nonCustomSurfaced = nonCustomPersonas.filter { $0.customMetricSurfacedPercent > 0 }
        gates.append(
            .init(
                id: "nonCustomPersonasCustomSurfaceZero",
                title: "Non-custom personas custom surfaced 0%",
                severity: .hard,
                passed: nonCustomSurfaced.isEmpty,
                details: nonCustomSurfaced.map { "\($0.persona): \(formatted($0.customMetricSurfacedPercent))%" }.joined(separator: ", ").nilIfEmpty ?? "none"
            )
        )

        let hardFailures = gates.filter { $0.severity == .hard && !$0.passed }
        let softFailures = gates.filter { $0.severity == .soft && !$0.passed }
        let status: CalibrationStatus
        if hardFailures.isEmpty && softFailures.isEmpty {
            status = .readyForManualTesting
        } else if hardFailures.isEmpty {
            status = .needsTuning
        } else {
            status = .notReady
        }

        return .init(
            generatedAt: Date(),
            status: status,
            passed: hardFailures.isEmpty && softFailures.isEmpty,
            hardFailureCount: hardFailures.count,
            softFailureCount: softFailures.count,
            gates: gates,
            failedGates: gates.filter { !$0.passed }.map(\.id)
        )
    }

    private static func sharedTopValueGate(
        id: String,
        title: String,
        counts: [String: Int],
        severity: CalibrationGateSeverity,
        contextPass: ((String, Int) -> Bool)? = nil
    ) -> CalibrationGate {
        let worst = counts
            .filter { $0.key != "None" }
            .sorted {
                if $0.value != $1.value {
                    return $0.value > $1.value
                }
                return $0.key < $1.key
            }
            .first
        let passed: Bool
        if let worst {
            passed = worst.value < 4 || (contextPass?(worst.key, worst.value) ?? false)
        } else {
            passed = true
        }
        let details = worst.map { "\($0.key): \($0.value) personas" } ?? "none"
        return .init(
            id: id,
            title: title,
            severity: severity,
            passed: passed,
            details: details
        )
    }

    private static func countTopValues(_ values: [String]) -> [String: Int] {
        Dictionary(grouping: values, by: { $0 }).mapValues(\.count)
    }

    private static func distanceOutside(
        _ value: Double,
        range: ClosedRange<Double>
    ) -> Double {
        if value < range.lowerBound {
            return range.lowerBound - value
        }

        if value > range.upperBound {
            return value - range.upperBound
        }

        return 0
    }

    private static func recommendationGroupAwarePass(
        recommendation: String,
        count: Int,
        personas: [PersonaCalibrationSummary]
    ) -> Bool {
        guard count >= 4 else { return true }

        let matchingPersonas = personas.filter { $0.topRecommendation == recommendation }
        let stateGroups = Set(matchingPersonas.map { recommendationStateGroup(for: $0.dominantState) })
        let driverGroups = Set(matchingPersonas.map { driverGroup(for: $0.topCurrentDriver) })

        if recommendation == "keepConsistent",
           stateGroups.isSubset(of: ["stable"]) {
            return true
        }

        return stateGroups.count < 2 && driverGroups.count < 3
    }

    private static func recommendationStateGroup(for state: String) -> String {
        switch state {
        case "Strong", "Primed", "Balanced", "Rebounding":
            return "stable"
        case "Under Pressure", "Dipping":
            return "pressure"
        default:
            return "other"
        }
    }

    private static func driverGroup(for title: String) -> String {
        switch title {
        case "Sleep Hours", "Sleep Quality", "Sleep Duration":
            return "sleep"
        case "Soreness", "Workout Difficulty", "Workout Performance", "Running Performance", "Cycling Performance":
            return "trainingRecovery"
        case "Stress", "Anxiety", "Energy", "Mood", "Mental Clarity", "Motivation":
            return "mindEnergy"
        case "Alcohol", "Caffeine", "Weed", "Nicotine", "Porn":
            return "habits"
        case "Low Data Confidence", "Recent logging":
            return "data"
        default:
            return "other"
        }
    }

    private static func writeJSON<T: Encodable>(_ value: T, to url: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        try encoder.encode(value).write(to: url, options: .atomic)
    }

    private static func iterationLog(scorecard: CalibrationScorecard) -> String {
        var lines = [String]()
        lines.append("# LifeIQ Calibration Iteration Log")
        lines.append("")
        lines.append("- Run type: XCTest calibration harness")
        lines.append("- Max local iterations for algorithm tuning: 6")
        lines.append("- Current status: \(scorecard.status.rawValue)")
        lines.append("- Hard failures: \(scorecard.hardFailureCount)")
        lines.append("- Soft failures: \(scorecard.softFailureCount)")
        lines.append("")
        lines.append("## Guardrails")
        lines.append("- Tune reusable policy, not persona-specific outcomes.")
        lines.append("- Do not hardcode persona names in production algorithm code.")
        lines.append("- Do not add one-off signal hacks unless they belong in metric semantics or relationship policy.")
        lines.append("- Prefer component, role, severity, recency, confidence, actionability, novelty, and state polarity.")
        lines.append("")
        lines.append("## Failed Gates")
        let failedGates = scorecard.gates.filter { !$0.passed }
        if failedGates.isEmpty {
            lines.append("- None")
        } else {
            for gate in failedGates {
                lines.append("- \(gate.id): \(gate.details)")
            }
        }
        return lines.joined(separator: "\n")
    }

    private static func formatted(_ value: Double) -> String {
        String(format: "%.1f", value)
    }

    private static func formatted(_ range: ClosedRange<Double>) -> String {
        "\(formatted(range.lowerBound))-\(formatted(range.upperBound))"
    }
}

private struct CalibrationSummary: Encodable {
    let generatedAt: Date
    let seed: Int
    let dayCount: Int
    let referenceDate: Date
    let personas: [PersonaCalibrationSummary]
}

private struct PersonaCalibrationSummary: Encodable {
    let id: String
    let persona: String
    let currentAverage: Double?
    let v2Average: Double?
    let currentRange: [Int]
    let v2Range: [Int]
    let dominantState: String
    let topCurrentDriver: String
    let topV2HealthDriver: String
    let topV2BehaviorDriver: String
    let topV2DataSignal: String
    let topRecommendation: String
    let topSurfacedInsight: String?
    let topSurfacedInsightPercentage: Double?
    let topRelationshipFamily: String?
    let topRelationshipFamilyCount: Int
    let topRelationshipFamilyPercentage: Double?
    let totalRelationshipFamilyCount: Int
    let customMetricLoggedDays: Int
    let customMetricSurfacedPercent: Double
    let personalizedDelta: Double
    let customRelationshipFlagOnSurfacedPercent: Double
    let positiveLeakage: Int
    let warningFlags: [String]

    init(report: SQViewLabSimulationReport) {
        id = report.persona.id
        persona = report.persona.title
        currentAverage = report.averageScore
        v2Average = report.averageShadowV2Score
        currentRange = [report.minimumScore, report.maximumScore].compactMap { $0 }
        v2Range = [report.minimumShadowV2Score, report.maximumShadowV2Score].compactMap { $0 }
        dominantState = report.stateDistribution.first?.label ?? "None"
        topCurrentDriver = report.topDriverAfterCalibrationDistribution.first?.label
            ?? report.topDriverDistribution.first?.label
            ?? "None"
        topV2HealthDriver = report.topV2HealthDriverDistribution.first?.label ?? "None"
        topV2BehaviorDriver = report.topV2BehaviorDriverDistribution.first?.label ?? "None"
        topV2DataSignal = report.topV2DataConfidenceSignalDistribution.first?.label ?? "None"
        topRecommendation = report.primaryActionFamilyAfterRoutingDistribution.first?.label
            ?? report.primaryActionRecommendationFamilyDistribution.first?.label
            ?? "None"
        topSurfacedInsight = report.surfacedInsightDistribution.first?.label
        topSurfacedInsightPercentage = report.surfacedInsightDistribution.first?.percentage
        topRelationshipFamily = report.relationshipFamilyAfterSlotPolicyDistribution.first?.label
        topRelationshipFamilyCount = report.relationshipFamilyAfterSlotPolicyDistribution.first?.count ?? 0
        topRelationshipFamilyPercentage = report.relationshipFamilyAfterSlotPolicyDistribution.first?.percentage
        totalRelationshipFamilyCount = report.relationshipFamilyAfterSlotPolicyDistribution.reduce(0) { $0 + $1.count }
        customMetricLoggedDays = report.customMetricLoggedDays
        customMetricSurfacedPercent = report.customMetricSurfacePercentage
        personalizedDelta = report.averageShadowScoreDelta ?? 0
        customRelationshipFlagOnSurfacedPercent = report.customRelationshipFlagOnSurfacePercentage
        positiveLeakage = report.pressureStatePositiveLeakageCount
        warningFlags = report.customMetricRegressionGuardFlags
    }
}

private struct CalibrationScorecard: Encodable {
    let generatedAt: Date
    let status: CalibrationStatus
    let passed: Bool
    let hardFailureCount: Int
    let softFailureCount: Int
    let gates: [CalibrationGate]
    let failedGates: [String]
}

private enum CalibrationStatus: String, Encodable {
    case readyForManualTesting
    case needsTuning
    case notReady
}

private struct CalibrationGate: Encodable {
    let id: String
    let title: String
    let severity: CalibrationGateSeverity
    let passed: Bool
    let details: String
}

private enum CalibrationGateSeverity: String, Encodable {
    case hard
    case soft
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}

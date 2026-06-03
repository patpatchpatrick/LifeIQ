//
//  SQInsightLibraryController.swift
//  BeastFitness
//
//  Created by Codex on 5/27/26.
//

import Foundation
import BeastFitnessCore

enum SQInsightLibrarySort: String, CaseIterable, Identifiable {
    case confidence = "Confidence"
    case effect = "Effect"
    case matchedDays = "Days"

    var id: String { rawValue }
}

@Observable @MainActor
final class SQInsightLibraryController {
    let id = UUID().uuidString
    private let input: SQHealthIntelligenceInput
    private let analyzer = SQInsightExplorerAnalyzer()
    private let source: String
    private let userState: SQUserStating

    private(set) var relationships: [SQInsightExplorerRelationshipResult] = []

    private var shouldUseDemoData: Bool {
        SQAdminConfig.useMockDashboardHealthData
            || SQAdminConfig.useMockHealthData
            || userState.loggedInUser?.usesAppReviewDemoData == true
    }

    var selectedRange: SQInsightExplorerRange {
        didSet { rebuildRelationships() }
    }

    var selectedSort: SQInsightLibrarySort {
        didSet { sortRelationships() }
    }

    init(
        input: SQHealthIntelligenceInput,
        initialRange: SQInsightExplorerRange = .days90,
        initialSort: SQInsightLibrarySort = .confidence,
        source: String,
        userState: SQUserStating = SQAppState.shared.userState
    ) {
        self.input = input
        self.selectedRange = initialRange
        self.selectedSort = initialSort
        self.source = source
        self.userState = userState
        rebuildRelationships()
    }

    func openExplorer(for relationship: SQInsightExplorerRelationshipResult) {
        let controller = SQInsightExplorerController(
            input: input,
            preselectedDriverId: relationship.driverId,
            preselectedOutcomeId: relationship.outcomeId,
            preselectedLag: relationship.lag,
            initialRange: relationship.range
        )
        controller.applyTopRelationship(relationship)

        SQLogger.shared.log(
            "PTD InsightLibrary openExplorer source=\(source) driver=\(relationship.driverId) outcome=\(relationship.outcomeId) range=\(relationship.range.rawValue) lag=\(relationship.lag.rawValue)",
            .debug,
            context: .dashboard
        )

        SQAppState.shared.hub.domainEvents.send(.pushDashboardRoute(.insightExplorer(controller: controller)))
    }

    private func rebuildRelationships() {
        let allRelationships = shouldUseDemoData
            ? Self.mockAppStoreRelationships(range: selectedRange)
            : analyzer.topRelationships(input: input, range: selectedRange)
        relationships = SQAdminConfig.hideScreenshotSensitiveInsights
            ? allRelationships.filter { !Self.isScreenshotSensitiveRelationship($0) }
            : allRelationships
        sortRelationships()
    }

    private func sortRelationships() {
        relationships.sort { lhs, rhs in
            switch selectedSort {
            case .confidence:
                if confidenceRank(lhs.confidence) != confidenceRank(rhs.confidence) {
                    return confidenceRank(lhs.confidence) > confidenceRank(rhs.confidence)
                }

                if lhs.rankingScore != rhs.rankingScore {
                    return lhs.rankingScore > rhs.rankingScore
                }

                return lhs.matchedDays > rhs.matchedDays
            case .effect:
                if abs(lhs.effectPoints) != abs(rhs.effectPoints) {
                    return abs(lhs.effectPoints) > abs(rhs.effectPoints)
                }

                return confidenceRank(lhs.confidence) > confidenceRank(rhs.confidence)
            case .matchedDays:
                if lhs.matchedDays != rhs.matchedDays {
                    return lhs.matchedDays > rhs.matchedDays
                }

                return lhs.rankingScore > rhs.rankingScore
            }
        }
    }

    private func confidenceRank(_ confidence: SQInsightConfidence) -> Int {
        switch confidence {
        case .high:
            return 3
        case .medium:
            return 2
        case .low:
            return 1
        }
    }

    private static func isScreenshotSensitiveRelationship(_ relationship: SQInsightExplorerRelationshipResult) -> Bool {
        containsScreenshotSensitiveText(relationship.driverId)
            || containsScreenshotSensitiveText(relationship.outcomeId)
            || containsScreenshotSensitiveText(relationship.driverTitle)
            || containsScreenshotSensitiveText(relationship.outcomeTitle)
    }

    private static func containsScreenshotSensitiveText(_ text: String) -> Bool {
        let lowercased = text.lowercased()
        return lowercased.contains("weed") || lowercased.contains("porn")
    }

    private static func mockAppStoreRelationships(range: SQInsightExplorerRange) -> [SQInsightExplorerRelationshipResult] {
        [
            mockRelationship(
                id: "mock.caffeine.sleepQuality",
                driverId: SQMetricId.caffeine,
                outcomeId: SQMetricId.sleepQuality,
                driverTitle: "Caffeine",
                outcomeTitle: "Sleep Quality",
                range: range,
                lag: .sameDay,
                displayEffectPoints: -16,
                confidence: .high,
                matchedDays: 42,
                highOutcomeLabel: "6.7/10",
                lowOutcomeLabel: "8.1/10",
                highRaw: 6.7,
                lowRaw: 8.1,
                rankingScore: 96,
                driverLow: 22,
                driverHigh: 78,
                outcomeLowDriver: 81,
                outcomeHighDriver: 67
            ),
            mockRelationship(
                id: "mock.alcohol.remSleep",
                driverId: SQMetricId.alcohol,
                outcomeId: SQInsightAnalysisMetricId.sleepRemMinutes,
                driverTitle: "Alcohol",
                outcomeTitle: "REM Sleep",
                range: range,
                lag: .sameDay,
                displayEffectPoints: -14,
                confidence: .high,
                matchedDays: 38,
                highOutcomeLabel: "71 min",
                lowOutcomeLabel: "91 min",
                highRaw: 71,
                lowRaw: 91,
                rankingScore: 91,
                driverLow: 18,
                driverHigh: 72,
                outcomeLowDriver: 76,
                outcomeHighDriver: 62
            ),
            mockRelationship(
                id: "mock.workoutDifficulty.sleepContinuity",
                driverId: SQInsightAnalysisMetricId.workoutDifficulty,
                outcomeId: SQInsightAnalysisMetricId.sleepContinuity,
                driverTitle: "Workout Difficulty",
                outcomeTitle: "Sleep Continuity",
                range: range,
                lag: .sameDay,
                displayEffectPoints: -11,
                confidence: .medium,
                matchedDays: 31,
                highOutcomeLabel: "72/100",
                lowOutcomeLabel: "83/100",
                highRaw: 72,
                lowRaw: 83,
                rankingScore: 82,
                driverLow: 34,
                driverHigh: 82,
                outcomeLowDriver: 83,
                outcomeHighDriver: 72
            ),
            mockRelationship(
                id: "mock.hydration.energy",
                driverId: SQMetricId.hydration,
                outcomeId: SQMetricId.energy,
                driverTitle: "Hydration",
                outcomeTitle: "Energy",
                range: range,
                lag: .sameDay,
                displayEffectPoints: 13,
                confidence: .medium,
                matchedDays: 36,
                highOutcomeLabel: "8.2/10",
                lowOutcomeLabel: "6.9/10",
                highRaw: 8.2,
                lowRaw: 6.9,
                rankingScore: 80,
                driverLow: 39,
                driverHigh: 86,
                outcomeLowDriver: 69,
                outcomeHighDriver: 82
            ),
            mockRelationship(
                id: "mock.sleepQuality.mood",
                driverId: SQMetricId.sleepQuality,
                outcomeId: SQMetricId.mood,
                driverTitle: "Sleep Quality",
                outcomeTitle: "Mood",
                range: range,
                lag: .nextDay,
                displayEffectPoints: 12,
                confidence: .medium,
                matchedDays: 34,
                highOutcomeLabel: "8.0/10",
                lowOutcomeLabel: "6.8/10",
                highRaw: 8.0,
                lowRaw: 6.8,
                rankingScore: 77,
                driverLow: 43,
                driverHigh: 84,
                outcomeLowDriver: 68,
                outcomeHighDriver: 80
            )
        ]
    }

    private static func mockRelationship(
        id: String,
        driverId: String,
        outcomeId: String,
        driverTitle: String,
        outcomeTitle: String,
        range: SQInsightExplorerRange,
        lag: SQInsightExplorerLag,
        displayEffectPoints: Double,
        confidence: SQInsightConfidence,
        matchedDays: Int,
        highOutcomeLabel: String,
        lowOutcomeLabel: String,
        highRaw: Double,
        lowRaw: Double,
        rankingScore: Double,
        driverLow: Double,
        driverHigh: Double,
        outcomeLowDriver: Double,
        outcomeHighDriver: Double
    ) -> SQInsightExplorerRelationshipResult {
        .init(
            id: "\(id)-\(range.rawValue)",
            driverId: driverId,
            outcomeId: outcomeId,
            driverTitle: driverTitle,
            outcomeTitle: outcomeTitle,
            range: range,
            lag: lag,
            higherDriverThreshold: (driverLow + driverHigh) / 2,
            displayEffectPoints: displayEffectPoints,
            effectPoints: displayEffectPoints,
            confidence: confidence,
            matchedDays: matchedDays,
            highDriverAverageOutcome: outcomeHighDriver,
            highDriverAverageOutcomeRawLabel: highOutcomeLabel,
            lowDriverAverageOutcome: outcomeLowDriver,
            lowDriverAverageOutcomeRawLabel: lowOutcomeLabel,
            rankingScore: rankingScore,
            chartPoints: mockChartPoints(
                idBase: id,
                matchedDays: matchedDays,
                driverLow: driverLow,
                driverHigh: driverHigh,
                outcomeLowDriver: outcomeLowDriver,
                outcomeHighDriver: outcomeHighDriver,
                highRaw: highRaw,
                lowRaw: lowRaw,
                highLabel: highOutcomeLabel,
                lowLabel: lowOutcomeLabel
            )
        )
    }

    private static func mockChartPoints(
        idBase: String,
        matchedDays: Int,
        driverLow: Double,
        driverHigh: Double,
        outcomeLowDriver: Double,
        outcomeHighDriver: Double,
        highRaw: Double,
        lowRaw: Double,
        highLabel: String,
        lowLabel: String
    ) -> [SQInsightExplorerChartPoint] {
        let calendar = Calendar.current
        let startDate = calendar.date(byAdding: .day, value: -matchedDays, to: .now) ?? .now

        return (0..<matchedDays).map { index in
            let isHighDriverDay = index % 5 == 1 || index % 5 == 2
            let phase = Double(index % 7)
            let driverValue = isHighDriverDay
                ? min(100, driverHigh + phase - 3)
                : max(0, driverLow + phase - 3)
            let outcomeValue = isHighDriverDay
                ? min(100, outcomeHighDriver + (phase - 3) * 0.8)
                : max(0, outcomeLowDriver + (phase - 3) * 0.8)
            let rawValue = isHighDriverDay ? highRaw : lowRaw
            let date = calendar.date(byAdding: .day, value: index, to: startDate) ?? startDate

            return .init(
                id: "\(idBase)-\(index)",
                date: date,
                driverValue: driverValue,
                driverDisplayLabel: "\(driverValue.sqStringRoundedTo(places: 0))%",
                outcomeValue: outcomeValue,
                outcomeRawValue: rawValue,
                outcomeDisplayLabel: isHighDriverDay ? highLabel : lowLabel,
                outcomeUtilityValue: outcomeValue
            )
        }
    }
}

extension SQInsightLibraryController: Hashable {
    nonisolated static func == (lhs: SQInsightLibraryController, rhs: SQInsightLibraryController) -> Bool {
        lhs.id == rhs.id
    }

    nonisolated func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

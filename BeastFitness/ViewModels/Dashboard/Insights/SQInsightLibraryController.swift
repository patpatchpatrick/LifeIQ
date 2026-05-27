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

    private(set) var relationships: [SQInsightExplorerRelationshipResult] = []

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
        source: String
    ) {
        self.input = input
        self.selectedRange = initialRange
        self.selectedSort = initialSort
        self.source = source
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
        let allRelationships = analyzer.topRelationships(input: input, range: selectedRange)
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
}

extension SQInsightLibraryController: Hashable {
    nonisolated static func == (lhs: SQInsightLibraryController, rhs: SQInsightLibraryController) -> Bool {
        lhs.id == rhs.id
    }

    nonisolated func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

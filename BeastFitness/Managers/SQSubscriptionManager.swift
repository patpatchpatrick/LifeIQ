//
//  SQSubscriptionManager.swift
//  BeastFitness
//

import Foundation
import BeastFitnessCore

struct SQWorkoutScorePreviewGrant: Codable, Equatable {
    let workoutId: String
    let usedAt: Date
}

struct SQWorkoutScorePreviewState: Equatable {
    let unlockedWorkoutId: String?
    let nextFreeDate: Date

    var hasUnlockedWorkout: Bool {
        unlockedWorkoutId != nil
    }

    var lockedSubtitle: String {
        "Next free score: \(nextFreeDateText). Unlock performance and difficulty scores for every workout."
    }

    var compactLockText: String {
        if Calendar.current.isDateInToday(nextFreeDate) {
            return "Free today"
        }

        return "Next: \(nextFreeDate.formattedString(with: .short))"
    }

    private var nextFreeDateText: String {
        if Calendar.current.isDateInToday(nextFreeDate) {
            return "Today"
        }

        return nextFreeDate.formattedString(with: .short)
    }
}

enum SQSubscriptionManager {
    enum ProductID {
        static let monthly = "com.lifeiq.pro.monthly"
        static let annual = "com.lifeiq.pro.annual"
        static let all: Set<String> = [monthly, annual]
    }

    private static let workoutScorePreviewKeyPrefix = "subscription.weekly-workout-score-preview"
    private static let workoutScorePreviewCadenceDays = 7

    @MainActor
    static var weeklyScorePreviewCompactText: String {
        weeklyWorkoutScorePreviewState(candidates: []).compactLockText
    }

    @MainActor
    static var weeklyScorePreviewLockedSubtitle: String {
        weeklyWorkoutScorePreviewState(candidates: []).lockedSubtitle
    }

    @MainActor
    static func displaySubscriptionScreen(source: String, feature: String? = nil) {
        SQAnalyticsManager.shared.track(.subscriptionScreenRequested(source: source, feature: feature))

        let featureText = feature.map { " feature=\($0)" } ?? ""
        SQLogger.shared.log(
            "PTD Display subscription screen source=\(source)\(featureText)",
            .info,
            context: .dashboard,
            isPriority: true
        )

        SQAppState.shared.hub.domainEvents.send(
            .pushDashboardRoute(.subscription(controller: .init(source: source, feature: feature)))
        )
    }

    @MainActor
    static var effectiveSubscriptionLevel: SQSubscriptionLevel {
        if let override = SQAdminConfig.subscriptionLevelOverride {
            return override
        }

        if let demoSubscriptionLevel = SQAppState.shared.userState.loggedInUser?.demoSubscriptionLevel {
            return demoSubscriptionLevel
        }

        return SQAppState.shared.subscriptionState.appleSubscriptionLevel
    }

    @MainActor
    static var hasPremiumAccess: Bool {
        effectiveSubscriptionLevel == .premium
    }

    @MainActor
    static func isCustomMetricLocked(_ metric: SQMetricDefinition, in metrics: [SQMetricDefinition]) -> Bool {
        guard !metric.isPreset else { return false }
        guard !hasPremiumAccess else { return false }

        return !unlockedCustomMetricIds(in: metrics).contains(metric.id)
    }

    @MainActor
    static func availableMetricDefinitions(_ metrics: [SQMetricDefinition]) -> [SQMetricDefinition] {
        guard !hasPremiumAccess else { return metrics }
        let unlockedIds = unlockedCustomMetricIds(in: metrics)
        return metrics.filter { metric in
            metric.isPreset || unlockedIds.contains(metric.id)
        }
    }

    @MainActor
    static func canCreateCustomMetric(existingMetrics: [SQMetricDefinition]) -> Bool {
        guard !hasPremiumAccess else { return true }
        let customMetricCount = existingMetrics.filter { !$0.isPreset && !$0.isArchived }.count
        return customMetricCount < SQAdminConfig.freeCustomMetricLimit
    }

    @MainActor
    static func weeklyWorkoutScorePreviewState(
        candidates: [SQWorkoutSessionable],
        isPremiumUnlocked: Bool = false,
        referenceDate: Date = .now
    ) -> SQWorkoutScorePreviewState {
        if isPremiumUnlocked {
            return .init(unlockedWorkoutId: nil, nextFreeDate: nextFreeDate(after: referenceDate, referenceDate: referenceDate))
        }

        let userId = SQAppState.shared.userState.loggedInUser?.id ?? "guest"
        let todayStart = Calendar.current.startOfDay(for: referenceDate)
        let sortedCandidates = candidates
            .filter { $0.startDate != nil }
            .sorted { ($0.startDate ?? .distantPast) > ($1.startDate ?? .distantPast) }

        if let grant = storedWorkoutScorePreviewGrant(for: userId) {
            let nextDate = nextFreeDate(after: grant.usedAt, referenceDate: referenceDate)
            let eligibleCandidates = todayStart >= nextDate
                ? sortedCandidates.filter { candidate in
                    guard let startDate = candidate.startDate else { return false }
                    return Calendar.current.startOfDay(for: startDate) >= nextDate
                }
                : []

            if let candidate = eligibleCandidates.first {
                storeWorkoutScorePreviewGrant(.init(workoutId: candidate.id, usedAt: referenceDate), for: userId)
                return .init(
                    unlockedWorkoutId: candidate.id,
                    nextFreeDate: nextFreeDate(after: referenceDate, referenceDate: referenceDate)
                )
            }

            if sortedCandidates.contains(where: { $0.id == grant.workoutId }) {
                return .init(unlockedWorkoutId: grant.workoutId, nextFreeDate: nextDate)
            }

            if todayStart >= nextDate {
                return .init(unlockedWorkoutId: nil, nextFreeDate: todayStart)
            }

            return .init(unlockedWorkoutId: nil, nextFreeDate: nextDate)
        }

        guard let candidate = sortedCandidates.first else {
            return .init(unlockedWorkoutId: nil, nextFreeDate: todayStart)
        }

        storeWorkoutScorePreviewGrant(.init(workoutId: candidate.id, usedAt: referenceDate), for: userId)
        return .init(
            unlockedWorkoutId: candidate.id,
            nextFreeDate: nextFreeDate(after: referenceDate, referenceDate: referenceDate)
        )
    }

    static func clearWeeklyWorkoutScorePreview(for userId: String) {
        UserDefaults.standard.removeObject(forKey: workoutScorePreviewKey(for: userId))
    }

    private static func nextFreeDate(after usedAt: Date, referenceDate: Date) -> Date {
        let usedDay = Calendar.current.startOfDay(for: usedAt)
        return Calendar.current.date(
            byAdding: .day,
            value: workoutScorePreviewCadenceDays,
            to: usedDay
        ) ?? Calendar.current.startOfDay(for: referenceDate)
    }

    private static func storedWorkoutScorePreviewGrant(for userId: String) -> SQWorkoutScorePreviewGrant? {
        guard let data = UserDefaults.standard.data(forKey: workoutScorePreviewKey(for: userId)) else {
            return nil
        }

        return try? JSONDecoder().decode(SQWorkoutScorePreviewGrant.self, from: data)
    }

    private static func storeWorkoutScorePreviewGrant(_ grant: SQWorkoutScorePreviewGrant, for userId: String) {
        guard let data = try? JSONEncoder().encode(grant) else { return }
        UserDefaults.standard.set(data, forKey: workoutScorePreviewKey(for: userId))
    }

    private static func workoutScorePreviewKey(for userId: String) -> String {
        "\(workoutScorePreviewKeyPrefix).\(userId)"
    }

    @MainActor
    private static func unlockedCustomMetricIds(in metrics: [SQMetricDefinition]) -> Set<String> {
        let limit = max(0, SQAdminConfig.freeCustomMetricLimit)
        guard limit > 0 else { return [] }

        let activeCustomMetrics = metrics
            .filter { !$0.isPreset && !$0.isArchived && $0.isEnabled }
            .sorted(by: metricEntitlementSort)

        let inactiveCustomMetrics = metrics
            .filter { !$0.isPreset && !$0.isArchived && !$0.isEnabled }
            .sorted(by: metricEntitlementSort)

        return Set((activeCustomMetrics + inactiveCustomMetrics).prefix(limit).map(\.id))
    }

    private static func metricEntitlementSort(_ lhs: SQMetricDefinition, _ rhs: SQMetricDefinition) -> Bool {
        if lhs.sortOrder == rhs.sortOrder {
            return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
        }

        return lhs.sortOrder < rhs.sortOrder
    }
}

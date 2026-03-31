//
//  SQWorkoutSessionMetadataManager.swift
//  BeastFitness
//

import Foundation
import BeastFitnessCore

/// Caches computed per-workout metadata (e.g. metrics) in memory so expensive
/// calculations like GPS-based pace are only performed once per workout per session.
///
/// Cache is keyed by workout `sourceId`. Invalidate when workouts are mutated
/// (save/delete) to ensure stale data is never shown.
///
/// Future improvement: persist entries to SwiftData so metrics survive app restarts.
actor SQWorkoutSessionMetadataManager {

    static let shared = SQWorkoutSessionMetadataManager()

    private var metricCache: [String: [SQQuantityType: SQWorkoutMetric]] = [:]
    private var heartRateZoneSummaryCache: [String: SQHeartRateWorkoutZoneSummary] = [:]

    func cachedMetric(for quantityType: SQQuantityType, sourceId: String) -> SQWorkoutMetric? {
        metricCache[sourceId, default: [:]][quantityType]
    }

    func cacheMetric(_ metric: SQWorkoutMetric, for quantityType: SQQuantityType, sourceId: String) {
        metricCache[sourceId, default: [:]][quantityType] = metric
    }

    func cachedHeartRateZoneSummary(for sourceId: String) -> SQHeartRateWorkoutZoneSummary? {
        heartRateZoneSummaryCache[sourceId]
    }

    func cacheHeartRateZoneSummary(_ summary: SQHeartRateWorkoutZoneSummary, for sourceId: String) {
        heartRateZoneSummaryCache[sourceId] = summary
    }

    func invalidate() {
        metricCache.removeAll()
        heartRateZoneSummaryCache.removeAll()
        SQLogger.shared.log("Workout session metadata cache invalidated", .debug, context: .workoutManager)
    }
}

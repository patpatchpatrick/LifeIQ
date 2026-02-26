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
final class SQWorkoutSessionMetadataManager {

    static let shared = SQWorkoutSessionMetadataManager()

    private var metricCache: [String: [SQQuantityType: SQWorkoutMetric]] = [:]

    func cachedMetric(for quantityType: SQQuantityType, sourceId: String) -> SQWorkoutMetric? {
        metricCache[sourceId, default: [:]][quantityType]
    }

    func cacheMetric(_ metric: SQWorkoutMetric, for quantityType: SQQuantityType, sourceId: String) {
        metricCache[sourceId, default: [:]][quantityType] = metric
    }

    func invalidate() {
        metricCache.removeAll()
        SQLogger.shared.log("Workout session metadata cache invalidated", .debug, context: .workoutManager)
    }
}

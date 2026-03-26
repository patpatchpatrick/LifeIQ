//
//  SQFirestoreMetricsManager.swift
//  BeastFitness
//
//  Created by Patrick Doyle on 1/29/26.
//

import Foundation
import BeastFitnessCore

/// Tracks Firestore document reads for cost monitoring
@MainActor
final class SQFirestoreMetricsManager {
    static let shared = SQFirestoreMetricsManager()

    private(set) var sessionReads: Int = 0
    private(set) var sessionWrites: Int = 0
    private var sessionStartTime: Date = Date()

    private init() {}

    /// Call this after fetching documents from Firestore
    func recordReads(_ count: Int, operation: String) {
        sessionReads += count

        let sessionDuration = Date().timeIntervalSince(sessionStartTime)
        let minutes = Int(sessionDuration / 60)

        SQLogger.shared.log(
            "📊 Firestore: \(count) reads for '\(operation)' | Session total: \(sessionReads) reads (\(minutes)m)",
            .info,
            context: .network,
            isPriority: true
        )
    }

    func recordWrites(_ count: Int, operation: String) {
        sessionWrites += count

        let sessionDuration = Date().timeIntervalSince(sessionStartTime)
        let minutes = Int(sessionDuration / 60)

        SQLogger.shared.log(
            "📊 Firestore: \(count) writes for '\(operation)' | Session total: \(sessionWrites) writes (\(minutes)m)",
            .info,
            context: .network,
            isPriority: true
        )
    }

    /// Reset metrics (e.g., for testing or new session)
    func reset() {
        sessionReads = 0
        sessionWrites = 0
        sessionStartTime = Date()
        SQLogger.shared.log(
            "🔄 Firestore metrics reset",
            .debug,
            context: .network
        )
    }

    /// Get a summary of current metrics
    var summary: String {
        let sessionDuration = Date().timeIntervalSince(sessionStartTime)
        let minutes = Int(sessionDuration / 60)
        return "Session: \(sessionReads) reads, \(sessionWrites) writes in \(minutes)m"
    }
}

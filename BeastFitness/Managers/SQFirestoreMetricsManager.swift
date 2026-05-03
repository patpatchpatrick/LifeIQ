//
//  SQFirestoreMetricsManager.swift
//  BeastFitness
//
//  Created by Patrick Doyle on 1/29/26.
//

import Foundation
import BeastFitnessCore

enum SQFirestoreSafetyOperationKind {
    case read
    case write
}

actor SQFirestoreSafetyManager {
    static let shared = SQFirestoreSafetyManager()

    private struct RequestEvent {
        let date: Date
        let operation: String
    }

    private struct CountEvent {
        let date: Date
        let count: Int
    }

    private var requestEvents: [RequestEvent] = []
    private var readEvents: [CountEvent] = []
    private var writeEvents: [CountEvent] = []
    private var blockedUntil: Date?

    private init() {}

    func assertAllowed(
        kind: SQFirestoreSafetyOperationKind,
        operation: String,
        limitMultiplier: Int = 1
    ) throws {
        guard SQAdminConfig.firestoreSafetyEnabled else { return }

        let now = Date()
        pruneEvents(referenceDate: now)

        if let blockedUntil, blockedUntil > now {
            throw SQNetworkError.temporarilyUnavailable
        }

        let operationRequestCount = requestEvents.filter { $0.operation == operation }.count
        let maxRequests = SQAdminConfig.firestoreMaxRequestsPerMinutePerOperation * limitMultiplier
        guard operationRequestCount < maxRequests else {
            trip(operation: operation, reason: "request_velocity", referenceDate: now)
            throw SQNetworkError.temporarilyUnavailable
        }

        switch kind {
        case .read:
            let maxReads = SQAdminConfig.firestoreMaxReadsPerMinute * limitMultiplier
            guard readEvents.reduce(0, { $0 + $1.count }) < maxReads else {
                trip(operation: operation, reason: "read_velocity", referenceDate: now)
                throw SQNetworkError.temporarilyUnavailable
            }
        case .write:
            let maxWrites = SQAdminConfig.firestoreMaxWritesPerMinute * limitMultiplier
            guard writeEvents.reduce(0, { $0 + $1.count }) < maxWrites else {
                trip(operation: operation, reason: "write_velocity", referenceDate: now)
                throw SQNetworkError.temporarilyUnavailable
            }
        }

        requestEvents.append(.init(date: now, operation: operation))
    }

    func recordReads(
        _ count: Int,
        operation: String,
        limitMultiplier: Int = 1
    ) throws {
        guard SQAdminConfig.firestoreSafetyEnabled else { return }

        let now = Date()
        pruneEvents(referenceDate: now)

        if let blockedUntil, blockedUntil > now {
            throw SQNetworkError.temporarilyUnavailable
        }

        readEvents.append(.init(date: now, count: max(count, 1)))
        let maxReads = SQAdminConfig.firestoreMaxReadsPerMinute * limitMultiplier
        guard readEvents.reduce(0, { $0 + $1.count }) <= maxReads else {
            trip(operation: operation, reason: "read_volume", referenceDate: now)
            throw SQNetworkError.temporarilyUnavailable
        }
    }

    func recordWrites(
        _ count: Int,
        operation: String,
        limitMultiplier: Int = 1
    ) throws {
        guard SQAdminConfig.firestoreSafetyEnabled else { return }

        let now = Date()
        pruneEvents(referenceDate: now)

        if let blockedUntil, blockedUntil > now {
            throw SQNetworkError.temporarilyUnavailable
        }

        writeEvents.append(.init(date: now, count: max(count, 1)))
        let maxWrites = SQAdminConfig.firestoreMaxWritesPerMinute * limitMultiplier
        guard writeEvents.reduce(0, { $0 + $1.count }) <= maxWrites else {
            trip(operation: operation, reason: "write_volume", referenceDate: now)
            throw SQNetworkError.temporarilyUnavailable
        }
    }

    private func pruneEvents(referenceDate: Date) {
        let cutoff = referenceDate.addingTimeInterval(-60)
        requestEvents.removeAll { $0.date < cutoff }
        readEvents.removeAll { $0.date < cutoff }
        writeEvents.removeAll { $0.date < cutoff }
    }

    private func trip(operation: String, reason: String, referenceDate: Date) {
        blockedUntil = referenceDate.addingTimeInterval(SQAdminConfig.firestoreSafetyCooldownSeconds)
        SQLogger.shared.log(
            "Firestore safety circuit opened for \(operation) (\(reason)).",
            .error,
            context: .network,
            isPriority: true
        )
    }
}

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

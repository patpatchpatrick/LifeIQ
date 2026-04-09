//
//  SQSyncMetadataEntity.swift
//  BeastFitness
//
//  Created by Patrick Doyle on 1/29/26.
//

import SwiftData
import Foundation
import BeastFitnessCore

enum SyncResult {
    case noSyncNeeded
    case fullSyncCompleted
    case incrementalSyncCompleted
    case refreshCompleted
}

extension SyncResult {
    func logSync(documentCount: Int = 0, service: String, context: SQiOSLogContext) {
        switch self {
        case .fullSyncCompleted:
            SQLogger.shared.log(
                "Full sync: \(documentCount) documents for \(service)",
                .info,
                context: context,
                isPriority: true
            )
        case .refreshCompleted, .incrementalSyncCompleted:
            SQLogger.shared.log(
                "Incremental sync: \(documentCount) documents for \(service)",
                .info,
                context: context,
                isPriority: true
            )
        case .noSyncNeeded:
            break
        }

        SQLogger.shared.log("Sync result: \(self)", .debug, context: context)
    }
}

/// Tracks sync state for various data types
extension SQLocalPersistenceSchemaV1 {
    @Model
    final class SQSyncMetadataEntity {
        @Attribute(.unique) var id: String  // e.g., "daily-check-in-sync"
        var lastSyncDate: Date?

        init(id: String) {
            self.id = id
            self.lastSyncDate = nil
        }
    }
}

typealias SQSyncMetadataEntity = SQCurrentLocalSchema.SQSyncMetadataEntity

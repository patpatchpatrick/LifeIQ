//
//  SQSyncMetadataEntity.swift
//  BeastFitness
//
//  Created by Patrick Doyle on 1/29/26.
//

import SwiftData
import Foundation

/// Tracks sync state for various data types
@Model
final class SQSyncMetadataEntity {
    @Attribute(.unique) var id: String  // e.g., "daily-check-in-sync"
    var lastSyncDate: Date?

    init(id: String) {
        self.id = id
        self.lastSyncDate = nil
    }
}

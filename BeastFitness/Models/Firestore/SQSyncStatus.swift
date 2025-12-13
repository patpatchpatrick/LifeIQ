//
//  SQSyncStatus.swift
//  BeastFitness
//
//  Created by Patrick Doyle on 12/13/25.
//

enum SQSyncStatus: String, Codable, CaseIterable {
    case synced
    case pendingUpload
    case pendingDelete
    case failed
}

//
//  SQMetricDefinitionService.swift
//  BeastFitness
//
//  Created by Patrick Doyle on 2/4/26.
//

import Foundation

protocol SQMetricDefinitionServicing {
    static func saveMetricDefinition(_ definition: SQMetricDefinition) async throws
    static func fetchAllMetricDefinitions(for user: SQUser, afterDate: Date?) async throws -> [SQMetricDefinition]
}

final class SQMetricDefinitionService: SQNetworkService, SQMetricDefinitionServicing {

    static func saveMetricDefinition(_ definition: SQMetricDefinition) async throws {
        let user = await SQAppState.shared.userState.loggedInUser
        let _: SQVoidWrite = try await performRequest(SQMetricDefinitionRoute.saveMetricDefinition(definition, user))
    }

    static func fetchAllMetricDefinitions(for user: SQUser, afterDate: Date? = nil) async throws -> [SQMetricDefinition] {
        let definitions: [SQMetricDefinition] = try await performRequest(
            SQMetricDefinitionRoute.fetchAllMetricDefinitions(user, afterDate: afterDate)
        )
        return definitions.sorted { $0.updatedAt < $1.updatedAt }
    }
}

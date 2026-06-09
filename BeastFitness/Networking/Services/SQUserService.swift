//
//  SQUserService.swift
//  BeastFitness
//
//  Created by Patrick Doyle on 3/21/26.
//

import Foundation

final class SQUserService: SQNetworkService {

    static func createUser(uid: String, email: String, displayName: String? = nil) async throws -> SQUser {
        let trimmedDisplayName = displayName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let parsedNameParts = nameParts(from: trimmedDisplayName)
        let user = SQUser(
            id: uid,
            createdAt: .now,
            name: trimmedDisplayName,
            email: email,
            emailVerificationBypass: nil,
            firstName: parsedNameParts.first,
            lastName: parsedNameParts.last,
            dateOfBirth: nil,
            heightCentimeters: nil,
            weightKilograms: nil,
            unitSystem: SQUserDefaults.shared.preferredUnitSystem ?? .defaultForCurrentLocale,
            sleepSchedule: nil,
            subscriptionLevel: SQAdminConfig.appDefaultSubscriptionLevel,
            demoDataMode: nil,
            demoSubscriptionAccess: nil,
            onboardingCompletedAt: nil,
            onboardingStatus: .pending
        )
        let _: SQVoidWrite = try await performRequest(SQUserRoute.createUser(user))
        return user
    }

    private static func nameParts(from fullName: String) -> (first: String?, last: String?) {
        guard !fullName.isEmpty else { return (nil, nil) }

        let parts = fullName
            .split(separator: " ", maxSplits: 1, omittingEmptySubsequences: true)
            .map(String.init)

        return (
            parts.first,
            parts.count > 1 ? parts[1] : nil
        )
    }

    static func saveUser(_ user: SQUser) async throws -> SQUser {
        let _: SQVoidWrite = try await performRequest(SQUserRoute.saveUser(user))
        return user
    }

    static func updateSubscriptionLevel(uid: String, level: SQSubscriptionLevel) async throws {
        let _: SQVoidWrite = try await performRequest(SQUserRoute.updateSubscriptionLevel(uid: uid, level: level))
    }

    static func fetchUser(uid: String) async throws -> SQUser {
        return try await performRequest(SQUserRoute.fetchUser(uid: uid))
    }
}

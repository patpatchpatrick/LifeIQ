//
//  SQUserService.swift
//  BeastFitness
//
//  Created by Patrick Doyle on 3/21/26.
//

import Foundation

final class SQUserService: SQNetworkService {

    static func createUser(uid: String, email: String) async throws -> SQUser {
        let user = SQUser(
            id: uid,
            createdAt: .now,
            name: "",
            email: email,
            emailVerificationBypass: nil,
            firstName: nil,
            lastName: nil,
            dateOfBirth: nil,
            heightCentimeters: nil,
            weightKilograms: nil,
            unitSystem: SQUserDefaults.shared.preferredUnitSystem ?? .defaultForCurrentLocale,
            sleepSchedule: nil,
            subscriptionLevel: SQAdminConfig.appDefaultSubscriptionLevel,
            onboardingCompletedAt: nil,
            onboardingStatus: .pending
        )
        let _: SQVoidWrite = try await performRequest(SQUserRoute.createUser(user))
        return user
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

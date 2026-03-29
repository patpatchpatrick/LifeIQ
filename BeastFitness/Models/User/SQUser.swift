//
//  SQUser.swift
//  BeastFitness
//
//  Created by Patrick Doyle on 12/1/25.
//

import Foundation

enum SQOnboardingStatus: String, Codable {
    case pending
    case completed
}

enum SQSubscriptionLevel: String, Codable {
    case free
    case premium

    /// Temporary app-wide default while subscription plans are not wired up yet.
    /// Change this to `.free` to quickly exercise locked premium UI states.
    static let appDefault: SQSubscriptionLevel = .free
}

struct SQUser: Codable, Equatable {
    let id: String
    let name: String
    let email: String
    let firstName: String?
    let lastName: String?
    let dateOfBirth: Date?
    let heightInInches: Double?
    let weightInPounds: Double?
    let subscriptionLevel: SQSubscriptionLevel?
    let onboardingCompletedAt: Date?
    let onboardingStatus: SQOnboardingStatus?

    var requiresOnboarding: Bool {
        onboardingStatus == .pending
    }

    /// Temporary default while subscription plans are not wired up yet.
    /// Legacy users without a stored value should still be able to access premium insights.
    var effectiveSubscriptionLevel: SQSubscriptionLevel {
        subscriptionLevel ?? .appDefault
    }

    var hasPremiumAccess: Bool {
        effectiveSubscriptionLevel == .premium
    }

    var fullName: String {
        let parts = [firstName, lastName]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        if !parts.isEmpty {
            return parts.joined(separator: " ")
        }

        return name
    }
}

// MARK: - Mock

extension SQUser {
    static let mock = SQUser(
        id: "mock",
        name: "Patrick Doyle",
        email: "patrick@example.com",
        firstName: "Patrick",
        lastName: "Doyle",
        dateOfBirth: nil,
        heightInInches: 72,
        weightInPounds: 185,
        subscriptionLevel: .appDefault,
        onboardingCompletedAt: .now,
        onboardingStatus: .completed
    )
}

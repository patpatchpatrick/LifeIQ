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

struct SQUser: Codable, Equatable {
    let id: String
    let name: String
    let email: String
    let firstName: String?
    let lastName: String?
    let dateOfBirth: Date?
    let heightInInches: Double?
    let weightInPounds: Double?
    let onboardingCompletedAt: Date?
    let onboardingStatus: SQOnboardingStatus?

    var requiresOnboarding: Bool {
        onboardingStatus == .pending
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
        onboardingCompletedAt: .now,
        onboardingStatus: .completed
    )
}

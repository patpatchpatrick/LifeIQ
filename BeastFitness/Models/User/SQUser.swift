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

struct SQTimeOfDay: Codable, Equatable, Hashable {
    let hour: Int
    let minute: Int

    init(hour: Int, minute: Int) {
        self.hour = min(max(hour, 0), 23)
        self.minute = min(max(minute, 0), 59)
    }

    init(date: Date, calendar: Calendar = .current) {
        let components = calendar.dateComponents([.hour, .minute], from: date)
        self.init(
            hour: components.hour ?? 0,
            minute: components.minute ?? 0
        )
    }

    var minutesSinceMidnight: Int {
        (hour * 60) + minute
    }

    func date(on day: Date, calendar: Calendar = .current) -> Date {
        let startOfDay = calendar.startOfDay(for: day)
        return calendar.date(byAdding: .minute, value: minutesSinceMidnight, to: startOfDay) ?? startOfDay
    }
}

struct SQSleepSchedule: Codable, Equatable, Hashable {
    let sleepTime: SQTimeOfDay
    let wakeTime: SQTimeOfDay

    static let onboardingDefault = SQSleepSchedule(
        sleepTime: .init(hour: 23, minute: 0),
        wakeTime: .init(hour: 7, minute: 0)
    )

    var sleepCrossesMidnight: Bool {
        sleepTime.minutesSinceMidnight >= wakeTime.minutesSinceMidnight
    }
}

enum SQSubscriptionLevel: String, Codable {
    case free
    case premium

    /// Temporary app-wide default while subscription plans are not wired up yet.
    /// Change this to `.free` to quickly exercise locked premium UI states.
    static let appDefault: SQSubscriptionLevel = .premium
}

struct SQUser: Codable, Equatable {
    let id: String
    let createdAt: Date?
    let name: String
    let email: String
    let emailVerificationBypass: Bool?
    let firstName: String?
    let lastName: String?
    let dateOfBirth: Date?
    let heightCentimeters: Double?
    let weightKilograms: Double?
    let unitSystem: SQUnitSystem?
    let sleepSchedule: SQSleepSchedule?
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

    var effectiveUnitSystem: SQUnitSystem {
        unitSystem ?? SQUserDefaults.shared.preferredUnitSystem ?? .defaultForCurrentLocale
    }

    var heightInInches: Double? {
        SQUnit.centimeter.convert(heightCentimeters, to: .inch)
    }

    var weightInPounds: Double? {
        SQUnit.kilogram.convert(weightKilograms, to: .pound)
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
        createdAt: .now,
        name: "Patrick Doyle",
        email: "patrick@example.com",
        emailVerificationBypass: nil,
        firstName: "Patrick",
        lastName: "Doyle",
        dateOfBirth: nil,
        heightCentimeters: 182.9,
        weightKilograms: 83.9,
        unitSystem: .imperial,
        sleepSchedule: .onboardingDefault,
        subscriptionLevel: .appDefault,
        onboardingCompletedAt: .now,
        onboardingStatus: .completed
    )
}

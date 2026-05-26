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
    let demoDataMode: String?
    let demoSubscriptionAccess: String?
    let onboardingCompletedAt: Date?
    let onboardingStatus: SQOnboardingStatus?

    var requiresOnboarding: Bool {
        onboardingStatus == .pending
    }

    /// Firestore-backed subscription mirror used for admin/debug visibility.
    /// Runtime entitlement checks should use SQSubscriptionManager so Apple remains source of truth.
    var effectiveSubscriptionLevel: SQSubscriptionLevel {
        if let override = SQAdminConfig.subscriptionLevelOverride {
            return override
        }

        if let demoSubscriptionLevel = demoSubscriptionLevel {
            return demoSubscriptionLevel
        }

        return subscriptionLevel ?? SQAdminConfig.appDefaultSubscriptionLevel
    }

    var hasPremiumAccess: Bool {
        effectiveSubscriptionLevel == .premium
    }

    var usesAppReviewDemoData: Bool {
        normalizedDemoDataMode == "appreview"
    }

    var demoSubscriptionLevel: SQSubscriptionLevel? {
        switch normalizedDemoSubscriptionAccess {
        case SQSubscriptionLevel.premium.rawValue:
            return .premium
        case SQSubscriptionLevel.free.rawValue:
            return .free
        default:
            return nil
        }
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

    private var normalizedDemoDataMode: String? {
        demoDataMode?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
    }

    private var normalizedDemoSubscriptionAccess: String? {
        demoSubscriptionAccess?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
    }
}

extension SQUser {
    func withSubscriptionLevel(_ updatedSubscriptionLevel: SQSubscriptionLevel?) -> SQUser {
        SQUser(
            id: id,
            createdAt: createdAt,
            name: name,
            email: email,
            emailVerificationBypass: emailVerificationBypass,
            firstName: firstName,
            lastName: lastName,
            dateOfBirth: dateOfBirth,
            heightCentimeters: heightCentimeters,
            weightKilograms: weightKilograms,
            unitSystem: unitSystem,
            sleepSchedule: sleepSchedule,
            subscriptionLevel: updatedSubscriptionLevel,
            demoDataMode: demoDataMode,
            demoSubscriptionAccess: demoSubscriptionAccess,
            onboardingCompletedAt: onboardingCompletedAt,
            onboardingStatus: onboardingStatus
        )
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
        subscriptionLevel: SQAdminConfig.appDefaultSubscriptionLevel,
        demoDataMode: nil,
        demoSubscriptionAccess: nil,
        onboardingCompletedAt: .now,
        onboardingStatus: .completed
    )
}

//
//  SQAnalyticsManager.swift
//  BeastFitness
//
//  Created by Patrick Doyle on 12/19/25.
//

import AmplitudeUnified
import BeastFitnessCore
import Combine
import Foundation

enum SQAnalyticsEvent {
    case appOpened
    case authStateChanged(isLoggedIn: Bool)

    var name: String {
        switch self {
        case .appOpened:
            return "app_opened"
        case .authStateChanged:
            return "auth_state_changed"
        }
    }

    var properties: [String: Any]? {
        switch self {
        case .appOpened:
            return nil
        case .authStateChanged(let isLoggedIn):
            return ["is_logged_in": isLoggedIn]
        }
    }
}

@MainActor
protocol SQAnalyticsTracking: AnyObject {
    func configure(hub: EventHub, userState: SQUserStating)
    func track(_ event: SQAnalyticsEvent)
    func setUser(_ user: SQUser?)
}

@MainActor
final class SQAnalyticsManager: SQAnalyticsTracking {
    private enum Constants {
        static let apiKeyInfoDictionaryKey = "LIFEIQ_AMPLITUDE_API_KEY"
    }

    static let shared = SQAnalyticsManager()

    private weak var userState: SQUserStating?
    private var amplitude: Amplitude?
    private var cancellables = Set<AnyCancellable>()
    private var hasConfigured = false

    private init() {}

    func configure(hub: EventHub, userState: SQUserStating) {
        guard !hasConfigured else { return }
        hasConfigured = true
        self.userState = userState

        guard let apiKey = Self.apiKey else {
            SQLogger.shared.log(
                "Amplitude disabled: missing \(Constants.apiKeyInfoDictionaryKey) build setting.",
                .warning,
                context: .analytics,
                isPriority: true
            )
            return
        }

        amplitude = Amplitude(
            apiKey: apiKey,
            analyticsConfig: .init(autocapture: [])
        )

        handleEventSubscriptions(hub: hub)
        setUser(userState.loggedInUser)
        track(.appOpened)

        SQLogger.shared.log(
            "Amplitude analytics initialized",
            .info,
            context: .analytics
        )
    }

    func track(_ event: SQAnalyticsEvent) {
        guard let amplitude else { return }

        if let properties = event.properties {
            amplitude.track(eventType: event.name, eventProperties: properties)
        } else {
            amplitude.track(eventType: event.name)
        }

        SQLogger.shared.log(
            "[Amplitude Event] \(event.name)\(event.logSuffix)",
            .debug,
            context: .analytics
        )
    }

    func setUser(_ user: SQUser?) {
        guard let amplitude else { return }

        guard let user else {
            amplitude.reset()
            SQLogger.shared.log(
                "[Amplitude] reset user",
                .debug,
                context: .analytics
            )
            return
        }

        amplitude.setUserId(userId: user.id)

        let identify = Identify()
        if let fullName = user.fullName.sqNonEmptyTrimmed {
            identify.set(property: "name", value: fullName)
        }
        if let email = user.email.sqNonEmptyTrimmed {
            identify.set(property: "email", value: email)
        }

        identify.set(property: "has_completed_onboarding", value: user.onboardingStatus == .completed)
        identify.set(property: "has_premium_access", value: user.hasPremiumAccess)
        identify.set(property: "unit_system", value: user.effectiveUnitSystem.rawValue)
        identify.set(property: "subscription_level", value: user.effectiveSubscriptionLevel.rawValue)

        if let onboardingStatus = user.onboardingStatus?.rawValue {
            identify.set(property: "onboarding_status", value: onboardingStatus)
        }

        amplitude.identify(identify: identify)

        SQLogger.shared.log(
            "[Amplitude] set user id: \(user.id)",
            .debug,
            context: .analytics
        )
    }

    private func handleEventSubscriptions(hub: EventHub) {
        hub.userEvents
            .sink { [weak self] event in
                self?.handleUserEvent(event)
            }
            .store(in: &cancellables)
    }

    private func handleUserEvent(_ event: UserEvent) {
        switch event {
        case .loginStateChanged(let isLoggedIn):
            if isLoggedIn {
                setUser(userState?.loggedInUser)
                track(.authStateChanged(isLoggedIn: true))
            } else {
                track(.authStateChanged(isLoggedIn: false))
                setUser(nil)
            }

        case .profileUpdated:
            setUser(userState?.loggedInUser)
        }
    }

    private static var apiKey: String? {
        guard
            let rawValue = Bundle.main.object(forInfoDictionaryKey: Constants.apiKeyInfoDictionaryKey) as? String,
            let trimmedValue = rawValue.sqNonEmptyTrimmed,
            !trimmedValue.contains("$(")
        else {
            return nil
        }

        return trimmedValue
    }
}

private extension SQAnalyticsEvent {
    var logSuffix: String {
        guard let properties, !properties.isEmpty else { return "" }
        return " properties: \(properties.logSummary)"
    }
}

private extension String {
    var sqNonEmptyTrimmed: String? {
        let trimmedValue = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedValue.isEmpty ? nil : trimmedValue
    }
}

private extension Dictionary where Key == String, Value == Any {
    var logSummary: String {
        keys.sorted().compactMap { key in
            guard let value = self[key] else { return nil }
            return "\(key)=\(String(describing: value))"
        }
        .joined(separator: ", ")
    }
}

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

enum SQAnalyticsAuthMethod: String {
    case email
    case google
}

enum SQAnalyticsMetricSaveAction: String {
    case create
    case edit
}

enum SQAnalyticsEvent {
    case appOpened
    case authStateChanged(isLoggedIn: Bool)
    case dashboardRouteOpened(route: SQNavRoute.DashboardRoute)
    case loginSucceeded(method: SQAnalyticsAuthMethod)
    case signupSucceeded(method: SQAnalyticsAuthMethod)
    case onboardingCompleted(unitSystem: SQUnitSystem, includesDateOfBirth: Bool)
    case profileUpdated(source: String)
    case logout
    case metricSaved(action: SQAnalyticsMetricSaveAction, definition: SQMetricDefinition)
    case metricTrackingChanged(isEnabled: Bool, definition: SQMetricDefinition)
    case metricArchived(definition: SQMetricDefinition)
    case dailyCheckInSubmitted(
        period: SQMetricPeriod,
        metricIds: [String],
        customMetricCount: Int,
        hasNotes: Bool,
        isPastDateEntry: Bool
    )
    case dashboardTimeRangeChanged(timeRange: AppTimeRange)
    case dashboardItemOpened(itemType: String, itemId: String?, sourceGroup: String?, score: Int?)
    case leaderboardOpened(mode: SQLeaderboardMode, sourceScreen: String)
    case workoutSummaryViewed(workout: SQWorkoutSessionable, entryMode: String)
    case workoutReviewSubmitted(
        workout: SQWorkoutSessionable,
        hasWeather: Bool,
        hasPerformanceScore: Bool,
        hasDifficultyScore: Bool,
        hasNotes: Bool
    )
    case workoutEditTapped(workout: SQWorkoutSessionable, sourceScreen: String)
    case workoutDeleteTapped(workout: SQWorkoutSessionable, sourceScreen: String)
    case workoutDeleted(workout: SQWorkoutSessionable, sourceScreen: String)
    case settingsActionTaken(action: String)
    case unitsChanged(unitSystem: SQUnitSystem)
    case metricDetailViewed(metricId: String, definition: SQMetricDefinition?, sourceScreen: String)
    case insightOpened(
        insightId: String?,
        insightType: String,
        sourceScreen: String,
        insightCategory: String?
    )

    var name: String {
        switch self {
        case .appOpened:
            return "app_opened"
        case .authStateChanged:
            return "auth_state_changed"
        case .dashboardRouteOpened:
            return "dashboard_route_opened"
        case .loginSucceeded:
            return "login_succeeded"
        case .signupSucceeded:
            return "signup_succeeded"
        case .onboardingCompleted:
            return "onboarding_completed"
        case .profileUpdated:
            return "profile_updated"
        case .logout:
            return "logout"
        case .metricSaved:
            return "metric_saved"
        case .metricTrackingChanged:
            return "metric_tracking_changed"
        case .metricArchived:
            return "metric_archived"
        case .dailyCheckInSubmitted:
            return "daily_check_in_submitted"
        case .dashboardTimeRangeChanged:
            return "dashboard_time_range_changed"
        case .dashboardItemOpened:
            return "dashboard_item_opened"
        case .leaderboardOpened:
            return "leaderboard_opened"
        case .workoutSummaryViewed:
            return "workout_summary_viewed"
        case .workoutReviewSubmitted:
            return "workout_review_submitted"
        case .workoutEditTapped:
            return "workout_edit_tapped"
        case .workoutDeleteTapped:
            return "workout_delete_tapped"
        case .workoutDeleted:
            return "workout_deleted"
        case .settingsActionTaken:
            return "settings_action_taken"
        case .unitsChanged:
            return "units_changed"
        case .metricDetailViewed:
            return "metric_detail_viewed"
        case .insightOpened:
            return "insight_opened"
        }
    }

    var properties: [String: Any]? {
        switch self {
        case .appOpened:
            return nil

        case .authStateChanged(let isLoggedIn):
            return ["is_logged_in": isLoggedIn]

        case .dashboardRouteOpened(let route):
            return route.analyticsProperties

        case .loginSucceeded(let method), .signupSucceeded(let method):
            return ["auth_method": method.rawValue]

        case .onboardingCompleted(let unitSystem, let includesDateOfBirth):
            return [
                "unit_system": unitSystem.rawValue,
                "includes_date_of_birth": includesDateOfBirth
            ]

        case .profileUpdated(let source):
            return ["source": source]

        case .logout:
            return nil

        case .metricSaved(let action, let definition):
            return definition.analyticsProperties(more: ["action": action.rawValue])

        case .metricTrackingChanged(let isEnabled, let definition):
            return definition.analyticsProperties(more: [
                "action": isEnabled ? "enabled" : "disabled",
                "is_enabled": isEnabled
            ])

        case .metricArchived(let definition):
            return definition.analyticsProperties(more: ["action": "archived"])

        case .dailyCheckInSubmitted(let period, let metricIds, let customMetricCount, let hasNotes, let isPastDateEntry):
            return [
                "period": period.rawValue.analyticsKey,
                "metric_count": metricIds.count,
                "metric_ids": metricIds.sorted().joined(separator: ","),
                "custom_metric_count": customMetricCount,
                "has_notes": hasNotes,
                "is_past_date_entry": isPastDateEntry
            ]

        case .dashboardTimeRangeChanged(let timeRange):
            return ["time_range": timeRange.analyticsValue]

        case .dashboardItemOpened(let itemType, let itemId, let sourceGroup, let score):
            return dictionary([
                "item_type": itemType,
                "item_id": itemId,
                "source_group": sourceGroup,
                "score": score
            ])

        case .leaderboardOpened(let mode, let sourceScreen):
            return mode.analyticsProperties(more: ["source_screen": sourceScreen])

        case .workoutSummaryViewed(let workout, let entryMode):
            return workout.analyticsProperties(more: ["entry_mode": entryMode])

        case .workoutReviewSubmitted(let workout, let hasWeather, let hasPerformanceScore, let hasDifficultyScore, let hasNotes):
            return workout.analyticsProperties(more: [
                "has_weather": hasWeather,
                "has_performance_score": hasPerformanceScore,
                "has_difficulty_score": hasDifficultyScore,
                "has_notes": hasNotes
            ])

        case .workoutEditTapped(let workout, let sourceScreen),
             .workoutDeleteTapped(let workout, let sourceScreen),
             .workoutDeleted(let workout, let sourceScreen):
            return workout.analyticsProperties(more: ["source_screen": sourceScreen])

        case .settingsActionTaken(let action):
            return ["action": action]

        case .unitsChanged(let unitSystem):
            return ["unit_system": unitSystem.rawValue]

        case .metricDetailViewed(let metricId, let definition, let sourceScreen):
            var properties = definition?.analyticsProperties() ?? ["metric_id": metricId]
            properties["source_screen"] = sourceScreen
            return properties

        case .insightOpened(let insightId, let insightType, let sourceScreen, let insightCategory):
            return dictionary([
                "insight_id": insightId,
                "insight_type": insightType,
                "source_screen": sourceScreen,
                "insight_category": insightCategory
            ])
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

        hub.domainEvents
            .sink { [weak self] event in
                self?.handleDomainEvent(event)
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

        case .emailVerificationStateChanged:
            setUser(userState?.loggedInUser)

        case .profileUpdated:
            setUser(userState?.loggedInUser)
        }
    }

    private func handleDomainEvent(_ event: DomainEvent) {
        switch event {
        case .pushDashboardRoute(let route):
            track(.dashboardRouteOpened(route: route))
        case .popDashboardRoute, .dismissDashboardNavStack, .changeTab:
            break
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

extension AppTimeRange {
    var analyticsValue: String {
        rawValue.analyticsKey
    }
}

extension SQLeaderboardMode {
    var analyticsIdentifier: String {
        switch self {
        case .workoutQuantity(let quantityType, let activityType):
            return "\(activityType.name.analyticsKey)_\(quantityType.id.analyticsKey)"
        case .workoutScore(let kind, let activityType):
            return "\(activityType.name.analyticsKey)_\(kind.rawValue.analyticsKey)"
        case .vo2Max:
            return "vo2_max"
        }
    }

    func analyticsProperties(more: [String: Any] = [:]) -> [String: Any] {
        var properties: [String: Any] = [
            "leaderboard_type": analyticsType,
            "leaderboard_id": analyticsIdentifier
        ]

        switch self {
        case .workoutQuantity(let quantityType, let activityType):
            properties["activity_type"] = activityType.name.analyticsKey
            properties["metric_type"] = quantityType.id.analyticsKey
        case .workoutScore(let kind, let activityType):
            properties["activity_type"] = activityType.name.analyticsKey
            properties["metric_type"] = kind.rawValue.analyticsKey
        case .vo2Max:
            break
        }

        more.forEach { properties[$0.key] = $0.value }
        return properties
    }

    private var analyticsType: String {
        switch self {
        case .workoutQuantity:
            return "workout_quantity"
        case .workoutScore:
            return "workout_score"
        case .vo2Max:
            return "vo2_max"
        }
    }
}

private extension SQAnalyticsEvent {
    var logSuffix: String {
        guard let properties, !properties.isEmpty else { return "" }
        return " properties: \(properties.logSummary)"
    }
}

private extension SQNavRoute.DashboardRoute {
    var analyticsProperties: [String: Any] {
        var properties: [String: Any] = ["route": analyticsRouteName]

        switch self {
        case .insightDetail(let model):
            properties["insight_id"] = model.id
            properties["insight_category"] = model.category.rawValue.analyticsKey
        case .dashboardSubsectionLayout(_, let groupId):
            properties["group_id"] = groupId
        default:
            break
        }

        return properties
    }

    var analyticsRouteName: String {
        switch self {
        case .workoutsList:
            return "workouts_list"
        case .workoutSummary:
            return "workout_summary"
        case .workoutInsightDetail:
            return "workout_insight_detail"
        case .insightDetail:
            return "insight_detail"
        case .webContent:
            return "web_content"
        case .lifeScoreDetail:
            return "life_score_detail"
        case .workoutReview:
            return "workout_review"
        case .editWorkout:
            return "edit_workout"
        case .leaderboard:
            return "leaderboard"
        case .sleepPhaseTrends:
            return "sleep_phase_trends"
        case .launchTutorial:
            return "launch_tutorial"
        case .metricDetail:
            return "metric_detail"
        case .profile:
            return "profile"
        case .login:
            return "login"
        case .deleteAccount:
            return "delete_account"
        case .onboarding:
            return "onboarding"
        case .settings:
            return "settings"
        case .dashboardLayout:
            return "dashboard_layout"
        case .dashboardSubsectionLayout:
            return "dashboard_subsection_layout"
        }
    }
}

private extension SQMetricDefinition {
    func analyticsProperties(more: [String: Any] = [:]) -> [String: Any] {
        var properties: [String: Any] = [
            "metric_id": id,
            "metric_kind": kind.rawValue,
            "metric_unit": unit.rawValue,
            "metric_group": group,
            "is_custom_metric": !isPreset,
            "is_enabled": isEnabled,
            "goal_style": goalStyle.rawValue,
            "body_battery_effect": bodyBatteryEffect.rawValue,
            "periods": periods.map(\.rawValue).sorted().joined(separator: ","),
            "is_single_daily_value": isSingleDailyValue
        ]

        more.forEach { properties[$0.key] = $0.value }
        return properties
    }
}

private extension SQWorkoutSessionable {
    func analyticsProperties(more: [String: Any] = [:]) -> [String: Any] {
        var properties: [String: Any] = [
            "workout_id": id,
            "activity_type": activityType.name.analyticsKey,
            "workout_source": workoutSource.rawSource.rawValue
        ]

        more.forEach { properties[$0.key] = $0.value }
        return properties
    }
}

extension String {
    var sqNonEmptyTrimmed: String? {
        let trimmedValue = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedValue.isEmpty ? nil : trimmedValue
    }

    var analyticsKey: String {
        let normalized = lowercased()
            .replacingOccurrences(of: "[^a-z0-9]+", with: "_", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: "_"))

        return normalized.isEmpty ? "unknown" : normalized
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

private func dictionary(_ values: [String: Any?]) -> [String: Any] {
    values.reduce(into: [String: Any]()) { result, entry in
        if let value = entry.value {
            result[entry.key] = value
        }
    }
}

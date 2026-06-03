//
//  SQUserDefaults.swift
//  BeastFitness
//
//  Created by Patrick Doyle on 12/17/25.
//

import Foundation

final class SQUserDefaults {
    static let shared = SQUserDefaults()
    private init() {}

    // MARK: - Keys

    /// Set of workout IDs that should be hidden from the UI
    private static let keyHiddenWorkouts = "workouts.hidden-list"

    /// Map: exerciseId -> lastUsedAtEpochSeconds
    private static let keyRecentExercisesLastUsedAt = "exercises.recents.last-used-at"

    /// Date the app was first installed on this device
    private static let keyAppInstallDate = "app.install-date"

    /// Version of the first-launch tutorial that has been completed on this device.
    private static let keyCompletedLaunchTutorialVersion = "launch.tutorial.completed-version"

    /// Persisted dashboard layout preferences
    private static let keyDashboardLayoutPreferences = "dashboard.layout.preferences"

    /// User IDs that should be forced through onboarding after a fresh signup until setup is completed.
    private static let keyPendingOnboardingUserIds = "user.pending-onboarding.ids"

    /// Local fallback for the user's preferred unit system, used in guest mode and before a profile loads.
    private static let keyPreferredUnitSystem = "settings.preferred-unit-system"

    /// Users whose existing recent workouts have already been baselined for the review sheet.
    private static let keyWorkoutReviewBaselineUserIds = "workouts.review-baseline.user-ids"

    /// Map: userId -> resend-attempt epoch seconds for email verification resends.
    private static let keyEmailVerificationResendHistory = "auth.email-verification.resend-history"

    /// Map: userId -> distinct local day keys when daily check-ins were submitted.
    private static let keyAppReviewCheckInSubmissionDays = "app-review.check-in-submission-days"

    /// Map: userId -> native review prompt request epoch seconds.
    private static let keyAppReviewPromptRequestHistory = "app-review.prompt-request-history"


    // MARK: - Private helpers (Workouts)

    private var hiddenWorkoutIds: Set<String> {
        get {
            let array = UserDefaults.standard.stringArray(forKey: Self.keyHiddenWorkouts) ?? []
            return Set(array)
        }
        set {
            UserDefaults.standard.set(Array(newValue), forKey: Self.keyHiddenWorkouts)
        }
    }

    // MARK: - Private helpers (Exercises Recents)

    private var recentExercisesLastUsedAtEpochById: [String: Double] {
        get {
            (UserDefaults.standard.dictionary(forKey: Self.keyRecentExercisesLastUsedAt) as? [String: Double]) ?? [:]
        }
        set {
            UserDefaults.standard.set(newValue, forKey: Self.keyRecentExercisesLastUsedAt)
        }
    }

    private var dashboardLayoutPreferencesData: Data? {
        get { UserDefaults.standard.data(forKey: Self.keyDashboardLayoutPreferences) }
        set { UserDefaults.standard.set(newValue, forKey: Self.keyDashboardLayoutPreferences) }
    }

    private var pendingOnboardingUserIdsValue: Set<String> {
        get { Set(UserDefaults.standard.stringArray(forKey: Self.keyPendingOnboardingUserIds) ?? []) }
        set { UserDefaults.standard.set(Array(newValue), forKey: Self.keyPendingOnboardingUserIds) }
    }

    private var preferredUnitSystemValue: SQUnitSystem? {
        get {
            guard let rawValue = UserDefaults.standard.string(forKey: Self.keyPreferredUnitSystem) else {
                return nil
            }

            return SQUnitSystem(rawValue: rawValue)
        }
        set {
            UserDefaults.standard.set(newValue?.rawValue, forKey: Self.keyPreferredUnitSystem)
        }
    }

    private var workoutReviewBaselineUserIdsValue: Set<String> {
        get { Set(UserDefaults.standard.stringArray(forKey: Self.keyWorkoutReviewBaselineUserIds) ?? []) }
        set { UserDefaults.standard.set(Array(newValue), forKey: Self.keyWorkoutReviewBaselineUserIds) }
    }

    private var emailVerificationResendHistoryValue: [String: [Double]] {
        get {
            (UserDefaults.standard.dictionary(forKey: Self.keyEmailVerificationResendHistory) as? [String: [Double]]) ?? [:]
        }
        set {
            UserDefaults.standard.set(newValue, forKey: Self.keyEmailVerificationResendHistory)
        }
    }

    private var appReviewCheckInSubmissionDaysValue: [String: [String]] {
        get {
            (UserDefaults.standard.dictionary(forKey: Self.keyAppReviewCheckInSubmissionDays) as? [String: [String]]) ?? [:]
        }
        set {
            UserDefaults.standard.set(newValue, forKey: Self.keyAppReviewCheckInSubmissionDays)
        }
    }

    private var appReviewPromptRequestHistoryValue: [String: [Double]] {
        get {
            (UserDefaults.standard.dictionary(forKey: Self.keyAppReviewPromptRequestHistory) as? [String: [Double]]) ?? [:]
        }
        set {
            UserDefaults.standard.set(newValue, forKey: Self.keyAppReviewPromptRequestHistory)
        }
    }

    // MARK: - Public API (Workouts)

    /// Returns true if the workout should be hidden from the UI
    func isWorkoutHidden(_ id: String) -> Bool {
        hiddenWorkoutIds.contains(id)
    }

    /// Hide a workout (e.g. HealthKit workout created by another app)
    func hideWorkout(_ id: String) {
        var set = hiddenWorkoutIds
        set.insert(id)
        hiddenWorkoutIds = set
    }

    /// Un-hide a workout (optional but useful)
    func unhideWorkout(_ id: String) {
        var set = hiddenWorkoutIds
        set.remove(id)
        hiddenWorkoutIds = set
    }

    /// Clear all hidden workouts (debug / reset)
    func clearHiddenWorkouts() {
        UserDefaults.standard.removeObject(forKey: Self.keyHiddenWorkouts)
    }

    /// Convenience: bulk hide
    func hideWorkouts(_ ids: [String]) {
        var set = hiddenWorkoutIds
        set.formUnion(ids)
        hiddenWorkoutIds = set
    }

    // MARK: - Public API (Exercises Recents)

    /// Returns a map of exerciseId -> lastUsedAt date
    func recentExercisesLastUsedAtById() -> [String: Date] {
        recentExercisesLastUsedAtEpochById.mapValues { Date(timeIntervalSince1970: $0) }
    }

    /// Overwrite the map of exerciseId -> lastUsedAt date
    func setRecentExercisesLastUsedAtById(_ map: [String: Date]) {
        recentExercisesLastUsedAtEpochById = map.mapValues { $0.timeIntervalSince1970 }
    }

    /// Clear all recent exercises
    func clearRecentExercises() {
        UserDefaults.standard.removeObject(forKey: Self.keyRecentExercisesLastUsedAt)
    }

    // MARK: - Public API (App Install Date)

    /// Returns the date the app was first installed. Nil only before `recordInstallDateIfNeeded()` is called.
    var appInstallDate: Date? {
        UserDefaults.standard.object(forKey: Self.keyAppInstallDate) as? Date
    }

    /// Writes the install date once. Subsequent calls are no-ops.
    func recordInstallDateIfNeeded() {
        guard UserDefaults.standard.object(forKey: Self.keyAppInstallDate) == nil else { return }
        UserDefaults.standard.set(Date(), forKey: Self.keyAppInstallDate)
    }

    // MARK: - Public API (Launch Tutorial)

    var completedLaunchTutorialVersion: Int? {
        let storedValue = UserDefaults.standard.integer(forKey: Self.keyCompletedLaunchTutorialVersion)
        return storedValue > 0 ? storedValue : nil
    }

    func hasCompletedLaunchTutorial(version: Int) -> Bool {
        guard let completedLaunchTutorialVersion else { return false }
        return completedLaunchTutorialVersion >= version
    }

    func markLaunchTutorialCompleted(version: Int) {
        UserDefaults.standard.set(version, forKey: Self.keyCompletedLaunchTutorialVersion)
    }

    func clearCompletedLaunchTutorialVersion() {
        UserDefaults.standard.removeObject(forKey: Self.keyCompletedLaunchTutorialVersion)
    }

    // MARK: - Public API (Dashboard Layout)

    func getDashboardLayoutPreferencesData() -> Data? {
        dashboardLayoutPreferencesData
    }

    func setDashboardLayoutPreferencesData(_ data: Data?) {
        dashboardLayoutPreferencesData = data
    }

    func clearDashboardLayoutPreferences() {
        UserDefaults.standard.removeObject(forKey: Self.keyDashboardLayoutPreferences)
    }

    // MARK: - Public API (Onboarding)

    var pendingOnboardingUserIds: Set<String> {
        pendingOnboardingUserIdsValue
    }

    func markPendingOnboarding(for userId: String) {
        var ids = pendingOnboardingUserIdsValue
        ids.insert(userId)
        pendingOnboardingUserIdsValue = ids
    }

    func hasPendingOnboarding(for userId: String) -> Bool {
        pendingOnboardingUserIdsValue.contains(userId)
    }

    func clearPendingOnboarding(for userId: String) {
        var ids = pendingOnboardingUserIdsValue
        ids.remove(userId)
        pendingOnboardingUserIdsValue = ids
    }

    func clearAccountScopedData(for userId: String) {
        clearHiddenWorkouts()
        clearRecentExercises()
        clearDashboardLayoutPreferences()
        clearPendingOnboarding(for: userId)
        clearWorkoutReviewBaseline(for: userId)
        clearEmailVerificationResendHistory(for: userId)
        clearAppReviewPromptHistory(for: userId)
        SQSubscriptionManager.clearWeeklyWorkoutScorePreview(for: userId)
        setPreferredUnitSystem(nil)
    }

    func hasWorkoutReviewBaseline(for userId: String) -> Bool {
        workoutReviewBaselineUserIdsValue.contains(userId)
    }

    func markWorkoutReviewBaselineEstablished(for userId: String) {
        var ids = workoutReviewBaselineUserIdsValue
        ids.insert(userId)
        workoutReviewBaselineUserIdsValue = ids
    }

    func clearWorkoutReviewBaseline(for userId: String) {
        var ids = workoutReviewBaselineUserIdsValue
        ids.remove(userId)
        workoutReviewBaselineUserIdsValue = ids
    }

    var preferredUnitSystem: SQUnitSystem? {
        preferredUnitSystemValue
    }

    func setPreferredUnitSystem(_ unitSystem: SQUnitSystem?) {
        preferredUnitSystemValue = unitSystem
    }

    // MARK: - Public API (Email Verification Resend Throttle)

    func emailVerificationResendAttemptDates(for userId: String) -> [Date] {
        let timestamps = emailVerificationResendHistoryValue[userId] ?? []
        return timestamps.map { Date(timeIntervalSince1970: $0) }.sorted()
    }

    func setEmailVerificationResendAttemptDates(_ dates: [Date], for userId: String) {
        var history = emailVerificationResendHistoryValue
        if dates.isEmpty {
            history.removeValue(forKey: userId)
        } else {
            history[userId] = dates.sorted().map(\.timeIntervalSince1970)
        }
        emailVerificationResendHistoryValue = history
    }

    func appendEmailVerificationResendAttempt(for userId: String, at date: Date = .now) {
        var dates = emailVerificationResendAttemptDates(for: userId)
        dates.append(date)
        setEmailVerificationResendAttemptDates(dates, for: userId)
    }

    func clearEmailVerificationResendHistory(for userId: String) {
        setEmailVerificationResendAttemptDates([], for: userId)
    }

    // MARK: - Public API (App Review Prompt)

    func appReviewCheckInSubmissionDayKeys(for userId: String) -> Set<String> {
        Set(appReviewCheckInSubmissionDaysValue[userId] ?? [])
    }

    func recordAppReviewCheckInSubmission(for userId: String, date: Date) {
        var history = appReviewCheckInSubmissionDaysValue
        var dayKeys = Set(history[userId] ?? [])
        dayKeys.insert(Self.appReviewDayKey(for: date))
        history[userId] = Array(dayKeys).sorted()
        appReviewCheckInSubmissionDaysValue = history
    }

    func appReviewPromptRequestDates(for userId: String) -> [Date] {
        let timestamps = appReviewPromptRequestHistoryValue[userId] ?? []
        return timestamps.map { Date(timeIntervalSince1970: $0) }.sorted()
    }

    func appendAppReviewPromptRequest(for userId: String, at date: Date = .now) {
        var history = appReviewPromptRequestHistoryValue
        var timestamps = history[userId] ?? []
        timestamps.append(date.timeIntervalSince1970)
        history[userId] = timestamps.sorted()
        appReviewPromptRequestHistoryValue = history
    }

    func clearAppReviewPromptHistory(for userId: String) {
        var checkInHistory = appReviewCheckInSubmissionDaysValue
        checkInHistory.removeValue(forKey: userId)
        appReviewCheckInSubmissionDaysValue = checkInHistory

        var requestHistory = appReviewPromptRequestHistoryValue
        requestHistory.removeValue(forKey: userId)
        appReviewPromptRequestHistoryValue = requestHistory
    }

    private static func appReviewDayKey(for date: Date) -> String {
        let components = Calendar.current.dateComponents([.year, .month, .day], from: date)
        let year = components.year ?? 0
        let month = components.month ?? 0
        let day = components.day ?? 0
        return String(format: "%04d-%02d-%02d", year, month, day)
    }
}

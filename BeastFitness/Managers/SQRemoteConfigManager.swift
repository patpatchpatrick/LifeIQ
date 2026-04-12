//
//  SQRemoteConfigManager.swift
//  BeastFitness
//
//  Created by Codex on 4/9/26.
//

import BeastFitnessCore
import FirebaseRemoteConfig
import Foundation
import Observation

struct SQRemoteConfigSnapshot: Equatable {
    let appDisabled: Bool
    let appDisabledMessage: String
    let writesDisabled: Bool
    let writesDisabledMessage: String
    let signupDisabled: Bool
    let signupDisabledMessage: String
    let minSupportedBuild: Int?
    let forceUpdateMessage: String
    let requiresForceUpdate: Bool

    static let `default` = SQRemoteConfigSnapshot(
        appDisabled: false,
        appDisabledMessage: SQRemoteConfigManager.FallbackMessages.appDisabled,
        writesDisabled: false,
        writesDisabledMessage: SQRemoteConfigManager.FallbackMessages.writesDisabled,
        signupDisabled: false,
        signupDisabledMessage: SQRemoteConfigManager.FallbackMessages.signupDisabled,
        minSupportedBuild: nil,
        forceUpdateMessage: SQRemoteConfigManager.FallbackMessages.forceUpdate,
        requiresForceUpdate: false
    )
}

@MainActor
protocol SQRemoteConfigManaging: AnyObject {
    var snapshot: SQRemoteConfigSnapshot { get }
    func configure()
    func addSnapshotObserver(_ observer: @escaping (SQRemoteConfigSnapshot) -> Void) -> UUID
    func removeSnapshotObserver(_ id: UUID)
    func refreshForCriticalStateCheck()
}

@MainActor
@Observable
final class SQRemoteConfigManager: SQRemoteConfigManaging {
    enum FallbackMessages {
        static let appDisabled = "LifeIQ is temporarily unavailable. Please try again in a little while."
        static let writesDisabled = "LifeIQ is temporarily in read-only mode while we make a quick fix."
        static let signupDisabled = "Signups are temporarily unavailable. Please try again later."
        static let forceUpdate = "A newer version of LifeIQ is required to continue."
    }

    private enum Constants {
        static let defaultsPlistName = "remote_config_defaults"
        static let productionMinimumFetchInterval: TimeInterval = 12 * 60 * 60
    }

#if DEBUG
    private enum DebugLaunchArgument {
        // Xcode: Product > Scheme > Edit Scheme... > Run > Arguments.
        // Add one of these under "Arguments Passed On Launch" to force the blocker UI locally.
        static let appDisabled = "-sq_app_disabled"
        static let forceUpdate = "-sq_force_update"
    }
#endif

    private enum Key: String, CaseIterable {
        case appDisabled = "app_disabled"
        case appDisabledMessage = "app_disabled_message"
        case writesDisabled = "writes_disabled"
        case writesDisabledMessage = "writes_disabled_message"
        case signupDisabled = "signup_disabled"
        case signupDisabledMessage = "signup_disabled_message"
        case minSupportedBuild = "min_supported_build"
        case forceUpdateMessage = "force_update_message"
    }

    static let shared = SQRemoteConfigManager()

    private let remoteConfig = RemoteConfig.remoteConfig()
    private var hasConfigured = false
    private var realtimeUpdateRegistration: ConfigUpdateListenerRegistration?
    private var snapshotObservers: [UUID: (SQRemoteConfigSnapshot) -> Void] = [:]
    private(set) var snapshot = SQRemoteConfigSnapshot.default

    private init() {}

    func configure() {
        guard !hasConfigured else { return }
        hasConfigured = true

        let settings = RemoteConfigSettings()
#if DEBUG
        settings.minimumFetchInterval = 0
#else
        settings.minimumFetchInterval = Constants.productionMinimumFetchInterval
#endif
        remoteConfig.configSettings = settings
        remoteConfig.setDefaults(fromPlist: Constants.defaultsPlistName)

        refreshSnapshot(source: "defaults")
        fetchAndActivate()
        startRealtimeUpdates()

        SQLogger.shared.log(
            "Remote Config initialized",
            .info,
            context: .general
        )
    }

    func addSnapshotObserver(_ observer: @escaping (SQRemoteConfigSnapshot) -> Void) -> UUID {
        let observerId = UUID()
        snapshotObservers[observerId] = observer
        return observerId
    }

    func removeSnapshotObserver(_ id: UUID) {
        snapshotObservers.removeValue(forKey: id)
    }

    func refreshForCriticalStateCheck() {
        guard hasConfigured else { return }

        remoteConfig.fetch(withExpirationDuration: 0) { [weak self] status, error in
            Task { @MainActor [weak self] in
                guard let self else { return }

                if let error {
                    SQLogger.shared.log(
                        "Remote Config critical refresh failed: \(error.localizedDescription)",
                        .warning,
                        context: .general
                    )
                    return
                }

                SQLogger.shared.log(
                    "Remote Config critical refresh completed with status: \(status.rawValue)",
                    .debug,
                    context: .general
                )

                self.remoteConfig.activate { [weak self] _, error in
                    Task { @MainActor [weak self] in
                        guard let self else { return }

                        if let error {
                            SQLogger.shared.log(
                                "Remote Config activate failed after critical refresh: \(error.localizedDescription)",
                                .warning,
                                context: .general
                            )
                            return
                        }

                        self.refreshSnapshot(source: "critical_refresh")
                    }
                }
            }
        }
    }

    private func fetchAndActivate() {
        remoteConfig.fetchAndActivate { [weak self] status, error in
            Task { @MainActor [weak self] in
                guard let self else { return }

                if let error {
                    SQLogger.shared.log(
                        "Remote Config fetchAndActivate failed: \(error.localizedDescription)",
                        .warning,
                        context: .general
                    )
                    return
                }

                SQLogger.shared.log(
                    "Remote Config fetchAndActivate completed with status: \(status.rawValue)",
                    .debug,
                    context: .general
                )
                self.refreshSnapshot(source: "fetch")
            }
        }
    }

    private func startRealtimeUpdates() {
        realtimeUpdateRegistration = remoteConfig.addOnConfigUpdateListener { [weak self] configUpdate, error in
            Task { @MainActor [weak self] in
                guard let self else { return }

                if let error {
                    SQLogger.shared.log(
                        "Remote Config realtime listener error: \(error.localizedDescription)",
                        .warning,
                        context: .general
                    )
                    return
                }

                guard let configUpdate else { return }

                SQLogger.shared.log(
                    "Remote Config updated keys: \(Array(configUpdate.updatedKeys).sorted().joined(separator: ", "))",
                    .debug,
                    context: .general
                )

                self.remoteConfig.activate { [weak self] _, error in
                    Task { @MainActor [weak self] in
                        guard let self else { return }

                        if let error {
                            SQLogger.shared.log(
                                "Remote Config activate failed after realtime update: \(error.localizedDescription)",
                                .warning,
                                context: .general
                            )
                            return
                        }

                        self.refreshSnapshot(source: "realtime")
                    }
                }
            }
        }

        SQLogger.shared.log(
            "Remote Config realtime listener started",
            .debug,
            context: .general
        )
    }

    private func refreshSnapshot(source: String) {
        let remoteSnapshot = SQRemoteConfigSnapshot(
            appDisabled: boolValue(for: .appDisabled),
            appDisabledMessage: fallbackMessage(
                for: .appDisabledMessage,
                fallback: FallbackMessages.appDisabled
            ),
            writesDisabled: boolValue(for: .writesDisabled),
            writesDisabledMessage: fallbackMessage(
                for: .writesDisabledMessage,
                fallback: FallbackMessages.writesDisabled
            ),
            signupDisabled: boolValue(for: .signupDisabled),
            signupDisabledMessage: fallbackMessage(
                for: .signupDisabledMessage,
                fallback: FallbackMessages.signupDisabled
            ),
            minSupportedBuild: minSupportedBuildValue(),
            forceUpdateMessage: fallbackMessage(
                for: .forceUpdateMessage,
                fallback: FallbackMessages.forceUpdate
            ),
            requiresForceUpdate: requiresForceUpdate()
        )

        let updatedSnapshot = applyDebugOverrides(to: remoteSnapshot)

        guard updatedSnapshot != snapshot else { return }
        snapshot = updatedSnapshot
        snapshotObservers.values.forEach { $0(updatedSnapshot) }

        SQLogger.shared.log(
            """
            Remote Config snapshot refreshed from \(source)
            app_disabled=\(updatedSnapshot.appDisabled)
            app_disabled_message=\(updatedSnapshot.appDisabledMessage)
            writes_disabled=\(updatedSnapshot.writesDisabled)
            writes_disabled_message=\(updatedSnapshot.writesDisabledMessage)
            signup_disabled=\(updatedSnapshot.signupDisabled)
            signup_disabled_message=\(updatedSnapshot.signupDisabledMessage)
            min_supported_build=\(updatedSnapshot.minSupportedBuild.map(String.init) ?? "nil")
            force_update_message=\(updatedSnapshot.forceUpdateMessage)
            requires_force_update=\(updatedSnapshot.requiresForceUpdate)
            """,
            .debug,
            context: .general
        )
    }

    private func applyDebugOverrides(to snapshot: SQRemoteConfigSnapshot) -> SQRemoteConfigSnapshot {
#if DEBUG
        let arguments = ProcessInfo.processInfo.arguments

        if arguments.contains(DebugLaunchArgument.forceUpdate) {
            return .init(
                appDisabled: false,
                appDisabledMessage: snapshot.appDisabledMessage,
                writesDisabled: snapshot.writesDisabled,
                writesDisabledMessage: snapshot.writesDisabledMessage,
                signupDisabled: snapshot.signupDisabled,
                signupDisabledMessage: snapshot.signupDisabledMessage,
                minSupportedBuild: snapshot.minSupportedBuild,
                forceUpdateMessage: "[Debug] A newer version of LifeIQ is required to continue.",
                requiresForceUpdate: true
            )
        }

        if arguments.contains(DebugLaunchArgument.appDisabled) {
            return .init(
                appDisabled: true,
                appDisabledMessage: "[Debug] LifeIQ is temporarily unavailable while this screen is being tested.",
                writesDisabled: snapshot.writesDisabled,
                writesDisabledMessage: snapshot.writesDisabledMessage,
                signupDisabled: snapshot.signupDisabled,
                signupDisabledMessage: snapshot.signupDisabledMessage,
                minSupportedBuild: snapshot.minSupportedBuild,
                forceUpdateMessage: snapshot.forceUpdateMessage,
                requiresForceUpdate: false
            )
        }
#endif

        return snapshot
    }

    private func boolValue(for key: Key) -> Bool {
        remoteConfig.configValue(forKey: key.rawValue).boolValue
    }

    private func stringValue(for key: Key) -> String? {
        remoteConfig.configValue(forKey: key.rawValue).stringValue.sqNonEmptyTrimmed
    }

    private func fallbackMessage(for key: Key, fallback: String) -> String {
        stringValue(for: key) ?? fallback
    }

    private func minSupportedBuildValue() -> Int? {
        guard let rawValue = stringValue(for: .minSupportedBuild) else { return nil }
        guard let buildNumber = Int(rawValue), buildNumber > 0 else { return nil }
        return buildNumber
    }

    private func requiresForceUpdate() -> Bool {
        guard let minSupportedBuild = minSupportedBuildValue() else { return false }
        // Force-update compares against CFBundleVersion (build number), not CFBundleShortVersionString.
        guard let currentBuildRaw = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String else {
            return false
        }
        guard let currentBuild = Int(currentBuildRaw) else { return false }
        return currentBuild < minSupportedBuild
    }
}

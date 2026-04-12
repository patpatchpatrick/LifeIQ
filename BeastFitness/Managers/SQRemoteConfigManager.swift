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
        remoteConfig.addOnConfigUpdateListener { [weak self] configUpdate, error in
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
                    "Remote Config updated keys: \(Array(configUpdate.updatedKeys).sorted().joined(separator: \", \"))",
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
    }

    private func refreshSnapshot(source: String) {
        let updatedSnapshot = SQRemoteConfigSnapshot(
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

        guard updatedSnapshot != snapshot else { return }
        snapshot = updatedSnapshot

        SQLogger.shared.log(
            "Remote Config snapshot refreshed from \(source)",
            .debug,
            context: .general
        )
    }

    private func boolValue(for key: Key) -> Bool {
        remoteConfig.configValue(forKey: key.rawValue).boolValue
    }

    private func stringValue(for key: Key) -> String? {
        remoteConfig.configValue(forKey: key.rawValue).stringValue?.sqNonEmptyTrimmed
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
        guard let currentBuildRaw = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String else {
            return false
        }
        guard let currentBuild = Int(currentBuildRaw) else { return false }
        return currentBuild < minSupportedBuild
    }
}

private extension String {
    var sqNonEmptyTrimmed: String? {
        let trimmedValue = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedValue.isEmpty ? nil : trimmedValue
    }
}

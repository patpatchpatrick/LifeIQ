//
//  SQAppBlockerState.swift
//  BeastFitness
//
//  Created by Codex on 4/10/26.
//

import BeastFitnessCore
import Foundation
import Observation
import UIKit

struct SQAppBlockerViewModel: Equatable {
    enum Kind: String, Equatable {
        case appDisabled
        case forceUpdate
    }

    let kind: Kind
    let title: String
    let message: String
    let primaryButtonTitle: String?
}

@MainActor
@Observable
final class SQAppBlockerState {
    private enum Constants {
        // TODO: - PTD Replace with the app-specific App Store URL once the production listing exists.
        static let appStoreURLString = "itms-apps://apps.apple.com/"
    }

    private let remoteConfigManager: any SQRemoteConfigManaging

    var onVisibilityChanged: ((Bool) -> Void)?
    private(set) var current: SQAppBlockerViewModel? {
        didSet {
            onVisibilityChanged?(isPresented)
        }
    }

    var isPresented: Bool { current != nil }

    init(remoteConfigManager: any SQRemoteConfigManaging = SQRemoteConfigManager.shared) {
        self.remoteConfigManager = remoteConfigManager
        self.current = Self.makeViewModel(from: remoteConfigManager.snapshot)

        _ = remoteConfigManager.addSnapshotObserver { [weak self] snapshot in
            self?.current = Self.makeViewModel(from: snapshot)
        }
    }

    func handlePrimaryAction() {
        guard let current else { return }

        switch current.kind {
        case .appDisabled:
            return
        case .forceUpdate:
            openAppStore()
        }
    }

    private func openAppStore() {
        guard let url = URL(string: Constants.appStoreURLString) else {
            SQLogger.shared.log(
                "App blocker could not open App Store because the URL is invalid",
                .warning,
                context: .general
            )
            return
        }

        UIApplication.shared.open(url)
    }

    private static func makeViewModel(from snapshot: SQRemoteConfigSnapshot) -> SQAppBlockerViewModel? {
        if snapshot.requiresForceUpdate {
            return .init(
                kind: .forceUpdate,
                title: "Update Required",
                message: snapshot.forceUpdateMessage,
                primaryButtonTitle: "Open App Store"
            )
        }

        if snapshot.appDisabled {
            return .init(
                kind: .appDisabled,
                title: "LifeIQ Is Temporarily Unavailable",
                message: snapshot.appDisabledMessage,
                primaryButtonTitle: nil
            )
        }

        return nil
    }
}

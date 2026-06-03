//
//  SQAppReviewPromptManager.swift
//  BeastFitness
//
//  Created by Codex on 6/3/26.
//

import BeastFitnessCore
import Foundation
import StoreKit
import UIKit

@MainActor
protocol SQAppReviewPromptManaging: AnyObject {
    func dailyCheckInSubmitted(user: SQUser?, date: Date, isPastDateEntry: Bool)
}

@MainActor
final class SQAppReviewPromptManager: SQAppReviewPromptManaging {
    private enum Constants {
        static let requiredDistinctCheckInDays = 3
        static let requestDelay: Duration = .seconds(1)
    }

    private let defaults: SQUserDefaults

    init(defaults: SQUserDefaults = .shared) {
        self.defaults = defaults
    }

    func dailyCheckInSubmitted(user: SQUser?, date: Date, isPastDateEntry: Bool) {
        guard let user else {
            return
        }

        let email = user.email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !SQAdminConfig.appReviewPromptExcludedEmails.contains(email) else { return }

        let userId = user.id
        guard !userId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

        defaults.recordAppReviewCheckInSubmission(for: userId, date: date)

        guard !isPastDateEntry else { return }
        guard defaults.appReviewPromptRequestDates(for: userId).isEmpty else { return }

        let completedDayCount = defaults.appReviewCheckInSubmissionDayKeys(for: userId).count
        guard completedDayCount >= Constants.requiredDistinctCheckInDays else { return }

        requestNativeReviewPromptSoon(for: userId)
    }

    private func requestNativeReviewPromptSoon(for userId: String) {
        Task { @MainActor in
            try? await Task.sleep(for: Constants.requestDelay)

            guard UIApplication.shared.applicationState == .active,
                  let scene = activeWindowScene else {
                SQLogger.shared.log(
                    "Skipped App Store review prompt because no active window scene was available",
                    .debug,
                    context: .general
                )
                return
            }

            defaults.appendAppReviewPromptRequest(for: userId, at: .now)
            SKStoreReviewController.requestReview(in: scene)
            SQLogger.shared.log(
                "Requested native App Store review prompt",
                .info,
                context: .general
            )
        }
    }

    private var activeWindowScene: UIWindowScene? {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        return scenes.first { scene in
            scene.activationState == .foregroundActive && scene.windows.contains(where: \.isKeyWindow)
        } ?? scenes.first { $0.activationState == .foregroundActive }
    }
}

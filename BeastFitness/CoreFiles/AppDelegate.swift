//
//  AppDelegate.swift
//  BeastFitness
//
//  Created by Patrick Doyle on 10/8/24.
//

import Foundation
import UIKit
import FirebaseCore
import FirebaseCrashlytics
import GoogleSignIn

class AppDelegate: NSObject, UIApplicationDelegate {
    private enum FirebaseEnvironment: String {
        case staging
        case prod

        var plistName: String {
            switch self {
            case .staging:
                return "GoogleService-Info-Staging"
            case .prod:
                return "GoogleService-Info-Prod"
            }
        }
    }

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        configureFirebase()
        return true
    }

    func application(
        _ app: UIApplication,
        open url: URL,
        options: [UIApplication.OpenURLOptionsKey: Any] = [:]
    ) -> Bool {
        SQAuthManager.shared.handleGoogleSignIn(url: url)
    }

    private func configureFirebase() {
        guard FirebaseApp.app() == nil else { return }

        let environment = configuredFirebaseEnvironment()

        guard
            let path = Bundle.main.path(forResource: environment.plistName, ofType: "plist"),
            let options = FirebaseOptions(contentsOfFile: path)
        else {
            fatalError("Missing Firebase configuration for \(environment.rawValue).")
        }

        FirebaseApp.configure(options: options)
        Crashlytics.crashlytics().log("Firebase configured for \(environment.rawValue)")
    }

    private func configuredFirebaseEnvironment() -> FirebaseEnvironment {
        guard
            let rawValue = Bundle.main.object(forInfoDictionaryKey: "LIFEIQ_FIREBASE_ENVIRONMENT") as? String,
            let environment = FirebaseEnvironment(rawValue: rawValue)
        else {
            fatalError("Missing LIFEIQ_FIREBASE_ENVIRONMENT build configuration.")
        }

        return environment
    }
}

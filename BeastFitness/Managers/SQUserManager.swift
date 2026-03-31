//
//  SQUserManager.swift
//  BeastFitness
//
//  Created by Patrick Doyle on 3/21/26.
//

import Foundation
import FirebaseAuth
import BeastFitnessCore

@MainActor
protocol SQUserManaging: AnyObject {
    func handleAuthStateChange(firebaseUser: FirebaseAuth.User?, userState: SQUserState) async
    func createUserDocument(uid: String, email: String) async throws -> SQUser
    func saveUser(_ user: SQUser) async throws -> SQUser
    func fetchUser(uid: String) async throws -> SQUser
}

@MainActor
final class SQUserManager: SQUserManaging {
    static let shared = SQUserManager()

    private init() {}

    // MARK: - Auth State

    /// Called by SQAuthManager's state listener. Updates SQUserState based on the current Firebase user.
    /// For login: sets user from Firebase Auth data directly (no Firestore fetch required until richer profile is needed).
    /// For logout: clears login state.
    func handleAuthStateChange(firebaseUser: FirebaseAuth.User?, userState: SQUserState) async {
        guard let firebaseUser = firebaseUser else {
            userState.setLoggedOut()
            SQLogger.shared.log("Auth state: user logged out", .info, context: .network)
            return
        }

        do {
            let user = try await SQUserService.fetchUser(uid: firebaseUser.uid)
            if user.onboardingStatus == .completed {
                SQUserDefaults.shared.clearPendingOnboarding(for: user.id)
            }
            userState.setLoggedIn(user, hasLoadedProfile: true)
            SQLogger.shared.log("✅ Auth state: user logged in with remote profile (\(firebaseUser.uid))", .info, context: .network, isPriority: true)
        } catch {
            let fallbackUser = SQUser(
                id: firebaseUser.uid,
                name: firebaseUser.displayName ?? "",
                email: firebaseUser.email ?? "",
                firstName: nil,
                lastName: nil,
                dateOfBirth: nil,
                heightInInches: nil,
                weightInPounds: nil,
                sleepSchedule: nil,
                subscriptionLevel: nil,
                onboardingCompletedAt: nil,
                onboardingStatus: nil
            )
            userState.setLoggedIn(fallbackUser, hasLoadedProfile: false)
            SQLogger.shared.log("Auth state: using fallback user profile for \(firebaseUser.uid): \(error)", .warning, context: .network)
        }

        if let modelContext = SQAppState.shared.modelContext {
            await SQWorkoutManager.shared.syncWorkoutsIfNeeded(context: modelContext, force: true)
        }
    }

    // MARK: - User Document

    /// Creates the user's Firestore document after signup.
    func createUserDocument(uid: String, email: String) async throws -> SQUser {
        let user = try await SQUserService.createUser(uid: uid, email: email)
        SQLogger.shared.log("✅ Created user document for \(uid)", .info, context: .network)
        return user
    }

    func saveUser(_ user: SQUser) async throws -> SQUser {
        let savedUser = try await SQUserService.saveUser(user)
        SQLogger.shared.log("✅ Saved user document for \(user.id)", .info, context: .network)
        return savedUser
    }

    func fetchUser(uid: String) async throws -> SQUser {
        try await SQUserService.fetchUser(uid: uid)
    }
}

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

        let user = SQUser(id: firebaseUser.uid, name: "", email: firebaseUser.email ?? "")
        userState.setLoggedIn(user)
        SQLogger.shared.log("✅ Auth state: user logged in (\(firebaseUser.uid))", .info, context: .network, isPriority: true)

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
}

//
//  SQAuthManager.swift
//  BeastFitness
//
//  Created by Patrick Doyle on 3/21/26.
//

import Foundation
import FirebaseAuth

@MainActor
protocol SQAuthManaging: AnyObject {
    func signIn(email: String, password: String) async throws -> AuthDataResult
    func createUser(email: String, password: String) async throws -> AuthDataResult
    func signOut() throws
}

@MainActor
final class SQAuthManager: SQAuthManaging {
    static let shared = SQAuthManager()

    private var authStateHandle: AuthStateDidChangeListenerHandle?

    private init() {}

    // MARK: - Auth State Listener

    /// Starts listening to Firebase auth state changes. Call once at app launch.
    /// Fires immediately with the current auth state, handling session persistence across app restarts.
    func startListening(userState: SQUserState) {
        authStateHandle = Auth.auth().addStateDidChangeListener { _, firebaseUser in
            Task { @MainActor in
                await SQUserManager.shared.handleAuthStateChange(firebaseUser: firebaseUser, userState: userState)
            }
        }
    }

    // MARK: - Auth Operations

    func signIn(email: String, password: String) async throws -> AuthDataResult {
        try await Auth.auth().signIn(withEmail: email, password: password)
    }

    func createUser(email: String, password: String) async throws -> AuthDataResult {
        try await Auth.auth().createUser(withEmail: email, password: password)
    }

    func signOut() throws {
        try Auth.auth().signOut()
    }
}

// MARK: - Auth Error

struct SQAuthError: SQUserFacingError {
    let userFacingTitle: String
    let userFacingDescription: String

    init(description: String, title: String = "Authentication Error") {
        self.userFacingTitle = title
        self.userFacingDescription = description
    }

    static func from(_ error: Error) -> SQAuthError {
        let code = AuthErrorCode(_bridgedNSError: error as NSError)
        switch code?.code {
        case .emailAlreadyInUse:
            return .init(description: "An account with this email already exists.")
        case .invalidEmail:
            return .init(description: "Please enter a valid email address.")
        case .weakPassword:
            return .init(description: "Please choose a stronger password.")
        case .wrongPassword, .invalidCredential:
            return .init(description: "Incorrect email or password.")
        case .userNotFound:
            return .init(description: "No account found with this email.")
        case .networkError:
            return .init(description: "Please check your connection and try again.")
        case .tooManyRequests:
            return .init(description: "Too many attempts. Please try again later.")
        default:
            return .init(description: "Something went wrong. Please try again.")
        }
    }
}

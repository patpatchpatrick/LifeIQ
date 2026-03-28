//
//  SQAuthManager.swift
//  BeastFitness
//
//  Created by Patrick Doyle on 3/21/26.
//

import Foundation
import FirebaseAuth
import FirebaseCore
import GoogleSignIn
import UIKit

@MainActor
protocol SQAuthManaging: AnyObject {
    func signIn(email: String, password: String) async throws -> AuthDataResult
    func createUser(email: String, password: String) async throws -> AuthDataResult
    func signInWithGoogle(presentingViewController: UIViewController) async throws -> AuthDataResult
    func handleGoogleSignIn(url: URL) -> Bool
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

        Task { @MainActor in
            try? await Task.sleep(for: .seconds(5))
            guard !userState.hasResolvedInitialAuthState else { return }
            userState.setLoggedOut()
        }
    }

    // MARK: - Auth Operations

    func signIn(email: String, password: String) async throws -> AuthDataResult {
        try await Auth.auth().signIn(withEmail: email, password: password)
    }

    func createUser(email: String, password: String) async throws -> AuthDataResult {
        try await Auth.auth().createUser(withEmail: email, password: password)
    }

    func signInWithGoogle(presentingViewController: UIViewController) async throws -> AuthDataResult {
        guard let clientID = FirebaseApp.app()?.options.clientID else {
            throw SQAuthError(description: "Google Sign-In is not configured for this app.")
        }

        GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientID)

        let signInResult: GIDSignInResult
        do {
            signInResult = try await GIDSignIn.sharedInstance.signIn(withPresenting: presentingViewController)
        } catch {
            throw SQAuthError.fromGoogle(error)
        }

        let googleUser = signInResult.user
        guard let idToken = googleUser.idToken?.tokenString else {
            throw SQAuthError(description: "Google Sign-In did not return an ID token.")
        }

        let credential = GoogleAuthProvider.credential(
            withIDToken: idToken,
            accessToken: googleUser.accessToken.tokenString
        )

        return try await Auth.auth().signIn(with: credential)
    }

    func handleGoogleSignIn(url: URL) -> Bool {
        GIDSignIn.sharedInstance.handle(url)
    }

    func signOut() throws {
        GIDSignIn.sharedInstance.signOut()
        try Auth.auth().signOut()
    }
}

// MARK: - Auth Error

struct SQAuthError: SQUserFacingError {
    let userFacingTitle: String
    let userFacingDescription: String
    let shouldPresentToUser: Bool

    init(description: String, title: String = "Authentication Error", shouldPresentToUser: Bool = true) {
        self.userFacingTitle = title
        self.userFacingDescription = description
        self.shouldPresentToUser = shouldPresentToUser
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

    static func fromGoogle(_ error: Error) -> SQAuthError {
        if let error = error as? SQAuthError {
            return error
        }

        let nsError = error as NSError
        let localizedDescription = nsError.localizedDescription.lowercased()
        if nsError.domain == kGIDSignInErrorDomain,
           (localizedDescription.contains("canceled") || localizedDescription.contains("cancelled")) {
            return .init(description: "Google Sign-In was canceled.", shouldPresentToUser: false)
        }

        return .init(description: nsError.localizedDescription)
    }
}

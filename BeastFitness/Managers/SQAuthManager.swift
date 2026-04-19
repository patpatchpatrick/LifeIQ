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

enum SQAuthProvider: String, CaseIterable, Hashable {
    case password = "password"
    case google = "google.com"

    init?(providerId: String) {
        self.init(rawValue: providerId)
    }
}

enum SQAccountDeletionReauthenticationMethod {
    case password(String)
    case google
}

@MainActor
protocol SQAuthManaging: AnyObject {
    func signIn(email: String, password: String) async throws -> AuthDataResult
    func createUser(email: String, password: String) async throws -> AuthDataResult
    func signInWithGoogle(presentingViewController: UIViewController) async throws -> AuthDataResult
    func sendEmailVerification() async throws
    func sendEmailVerification(to user: FirebaseAuth.User) async throws
    func reloadCurrentUser() async throws -> FirebaseAuth.User
    func handleGoogleSignIn(url: URL) -> Bool
    func currentAuthProviders() -> Set<SQAuthProvider>
    func reauthenticateForAccountDeletion(using method: SQAccountDeletionReauthenticationMethod) async throws
    func revokeGoogleAccessIfNeeded() async throws
    func deleteCurrentUser() async throws
    func signOut() throws
}

@MainActor
final class SQAuthManager: SQAuthManaging {
    static let shared = SQAuthManager()
    static let reservedSignupEmailDomains: Set<String> = ["lifeiq.app"]

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
        try SQRemoteConfigManager.shared.assertSignupEnabled()
        try Self.assertEmailAllowedForPublicSignup(email)
        return try await Auth.auth().createUser(withEmail: email, password: password)
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

    func sendEmailVerification() async throws {
        guard let currentUser = Auth.auth().currentUser else {
            throw SQAuthError(description: "You need to be signed in to verify your email.")
        }

        try await sendEmailVerification(to: currentUser)
    }

    func sendEmailVerification(to user: FirebaseAuth.User) async throws {
        try await user.sendEmailVerification()
    }

    func reloadCurrentUser() async throws -> FirebaseAuth.User {
        guard let currentUser = Auth.auth().currentUser else {
            throw SQAuthError(description: "You need to be signed in to refresh your email verification status.")
        }

        try await currentUser.reload()

        guard let reloadedUser = Auth.auth().currentUser else {
            throw SQAuthError(description: "Your session expired. Please log in again.")
        }

        return reloadedUser
    }

    func handleGoogleSignIn(url: URL) -> Bool {
        GIDSignIn.sharedInstance.handle(url)
    }

    func currentAuthProviders() -> Set<SQAuthProvider> {
        let providerIds = Auth.auth().currentUser?.providerData.map(\.providerID) ?? []
        return Set(providerIds.compactMap(SQAuthProvider.init(providerId:)))
    }

    func reauthenticateForAccountDeletion(using method: SQAccountDeletionReauthenticationMethod) async throws {
        guard let currentUser = Auth.auth().currentUser else {
            throw SQAuthError(description: "You need to be signed in to delete your account.")
        }

        switch method {
        case .password(let password):
            guard let email = currentUser.email?.trimmingCharacters(in: .whitespacesAndNewlines), !email.isEmpty else {
                throw SQAuthError(description: "This account does not have an email address available for password confirmation.")
            }

            let credential = EmailAuthProvider.credential(withEmail: email, password: password)
            try await currentUser.reauthenticate(with: credential)

        case .google:
            guard let clientID = FirebaseApp.app()?.options.clientID else {
                throw SQAuthError(description: "Google Sign-In is not configured for this app.")
            }

            let presentingViewController = try currentPresentingViewController()
            GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientID)

            let signInResult: GIDSignInResult
            do {
                signInResult = try await GIDSignIn.sharedInstance.signIn(withPresenting: presentingViewController)
            } catch {
                throw SQAuthError.fromGoogle(error)
            }

            guard let idToken = signInResult.user.idToken?.tokenString else {
                throw SQAuthError(description: "Google Sign-In did not return an ID token.")
            }

            let credential = GoogleAuthProvider.credential(
                withIDToken: idToken,
                accessToken: signInResult.user.accessToken.tokenString
            )

            try await currentUser.reauthenticate(with: credential)
        }
    }

    func revokeGoogleAccessIfNeeded() async throws {
        guard currentAuthProviders().contains(.google) else { return }

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            GIDSignIn.sharedInstance.disconnect { error in
                if let error {
                    continuation.resume(throwing: SQAuthError.fromGoogle(error))
                } else {
                    continuation.resume(returning: ())
                }
            }
        }
    }

    func deleteCurrentUser() async throws {
        guard let currentUser = Auth.auth().currentUser else {
            throw SQAuthError(description: "You need to be signed in to delete your account.")
        }

        try await currentUser.delete()
    }

    func signOut() throws {
        GIDSignIn.sharedInstance.signOut()
        try Auth.auth().signOut()
    }

    private func currentPresentingViewController() throws -> UIViewController {
        guard let scene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive }),
              let rootViewController = scene.windows.first(where: \.isKeyWindow)?.rootViewController else {
            throw SQAuthError(description: "Could not start Google Sign-In because no active view was available.")
        }

        var presentingViewController = rootViewController
        while let presentedViewController = presentingViewController.presentedViewController {
            presentingViewController = presentedViewController
        }

        return presentingViewController
    }

    static func isReservedPublicSignupEmail(_ email: String) -> Bool {
        let normalizedEmail = email
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        guard let domain = normalizedEmail.split(separator: "@").last.map(String.init) else {
            return false
        }

        return reservedSignupEmailDomains.contains(domain)
    }

    static func assertEmailAllowedForPublicSignup(_ email: String) throws {
        guard !isReservedPublicSignupEmail(email) else {
            throw SQAuthError(
                description: "Emails ending in @lifeiq.app are reserved and cannot be used to create an account."
            )
        }
    }

    static func emailVerificationRequirement(for firebaseUser: FirebaseAuth.User) -> SQEmailVerificationRequirement? {
        guard SQBuildOverrides.enforceEmailVerificationForEmailPasswordAccounts else {
            return nil
        }

        let providerIds = Set(firebaseUser.providerData.map(\.providerID))
        guard providerIds.contains(SQAuthProvider.password.rawValue) else {
            return nil
        }

        let email = firebaseUser.email?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !email.isEmpty, !firebaseUser.isEmailVerified else {
            return nil
        }

        return .init(email: email)
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
        case .requiresRecentLogin:
            return .init(description: "For security, log in again and retry.")
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

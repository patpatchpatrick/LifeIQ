//
//  SQAuthManager.swift
//  BeastFitness
//
//  Created by Patrick Doyle on 3/21/26.
//

import Foundation
import AuthenticationServices
import CryptoKit
import FirebaseAuth
import FirebaseCore
import GoogleSignIn
import Security
import UIKit
import BeastFitnessCore

enum SQAuthProvider: String, CaseIterable, Hashable {
    case password = "password"
    case google = "google.com"
    case apple = "apple.com"

    init?(providerId: String) {
        self.init(rawValue: providerId)
    }
}

enum SQAccountDeletionReauthenticationMethod {
    case password(String)
    case google
    case apple
}

@MainActor
protocol SQAuthManaging: AnyObject {
    func signIn(email: String, password: String) async throws -> AuthDataResult
    func createUser(email: String, password: String) async throws -> AuthDataResult
    func signInWithGoogle(presentingViewController: UIViewController) async throws -> AuthDataResult
    func configureAppleSignInRequest(_ request: ASAuthorizationAppleIDRequest) throws
    func signInWithApple(authorization: ASAuthorization) async throws -> AuthDataResult
    func signInWithApple(presentingViewController: UIViewController) async throws -> AuthDataResult
    func sendEmailVerification() async throws
    func sendEmailVerification(to user: FirebaseAuth.User) async throws
    func reloadCurrentUser() async throws -> FirebaseAuth.User
    func handleGoogleSignIn(url: URL) -> Bool
    func currentAuthProviders() -> Set<SQAuthProvider>
    func reauthenticateForAccountDeletion(using method: SQAccountDeletionReauthenticationMethod) async throws
    func revokeGoogleAccessIfNeeded() async throws
    func revokeAppleAccessIfNeeded() async throws
    func deleteCurrentUser() async throws
    func signOut() throws
}

@MainActor
final class SQAuthManager: SQAuthManaging {
    static let shared = SQAuthManager()
    static let reservedSignupEmailDomains: Set<String> = ["lifeiq.app"]

    private var authStateHandle: AuthStateDidChangeListenerHandle?
    private var appleAuthorizationCoordinator: SQAppleAuthorizationCoordinator?
    private var currentAppleSignInNonce: String?
    private var appleAuthorizationCodeForRevocation: String?

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

    func configureAppleSignInRequest(_ request: ASAuthorizationAppleIDRequest) throws {
        let nonce = try Self.randomNonceString()
        currentAppleSignInNonce = nonce
        request.requestedScopes = [.fullName, .email]
        request.nonce = Self.sha256(nonce)
    }

    func clearPendingAppleSignInRequest() {
        currentAppleSignInNonce = nil
    }

    func signInWithApple(authorization: ASAuthorization) async throws -> AuthDataResult {
        defer { currentAppleSignInNonce = nil }

        guard let nonce = currentAppleSignInNonce else {
            throw SQAuthError(description: "Sign in with Apple could not verify the request.")
        }

        let appleAuthorizationResult = try Self.appleAuthorizationResult(from: authorization, nonce: nonce)

        do {
            return try await Auth.auth().signIn(with: appleAuthorizationResult.credential)
        } catch {
            throw SQAuthError.from(error)
        }
    }

    func signInWithApple(presentingViewController: UIViewController) async throws -> AuthDataResult {
        let authorization = try await requestAppleAuthorization(presentingViewController: presentingViewController)

        do {
            return try await Auth.auth().signIn(with: authorization.credential)
        } catch {
            throw SQAuthError.from(error)
        }
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

        case .apple:
            let presentingViewController = try currentPresentingViewController()
            let authorization = try await requestAppleAuthorization(presentingViewController: presentingViewController)
            try await currentUser.reauthenticate(with: authorization.credential)
            appleAuthorizationCodeForRevocation = authorization.authorizationCode
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

    func revokeAppleAccessIfNeeded() async throws {
        guard currentAuthProviders().contains(.apple) else { return }

        defer { appleAuthorizationCodeForRevocation = nil }

        let authorizationCode: String
        if let cachedAuthorizationCode = appleAuthorizationCodeForRevocation {
            authorizationCode = cachedAuthorizationCode
        } else {
            let presentingViewController = try currentPresentingViewController()
            let authorization = try await requestAppleAuthorization(presentingViewController: presentingViewController)
            guard let freshAuthorizationCode = authorization.authorizationCode else {
                throw SQAuthError(description: "Sign in with Apple did not return an authorization code.")
            }
            authorizationCode = freshAuthorizationCode
        }

        do {
            try await Auth.auth().revokeToken(withAuthorizationCode: authorizationCode)
        } catch {
            if Self.isAppleCodeFlowNotEnabled(error) {
                throw SQAuthError(
                    description: "Apple account deletion is not fully configured yet. Enable Apple's OAuth code flow in Firebase Authentication, then try deleting the account again."
                )
            }
            throw error
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
            throw SQAuthError(description: "Could not start sign-in because no active view was available.")
        }

        var presentingViewController = rootViewController
        while let presentedViewController = presentingViewController.presentedViewController {
            presentingViewController = presentedViewController
        }

        return presentingViewController
    }

    private func requestAppleAuthorization(presentingViewController: UIViewController) async throws -> SQAppleAuthorizationResult {
        guard let presentationAnchor = presentingViewController.view.window else {
            throw SQAuthError(description: "Could not start Sign in with Apple because no active window was available.")
        }

        let nonce = try Self.randomNonceString()

        do {
            let result: SQAppleAuthorizationResult = try await withCheckedThrowingContinuation { continuation in
                let coordinator = SQAppleAuthorizationCoordinator(
                    presentationAnchor: presentationAnchor,
                    nonce: nonce,
                    continuation: continuation
                )
                appleAuthorizationCoordinator = coordinator
                coordinator.start()
            }
            appleAuthorizationCoordinator = nil
            return result
        } catch {
            appleAuthorizationCoordinator = nil
            throw error
        }
    }

    private static func randomNonceString(length: Int = 32) throws -> String {
        guard length > 0 else {
            throw SQAuthError(description: "Could not start Sign in with Apple.")
        }

        let charset = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var randomBytes = [UInt8](repeating: 0, count: length)
        let status = randomBytes.withUnsafeMutableBytes { buffer -> Int32 in
            guard let baseAddress = buffer.baseAddress else { return errSecParam }
            return SecRandomCopyBytes(kSecRandomDefault, length, baseAddress)
        }

        guard status == errSecSuccess else {
            throw SQAuthError(description: "Could not generate a secure Sign in with Apple request.")
        }

        return String(randomBytes.map { charset[Int($0) % charset.count] })
    }

    nonisolated fileprivate static func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashedData = SHA256.hash(data: inputData)
        return hashedData.map { String(format: "%02x", $0) }.joined()
    }

    nonisolated fileprivate static func appleAuthorizationResult(
        from authorization: ASAuthorization,
        nonce: String
    ) throws -> SQAppleAuthorizationResult {
        guard let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential else {
            throw SQAuthError(description: "Sign in with Apple did not return a valid credential.")
        }

        guard let identityToken = appleIDCredential.identityToken else {
            throw SQAuthError(description: "Sign in with Apple did not return an identity token.")
        }

        guard let idToken = String(data: identityToken, encoding: .utf8) else {
            throw SQAuthError(description: "Could not read the Sign in with Apple identity token.")
        }

        let credential = OAuthProvider.appleCredential(
            withIDToken: idToken,
            rawNonce: nonce,
            fullName: appleIDCredential.fullName
        )
        let authorizationCode = appleIDCredential.authorizationCode.flatMap { String(data: $0, encoding: .utf8) }
        return .init(credential: credential, authorizationCode: authorizationCode)
    }

    private static func isAppleCodeFlowNotEnabled(_ error: Error) -> Bool {
        let nsError = error as NSError
        let errorName = nsError.userInfo["FIRAuthErrorUserInfoNameKey"] as? String
        let description = nsError.localizedDescription.lowercased()
        return errorName == "ERROR_OPERATION_NOT_ALLOWED"
            && description.contains("code flow")
            && description.contains("apple")
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
        guard SQAdminConfig.enforceEmailVerificationForEmailPasswordAccounts else {
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
        let nsError = error as NSError
        let localizedDescription = nsError.localizedDescription.lowercased()

        if localizedDescription.contains("blocked all requests from this device due to unusual activity") {
            return .init(
                description: "Email verification is temporarily blocked on this device because too many requests were sent. Please try again later or email \(SQError.supportEmail) if you need help."
            )
        }

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
            return .init(description: "Too many attempts. Please try again later or email \(SQError.supportEmail) if the issue continues.")
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

    static func fromApple(_ error: Error) -> SQAuthError {
        if let error = error as? SQAuthError {
            return error
        }

        if let authorizationError = error as? ASAuthorizationError,
           authorizationError.code == .canceled {
            return .init(description: "Sign in with Apple was canceled.", shouldPresentToUser: false)
        }

        let nsError = error as NSError
        return .init(description: nsError.localizedDescription)
    }
}

fileprivate struct SQAppleAuthorizationResult {
    let credential: AuthCredential
    let authorizationCode: String?
}

private final class SQAppleAuthorizationCoordinator: NSObject, ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {
    private let presentationAnchor: ASPresentationAnchor
    private let nonce: String
    private var continuation: CheckedContinuation<SQAppleAuthorizationResult, Error>?

    init(
        presentationAnchor: ASPresentationAnchor,
        nonce: String,
        continuation: CheckedContinuation<SQAppleAuthorizationResult, Error>
    ) {
        self.presentationAnchor = presentationAnchor
        self.nonce = nonce
        self.continuation = continuation
    }

    func start() {
        let appleIDProvider = ASAuthorizationAppleIDProvider()
        let request = appleIDProvider.createRequest()
        request.requestedScopes = [.fullName, .email]
        request.nonce = SQAuthManager.sha256(nonce)

        let authorizationController = ASAuthorizationController(authorizationRequests: [request])
        authorizationController.delegate = self
        authorizationController.presentationContextProvider = self
        authorizationController.performRequests()
    }

    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        presentationAnchor
    }

    func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithAuthorization authorization: ASAuthorization
    ) {
        do {
            finish(returning: try SQAuthManager.appleAuthorizationResult(from: authorization, nonce: nonce))
        } catch {
            finish(throwing: error)
        }
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        finish(throwing: SQAuthError.fromApple(error))
    }

    private func finish(returning result: SQAppleAuthorizationResult) {
        continuation?.resume(returning: result)
        continuation = nil
    }

    private func finish(throwing error: Error) {
        continuation?.resume(throwing: error)
        continuation = nil
    }
}

//
//  SQSubscriptionService.swift
//  BeastFitness
//

import BeastFitnessCore
import Combine
import Foundation
import StoreKit
import UIKit

@MainActor
protocol SQSubscriptionServicing: AnyObject {
    func configure()
    func loadProducts() async
    func refreshEntitlements() async
    func purchase(_ product: Product) async
    func restorePurchases() async
    func manageSubscriptions() async
}

@MainActor
final class SQSubscriptionService: SQSubscriptionServicing {
    private let subscriptionState: SQSubscriptionState
    private let hub: EventHub
    private let userManager: SQUserManaging
    private var hasConfigured = false
    private var transactionListenerTask: Task<Void, Never>?
    private var subscriptionStatusListenerTask: Task<Void, Never>?
    private var foregroundRefreshTask: Task<Void, Never>?
    private var cancellables = Set<AnyCancellable>()

    init(
        subscriptionState: SQSubscriptionState,
        hub: EventHub,
        userManager: SQUserManaging = SQUserManager.shared
    ) {
        self.subscriptionState = subscriptionState
        self.hub = hub
        self.userManager = userManager
    }

    func configure() {
        guard !hasConfigured else { return }
        hasConfigured = true

        transactionListenerTask = Task { [weak self] in
            for await result in Transaction.updates {
                guard !Task.isCancelled else { return }
                await self?.handle(transactionResult: result)
            }
        }

        subscriptionStatusListenerTask = Task { [weak self] in
            for await _ in Product.SubscriptionInfo.Status.updates {
                guard !Task.isCancelled else { return }
                await self?.refreshEntitlements()
            }
        }

        NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)
            .sink { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.foregroundRefreshTask?.cancel()
                    self?.foregroundRefreshTask = Task { @MainActor [weak self] in
                        await self?.refreshEntitlements()
                    }
                }
            }
            .store(in: &cancellables)

        hub.userEvents
            .sink { [weak self] event in
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    switch event {
                    case .loginStateChanged, .profileUpdated:
                        await self.syncUserSubscriptionMirrorIfNeeded()
                    case .emailVerificationStateChanged:
                        break
                    }
                }
            }
            .store(in: &cancellables)

        Task {
            await loadProducts()
            await refreshEntitlements()
        }
    }

    func loadProducts() async {
        subscriptionState.updateLoadingProducts(true)
        defer { subscriptionState.updateLoadingProducts(false) }

        do {
            let fetchedProducts = try await Product.products(for: Array(SQSubscriptionManager.ProductID.all))
            subscriptionState.updateProducts(fetchedProducts.sorted(by: productSort))
            SQLogger.shared.log(
                "Loaded \(fetchedProducts.count) subscription products from StoreKit",
                .info,
                context: .network
            )
        } catch {
            SQLogger.shared.log(
                "Failed to load subscription products: \(error)",
                .error,
                context: .network,
                isPriority: true
            )
        }
    }

    func refreshEntitlements() async {
        var hasPremiumEntitlement = false
        var activeExpirationDate: Date?
        var activeProductId: String?
        let now = Date()

        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result else { continue }
            guard SQSubscriptionManager.ProductID.all.contains(transaction.productID) else { continue }
            guard transaction.revocationDate == nil else { continue }
            guard !transaction.isUpgraded else { continue }

            if let expirationDate = transaction.expirationDate {
                guard expirationDate > now else { continue }
                if let activeExpirationDate, activeExpirationDate >= expirationDate {
                    continue
                }
            }

            hasPremiumEntitlement = true
            activeExpirationDate = transaction.expirationDate
            activeProductId = transaction.productID
        }

        let renewalInfo = await currentRenewalInfo(activeProductId: activeProductId)
        subscriptionState.updateSubscriptionRenewalInfo(
            expirationDate: renewalInfo?.expirationDate ?? activeExpirationDate,
            willAutoRenew: renewalInfo?.willAutoRenew,
            productId: renewalInfo?.productId ?? activeProductId
        )

        await updateAppleSubscriptionLevel(hasPremiumEntitlement ? .premium : .free)
    }

    func purchase(_ product: Product) async {
        guard !subscriptionState.isPurchasing else { return }
        subscriptionState.updatePurchasing(true)
        defer { subscriptionState.updatePurchasing(false) }

        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                guard case .verified(let transaction) = verification else {
                    presentStandardError()
                    return
                }

                await transaction.finish()
                await refreshEntitlements()
                hub.toastEvents.send(.present(.init(title: "LifeIQ Pro unlocked", style: .success)))

            case .pending:
                hub.toastEvents.send(.present(.init(title: "Purchase pending", style: .normal)))

            case .userCancelled:
                break

            @unknown default:
                break
            }
        } catch {
            presentError(error)
        }
    }

    func restorePurchases() async {
        guard !subscriptionState.isRestoring else { return }
        subscriptionState.updateRestoring(true)
        defer { subscriptionState.updateRestoring(false) }

        do {
            try await AppStore.sync()
            await refreshEntitlements()
            let hasPremiumAccess = subscriptionState.hasPremiumAccess
            let title = hasPremiumAccess ? "Purchases restored" : "No active subscription found"
            hub.toastEvents.send(.present(.init(title: title, style: hasPremiumAccess ? .success : .normal)))
        } catch {
            presentError(error)
        }
    }

    func manageSubscriptions() async {
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene else {
            presentStandardError()
            return
        }

        do {
            try await AppStore.showManageSubscriptions(in: scene)
        } catch {
            presentError(error)
        }
    }

    private func handle(transactionResult result: VerificationResult<Transaction>) async {
        guard case .verified(let transaction) = result else { return }
        guard SQSubscriptionManager.ProductID.all.contains(transaction.productID) else { return }

        await transaction.finish()
        await refreshEntitlements()
    }

    private func updateAppleSubscriptionLevel(_ level: SQSubscriptionLevel) async {
        guard subscriptionState.appleSubscriptionLevel != level else {
            await syncUserSubscriptionMirrorIfNeeded()
            return
        }

        subscriptionState.updateAppleSubscriptionLevel(level)
        SQLogger.shared.log(
            "Apple subscription level updated to \(level.rawValue)",
            .info,
            context: .network,
            isPriority: true
        )

        await syncUserSubscriptionMirrorIfNeeded()
        hub.userEvents.send(.profileUpdated)
    }

    private func syncUserSubscriptionMirrorIfNeeded() async {
        let appleSubscriptionLevel = subscriptionState.appleSubscriptionLevel
        guard SQAdminConfig.subscriptionLevelOverride == nil else { return }
        guard let user = SQAppState.shared.userState.loggedInUser else { return }
        guard user.subscriptionLevel != appleSubscriptionLevel else { return }

        let updatedUser = user.withSubscriptionLevel(appleSubscriptionLevel)

        do {
            let savedUser = try await userManager.updateSubscriptionLevel(
                for: user,
                level: appleSubscriptionLevel
            )
            SQAppState.shared.userState.updateLoggedInUser(
                savedUser,
                hasLoadedProfile: SQAppState.shared.userState.hasLoadedUserProfile,
                emailVerificationRequirement: SQAppState.shared.userState.emailVerificationRequirement
            )
        } catch {
            SQLogger.shared.log(
                "Failed to mirror Apple subscription level to Firestore: \(error)",
                .warning,
                context: .network
            )

            SQAppState.shared.userState.updateLoggedInUser(
                updatedUser,
                hasLoadedProfile: SQAppState.shared.userState.hasLoadedUserProfile,
                emailVerificationRequirement: SQAppState.shared.userState.emailVerificationRequirement
            )
        }
    }

    private func productSort(_ lhs: Product, _ rhs: Product) -> Bool {
        productRank(lhs.id) < productRank(rhs.id)
    }

    private func currentRenewalInfo(
        activeProductId: String?
    ) async -> (expirationDate: Date?, willAutoRenew: Bool?, productId: String?)? {
        var fallback: (expirationDate: Date?, willAutoRenew: Bool?, productId: String?)?

        for product in subscriptionState.products {
            guard let subscription = product.subscription else { continue }

            do {
                let statuses = try await subscription.status
                for status in statuses {
                    guard isActive(status.state) else { continue }
                    guard case .verified(let transaction) = status.transaction else { continue }
                    guard SQSubscriptionManager.ProductID.all.contains(transaction.productID) else { continue }
                    guard transaction.revocationDate == nil else { continue }
                    guard !transaction.isUpgraded else { continue }
                    guard case .verified(let renewalInfo) = status.renewalInfo else { continue }

                    let info = (
                        expirationDate: transaction.expirationDate,
                        willAutoRenew: renewalInfo.willAutoRenew,
                        productId: transaction.productID
                    )

                    if transaction.productID == activeProductId {
                        return info
                    }

                    if fallback == nil {
                        fallback = info
                    }
                }
            } catch {
                SQLogger.shared.log(
                    "Failed to load subscription status: \(error)",
                    .warning,
                    context: .network
                )
            }
        }

        return fallback
    }

    private func isActive(_ state: Product.SubscriptionInfo.RenewalState) -> Bool {
        switch state {
        case .subscribed, .inGracePeriod:
            return true
        case .expired, .inBillingRetryPeriod, .revoked:
            return false
        default:
            return false
        }
    }

    private func productRank(_ productId: String) -> Int {
        switch productId {
        case SQSubscriptionManager.ProductID.annual:
            return 0
        case SQSubscriptionManager.ProductID.monthly:
            return 1
        default:
            return 2
        }
    }

    private func presentError(_ error: Error) {
        hub.alertEvents.send(.present(.init(error as? SQUserFacingError ?? SQError.standard)))
    }

    private func presentStandardError() {
        hub.alertEvents.send(.present(.init(SQError.standard)))
    }
}

//
//  SQSubscriptionState.swift
//  BeastFitness
//

import Foundation
import StoreKit

@MainActor
protocol SQSubscriptionStating: AnyObject {
    var appleSubscriptionLevel: SQSubscriptionLevel { get }
    var effectiveSubscriptionLevel: SQSubscriptionLevel { get }
    var hasPremiumAccess: Bool { get }
    var products: [Product] { get }
    var isLoadingProducts: Bool { get }
    var isPurchasing: Bool { get }
    var isRestoring: Bool { get }
    var subscriptionExpirationDate: Date? { get }
    var subscriptionWillAutoRenew: Bool? { get }
    var statusText: String { get }
}

@MainActor
@Observable
final class SQSubscriptionState: SQSubscriptionStating {
    private(set) var appleSubscriptionLevel: SQSubscriptionLevel = .free
    private(set) var products: [Product] = []
    private(set) var isLoadingProducts = false
    private(set) var isPurchasing = false
    private(set) var isRestoring = false
    private(set) var subscriptionExpirationDate: Date?
    private(set) var subscriptionWillAutoRenew: Bool?
    private(set) var subscriptionProductId: String?

    var effectiveSubscriptionLevel: SQSubscriptionLevel {
        SQSubscriptionManager.effectiveSubscriptionLevel
    }

    var hasPremiumAccess: Bool {
        SQSubscriptionManager.hasPremiumAccess
    }

    var statusText: String {
        if let override = SQAdminConfig.subscriptionLevelOverride {
            return override == .premium ? "Premium override active" : "Free override active"
        }

        if SQAppState.shared.userState.loggedInUser?.demoSubscriptionLevel == .premium {
            return "LifeIQ Pro active"
        }

        guard appleSubscriptionLevel == .premium else {
            return "Free plan"
        }

        if subscriptionWillAutoRenew == false, let subscriptionExpirationDate {
            return "Auto-renew disabled. Access until \(subscriptionExpirationDate.formattedString(with: .fullWithoutDayName))"
        }

        return "LifeIQ Pro active"
    }

    func updateProducts(_ products: [Product]) {
        self.products = products
    }

    func updateAppleSubscriptionLevel(_ level: SQSubscriptionLevel) {
        appleSubscriptionLevel = level
    }

    func updateSubscriptionRenewalInfo(
        expirationDate: Date?,
        willAutoRenew: Bool?,
        productId: String?
    ) {
        subscriptionExpirationDate = expirationDate
        subscriptionWillAutoRenew = willAutoRenew
        subscriptionProductId = productId
    }

    func updateLoadingProducts(_ isLoading: Bool) {
        isLoadingProducts = isLoading
    }

    func updatePurchasing(_ isPurchasing: Bool) {
        self.isPurchasing = isPurchasing
    }

    func updateRestoring(_ isRestoring: Bool) {
        self.isRestoring = isRestoring
    }
}

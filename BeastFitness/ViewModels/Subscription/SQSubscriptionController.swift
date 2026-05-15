//
//  SQSubscriptionController.swift
//  BeastFitness
//

import Foundation
import StoreKit

@MainActor
@Observable
final class SQSubscriptionController: Hashable {
    let id = UUID().uuidString
    let source: String
    let feature: String?
    let subscriptionState: SQSubscriptionState

    private let subscriptionService: SQSubscriptionServicing

    init(
        source: String,
        feature: String?,
        subscriptionState: SQSubscriptionState = SQAppState.shared.subscriptionState,
        subscriptionService: SQSubscriptionServicing = SQAppState.shared.subscriptionService
    ) {
        self.source = source
        self.feature = feature
        self.subscriptionState = subscriptionState
        self.subscriptionService = subscriptionService
    }

    var products: [Product] {
        subscriptionState.products
    }

    var isLoading: Bool {
        subscriptionState.isLoadingProducts
    }

    var isPurchasing: Bool {
        subscriptionState.isPurchasing
    }

    var isRestoring: Bool {
        subscriptionState.isRestoring
    }

    var hasPremiumAccess: Bool {
        subscriptionState.hasPremiumAccess
    }

    var statusText: String {
        subscriptionState.statusText
    }

    func loadProducts() async {
        await subscriptionService.loadProducts()
    }

    func purchase(_ product: Product) {
        Task { @MainActor in
            await subscriptionService.purchase(product)
        }
    }

    func restorePurchases() {
        Task { @MainActor in
            await subscriptionService.restorePurchases()
        }
    }

    func manageSubscriptions() {
        Task { @MainActor in
            await subscriptionService.manageSubscriptions()
        }
    }

    nonisolated static func == (lhs: SQSubscriptionController, rhs: SQSubscriptionController) -> Bool {
        lhs.id == rhs.id
    }

    nonisolated func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

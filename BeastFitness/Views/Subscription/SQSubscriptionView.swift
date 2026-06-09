//
//  SQSubscriptionView.swift
//  BeastFitness
//

import StoreKit
import SwiftUI

struct SQSubscriptionView: View {
    @Bindable var controller: SQSubscriptionController

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: .SQSpace.l) {
                header
                productsSection
                termsSection
                restoreSection
            }
            .padding(.horizontal, .SQSpace.l)
            .padding(.top, .SQSpace.l)
            .padding(.bottom, .SQSpace.xl)
        }
        .navigationTitle("LifeIQ Pro")
        .navigationBarTitleDisplayMode(.inline)
        .background {
            SQSheetBackground()
        }
        .task {
            await controller.loadProducts()
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: .SQSpace.m) {
            HStack(spacing: .SQSpace.m) {
                SQImageView(
                    image: .init(
                        symbol: .sparkles,
                        symbolStyle: .colorWithFont(.dashboardGlowBlueForeground, font: .title3)
                    )
                )
                .frame(width: 28, height: 28)

                VStack(alignment: .leading, spacing: .SQSpace.xs) {
                    Text("LifeIQ Pro")
                        .sqFont(.title3)
                        .sqForegroundColor(.textPrimary)

                    Text(controller.statusText)
                        .sqFont(.bodyExtraSmall)
                        .sqForegroundColor(.textSecondary)
                }
            }

            Text("Unlock advanced scores, expanded insights, and premium tracking tools.")
                .sqFont(.bodySmall)
                .sqForegroundColor(.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.SQSpace.l)
        .sqGlassSurface(level: .card, cornerRadius: .SQCornerRadius.xl)
    }

    @ViewBuilder
    private var productsSection: some View {
        if controller.isLoading && controller.products.isEmpty {
            loadingCard
        } else if controller.products.isEmpty {
            emptyProductsCard
        } else {
            VStack(spacing: .SQSpace.m) {
                ForEach(controller.products, id: \.id) { product in
                    productRow(product)
                }
            }
        }
    }

    private var loadingCard: some View {
        HStack(spacing: .SQSpace.m) {
            ProgressView()
                .progressViewStyle(.circular)

            Text("Loading subscription options...")
                .sqFont(.bodySmall)
                .sqForegroundColor(.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.SQSpace.l)
        .sqGlassSurface(level: .card, cornerRadius: .SQCornerRadius.xl)
    }

    private var emptyProductsCard: some View {
        VStack(alignment: .leading, spacing: .SQSpace.s) {
            Text("Subscriptions unavailable")
                .sqFont(.bodySemiBold)
                .sqForegroundColor(.textPrimary)

            Text("LifeIQ could not load subscription options. Check your connection and try again.")
                .sqFont(.bodyExtraSmall)
                .sqForegroundColor(.textSecondary)

            SQButton(style: .secondary, shouldHugContent: true, title: "Retry") {
                Task { @MainActor in
                    await controller.loadProducts()
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.SQSpace.l)
        .sqGlassSurface(level: .card, cornerRadius: .SQCornerRadius.xl)
    }

    private func productRow(_ product: Product) -> some View {
        VStack(alignment: .leading, spacing: .SQSpace.m) {
            HStack(alignment: .firstTextBaseline, spacing: .SQSpace.m) {
                VStack(alignment: .leading, spacing: .SQSpace.xs) {
                    Text(title(for: product))
                        .sqFont(.bodySemiBold)
                        .sqForegroundColor(.textPrimary)

                    Text(subtitle(for: product))
                        .sqFont(.bodyExtraSmall)
                        .sqForegroundColor(.textSecondary)
                }

                Spacer(minLength: .SQSpace.m)

                Text(product.displayPrice)
                    .sqFont(.bodyBold)
                    .sqForegroundColor(.textPrimary)
            }

            SQButton(
                style: product.id == SQSubscriptionManager.ProductID.annual ? .glassPrimary : .secondary,
                title: controller.hasPremiumAccess ? "Active" : "Continue",
                isDisabled: controller.hasPremiumAccess,
                isLoading: controller.isPurchasing
            ) {
                controller.purchase(product)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.SQSpace.l)
        .sqGlassSurface(level: .card, cornerRadius: .SQCornerRadius.xl)
    }

    private var restoreSection: some View {
        VStack(alignment: .leading, spacing: .SQSpace.m) {
            SQButton(
                style: .secondary,
                title: "Restore Purchases",
                isLoading: controller.isRestoring
            ) {
                controller.restorePurchases()
            }

            if controller.hasPremiumAccess {
                SQButton(style: .secondary, title: "Manage Subscription") {
                    controller.manageSubscriptions()
                }
            }
        }
    }

    private var termsSection: some View {
        VStack(alignment: .leading, spacing: .SQSpace.m) {
            Text("Legal")
                .sqFont(.bodySmallSemiBold)
                .sqForegroundColor(.textPrimary)

            Text("Payment is handled by Apple. Subscriptions renew automatically unless canceled in App Store settings.")
                .sqFont(.bodyExtraSmall)
                .sqForegroundColor(.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            VStack(spacing: .SQSpace.s) {
                legalRow(title: "Privacy Policy") {
                    controller.openPrivacyPolicy()
                }

                legalRow(title: "Terms of Use (EULA)") {
                    controller.openTermsOfUse()
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.SQSpace.l)
        .sqGlassSurface(level: .card, cornerRadius: .SQCornerRadius.xl)
    }

    private func title(for product: Product) -> String {
        switch product.id {
        case SQSubscriptionManager.ProductID.annual:
            return "LifeIQ Pro Annual"
        case SQSubscriptionManager.ProductID.monthly:
            return "LifeIQ Pro Monthly"
        default:
            return product.displayName
        }
    }

    private func subtitle(for product: Product) -> String {
        switch product.id {
        case SQSubscriptionManager.ProductID.annual:
            return "1 year of full Pro access."
        case SQSubscriptionManager.ProductID.monthly:
            return "1 month of full Pro access."
        default:
            return product.description
        }
    }

    private func legalRow(title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: .SQSpace.s) {
                Text(title)
                    .sqFont(.bodySmallSemiBold)
                    .sqForegroundColor(.textPrimary)

                Spacer(minLength: .SQSpace.m)

                SQImageView(
                    image: .init(
                        symbol: .chevronRight,
                        symbolStyle: .colorWithFont(.textSecondary, font: .bodyExtraSmall)
                    )
                )
                .frame(width: 10, height: 10)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, .SQSpace.xs)
        }
        .buttonStyle(.plain)
    }
}

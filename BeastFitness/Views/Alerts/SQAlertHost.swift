//
//  SQAlertsHost.swift
//  BeastFitness
//
//  Created by Patrick Doyle on 12/17/25.
//

import SwiftUI

struct SQAlertHost: View {
    @Bindable var alerts: SQAlertState
    @State private var hostId: UUID = UUID()

    var body: some View {
        ZStack {
            if let alert = alerts.current {
                ZStack {
                    SQColor.dashboardGradientStart.color
                        .opacity(SQColor.isDarkMode ? 0.72 : 0.28)

                    LinearGradient(
                        colors: [
                            SQColor.dashboardGlowBlue.color.opacity(SQColor.isDarkMode ? 0.10 : 0.16),
                            SQColor.dashboardGradientMid.color.opacity(SQColor.isDarkMode ? 0.34 : 0.18),
                            SQColor.dashboardGlowMint.color.opacity(SQColor.isDarkMode ? 0.05 : 0.10)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                }
                    .ignoresSafeArea()
                    .onTapGesture {
                        alerts.dismissCurrent()
                    }

                SQAlertCard(
                    alert: alert,
                    onPrimary: { handlePrimary(alert) },
                    onSecondary: { handleSecondary(alert) },
                    onDismiss: { alerts.dismiss(alert) }
                )
                .transition(.scale(scale: 0.96).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.18), value: alerts.isPresented)
        .zIndex(10_000)
    }

    private func handlePrimary(_ alert: SQAlertViewModel) {
        if alert.primary.shouldDismissOnTap {
            alerts.dismiss(alert)
        }
        alert.primary.handler?(alert.buildContext())
    }

    private func handleSecondary(_ alert: SQAlertViewModel) {
        if alert.secondary?.shouldDismissOnTap == true {
            alerts.dismiss(alert)
        }
        alert.secondary?.handler?(alert.buildContext())
    }
}

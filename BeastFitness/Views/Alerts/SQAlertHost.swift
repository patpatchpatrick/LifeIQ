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
            if alerts.isTopHost(hostId), let alert = alerts.current {
                Color.black.opacity(0.45)
                    .ignoresSafeArea()
                    .onTapGesture {
                        // Optional: dismiss on tap outside (many apps do)
                        alerts.dismissCurrent()
                    }

                SQAlertCard(
                    alert: alert,
                    onPrimary: { handlePrimary(alert) },
                    onSecondary: { handleSecondary(alert) }
                )
                .transition(.scale(scale: 0.97).combined(with: .opacity))
            }
        }
        .onAppear { alerts.pushHost(hostId) }
        .onDisappear { alerts.popHost(hostId) }
        .animation(.easeInOut(duration: 0.15), value: alerts.isPresented)
        .zIndex(10_000)
    }

    private func handlePrimary(_ alert: SQAlertViewModel) {
        if alert.primary.shouldDismissOnTap {
            alerts.dismiss(alert)
        }
        alert.primary.handler?()
    }

    private func handleSecondary(_ alert: SQAlertViewModel) {
        if alert.secondary?.shouldDismissOnTap == true {
            alerts.dismiss(alert)
        }
        alert.secondary?.handler?()
    }
}

private struct SQAlertHostModifier: ViewModifier {
    @Bindable var alerts: SQAlertState

    func body(content: Content) -> some View {
        ZStack {
            content
            // 🚫 Prevent sheet drag / dismiss while alert is visible
                .interactiveDismissDisabled(alerts.isPresented)
            
            SQAlertHost(alerts: alerts)
        }
    }
}

extension View {
    /// Preferred: pass the alert state explicitly (works everywhere)
    func sqAlertHost(_ alerts: SQAlertState) -> some View {
        self.modifier(SQAlertHostModifier(alerts: alerts))
    }

    /// Convenience for call sites already on MainActor
    @MainActor
    func sqAlertHost() -> some View {
        self.modifier(SQAlertHostModifier(alerts: AppState.shared.alertState))
    }
}

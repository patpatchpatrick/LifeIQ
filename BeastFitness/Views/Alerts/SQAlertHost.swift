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
                Color.black.opacity(0.45)
                    .ignoresSafeArea()
                    .onTapGesture {
                        // Optional: dismiss on tap outside (many apps do)
                        alerts.dismissCurrent()
                    }

                SQAlertCard(
                    alert: alert,
                    onPrimary: { handlePrimary(alert) },
                    onSecondary: { handleSecondary(alert) },
                    onDismiss: { alerts.dismiss(alert) }
                )
                .transition(.scale(scale: 0.97).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.15), value: alerts.isPresented)
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

//
//  SQAlertCard.swift
//  BeastFitness
//
//  Created by Patrick Doyle on 12/17/25.
//

import SwiftUI

struct SQAlertCard: View {
    let alert: SQAlertViewModel
    let onPrimary: () -> Void
    let onSecondary: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            VStack(spacing: 6) {
                Text(alert.title)
                    .font(.headline)
                    .multilineTextAlignment(.center)

                if let subtitle = alert.subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.subheadline)
                        .opacity(0.8)
                        .multilineTextAlignment(.center)
                }
            }

            VStack(spacing: 10) {
                Button(alert.primary.title) { onPrimary() }
                    .buttonStyle(.borderedProminent)

                if let secondary = alert.secondary {
                    Button(secondary.title) { onSecondary() }
                        .buttonStyle(.bordered)
                }
            }
        }
        .padding(18)
        .frame(maxWidth: 320)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(radius: 24)
        .padding(.horizontal, 24)
    }
}

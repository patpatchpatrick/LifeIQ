//
//  SQOverlayRootView.swift
//  BeastFitness
//
//  Created by Patrick Doyle on 12/18/25.
//

import SwiftUI

/// This is the overlay view for the window that displays at the top level to manage both alerts and toasts
struct SQOverlayRootView: View {
    @Bindable var alerts: SQAlertState
    @Bindable var toasts: SQToastState
    @Bindable var modals: SQModalState

    var body: some View {
        ZStack {
            // Toasts layer (bottom)
            SQToastHostView(toasts: toasts)
                .zIndex(1)

            // Alerts layer (center + dim background)
            SQAlertHost(alerts: alerts)
                .zIndex(2)

            // Modals layer (above alerts)
            SQModalHost(modalState: modals)
                .zIndex(3)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.clear)
    }
}

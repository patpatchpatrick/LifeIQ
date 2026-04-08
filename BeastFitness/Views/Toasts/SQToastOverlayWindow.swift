//
//  SQToastOverlayWindow.swift
//  BeastFitness
//
//  Created by Patrick Doyle on 12/17/25.
//

import SwiftUI
import UIKit

@MainActor
final class SQOverlayWindow {
    static let shared = SQOverlayWindow()

    private var window: SQPassthroughWindow?
    private var hostingController: UIHostingController<SQOverlayRootView>?

    private init() {}

    func attachIfNeeded(alerts: SQAlertState, toasts: SQToastState, modals: SQModalState, dropdownMenu: SQDropDownMenuState) {
        guard window == nil else { return }

        guard let scene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive || $0.activationState == .foregroundInactive })
        else {
            return
        }

        let rootView = SQOverlayRootView(alerts: alerts, toasts: toasts, modals: modals, dropdownMenu: dropdownMenu)
        let hc = UIHostingController(rootView: rootView)
        hc.view.backgroundColor = .clear

        let w = SQPassthroughWindow(windowScene: scene)
        w.rootViewController = hc
        w.backgroundColor = .clear
        w.windowLevel = .alert + 1
        w.isHidden = false

        self.window = w
        self.hostingController = hc

        // ✅ Passthrough rules:
        // - If an alert is visible, we want to block the app (passthrough OFF).
        // - If a modal is visible, we want to block the app (passthrough OFF).
        // - If only a toast is visible and you want the dismiss button tappable,
        //   passthrough should also be OFF (otherwise taps fall through).
        // - If nothing visible, passthrough ON.
        updatePassthrough(alerts: alerts, toasts: toasts, modals: modals, dropdownMenu: dropdownMenu)

        // React to changes (simple callbacks).
        // If your managers don't have callbacks, you can add them (like we did earlier),
        // or just call updatePassthrough() when you present/dismiss.
        alerts.onVisibilityChanged = { [weak self] _ in
            guard let self else { return }
            self.updatePassthrough(alerts: alerts, toasts: toasts, modals: modals, dropdownMenu: dropdownMenu)
        }
        toasts.onVisibilityChanged = { [weak self] _ in
            guard let self else { return }
            self.updatePassthrough(alerts: alerts, toasts: toasts, modals: modals, dropdownMenu: dropdownMenu)
        }
        modals.onVisibilityChanged = { [weak self] _ in
            guard let self else { return }
            self.updatePassthrough(alerts: alerts, toasts: toasts, modals: modals, dropdownMenu: dropdownMenu)
        }
        dropdownMenu.onVisibilityChanged = { [weak self] _ in
            guard let self else { return }
            self.updatePassthrough(alerts: alerts, toasts: toasts, modals: modals, dropdownMenu: dropdownMenu)
        }
    }

    func detach() {
        window?.isHidden = true
        window = nil
        hostingController = nil
    }

    private func updatePassthrough(alerts: SQAlertState, toasts: SQToastState, modals: SQModalState, dropdownMenu: SQDropDownMenuState) {
        // Passthrough ONLY when nothing is showing
        window?.isPassthroughEnabled = !(alerts.isPresented || toasts.isPresented || modals.isPresented || dropdownMenu.isPresented)
    }
}

final class SQPassthroughWindow: UIWindow {
    /// When true, taps that hit the root hosting view pass through to the app.
    var isPassthroughEnabled: Bool = true

    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        let hitView = super.hitTest(point, with: event)

        // If passthrough enabled, drop taps that hit only the root hosting view.
        if isPassthroughEnabled, hitView === rootViewController?.view {
            return nil
        }

        return hitView
    }
}

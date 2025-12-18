//
//  SQToastOverlayWindow.swift
//  BeastFitness
//
//  Created by Patrick Doyle on 12/17/25.
//

import SwiftUI
import UIKit

@MainActor
final class SQToastOverlayWindow {
    static let shared = SQToastOverlayWindow()

    private var window: UIWindow?
    private var hostingController: UIHostingController<SQToastHostView>?

    private init() {}

    func attachIfNeeded(toasts: SQToastManager) {
        guard window == nil else { return }

        guard let scene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive || $0.activationState == .foregroundInactive })
        else {
            return
        }

        let host = SQToastHostView(toasts: toasts)
        let hc = UIHostingController(rootView: host)
        hc.view.backgroundColor = .clear

        let w = SQPassthroughWindow(windowScene: scene)
        w.rootViewController = hc
        w.backgroundColor = .clear
        w.windowLevel = .alert + 1
        w.isHidden = false

        // ✅ Passthrough when NO toast; interactive when toast is showing
        w.isPassthroughEnabled = !toasts.isPresented
        toasts.onVisibilityChanged = { [weak w] isPresented in
            w?.isPassthroughEnabled = !isPresented
        }

        self.window = w
        self.hostingController = hc
    }

    func detach() {
        window?.isHidden = true
        window = nil
        hostingController = nil
    }
}


final class SQPassthroughWindow: UIWindow {
    /// When true, taps that hit the root hosting view pass through to the app.
    var isPassthroughEnabled: Bool = true

    // TODO: - PTD make sure only the TOAST is tappable, not the entire region.. Currently the entire window intercepts all taps so the user can't interact with the main app when a toast is visible
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        let hitView = super.hitTest(point, with: event)

        // If passthrough enabled, drop taps that hit only the root hosting view.
        if isPassthroughEnabled, hitView === rootViewController?.view {
            return nil
        }

        return hitView
    }
}

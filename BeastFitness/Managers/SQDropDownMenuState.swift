//
//  SQDropDownMenuState.swift
//  BeastFitness
//

import Foundation
import Observation
import CoreGraphics

@MainActor
@Observable
final class SQDropDownMenuState {

    struct MenuPresentation {
        /// The button's frame in global (screen) coordinates — used to position the card.
        let anchorFrame: CGRect
        /// All selectable items.
        let items: [SQDropDownButtonViewModel]
        /// Title of the currently selected item (shown with a checkmark).
        let selectedTitle: String
        /// Called with the selected title after the dismiss animation finishes.
        let onSelect: (String) -> Void
    }

    private(set) var currentMenu: MenuPresentation? {
        didSet { onVisibilityChanged?(isPresented) }
    }

    var onVisibilityChanged: ((Bool) -> Void)?
    var isPresented: Bool { currentMenu != nil }

    func present(_ menu: MenuPresentation) {
        currentMenu = menu
    }

    func dismiss() {
        currentMenu = nil
    }
}

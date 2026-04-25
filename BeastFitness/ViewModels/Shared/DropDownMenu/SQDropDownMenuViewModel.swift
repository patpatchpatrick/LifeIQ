//
//  SQDropDownMenuViewModel.swift
//  BeastFitness
//
//  Created by Patrick Doyle on 10/14/24.
//

import Foundation
import SwiftUI

final class SQDropDownMenuViewModel: NSObject, ObservableObject {
    let id = UUID()
    struct Item {
        let title: String
        let shouldUpdateTitle: Bool
        let badgeText: String?
        let showsIndicatorDot: Bool
        
        init(
            title: String,
            shouldUpdateTitle: Bool = true,
            badgeText: String? = nil,
            showsIndicatorDot: Bool = false
        ) {
            self.title = title
            self.shouldUpdateTitle = shouldUpdateTitle
            self.badgeText = badgeText
            self.showsIndicatorDot = showsIndicatorDot
        }
    }
    var itemSelectionHandler: (String) -> Void
    private(set) var items: [Item]
    var defaultItem: Item = .init(title: "") {
        didSet {
            if defaultItem.shouldUpdateTitle {
                mainButton.title = defaultItem.title
            }
            mainButton.showsIndicatorDot = defaultItem.showsIndicatorDot
            itemSelectionHandler(defaultItem.title)
        }
    }
    lazy var mainButton = SQButtonViewModel(
        title: defaultItem.title,
        showsIndicatorDot: defaultItem.showsIndicatorDot
    ) {}
    
    @Published var dropDownButtons = [SQDropDownButtonViewModel]()
    
    init(defaultItem: Item, items: [Item], itemSelectionHandler: @escaping (String) -> Void) {
        self.items = items
        self.itemSelectionHandler = itemSelectionHandler
        super.init()
        self.defaultItem = defaultItem
        rebuildButtons()
    }

    func updateItems(
        _ items: [Item],
        defaultItem: Item? = nil,
        showsIndicatorDotOnMainButton: Bool? = nil
    ) {
        self.items = items

        if let defaultItem {
            self.defaultItem = defaultItem
        } else if let matchingItem = items.first(where: { $0.title == self.defaultItem.title }) {
            self.defaultItem = matchingItem
        }

        if let showsIndicatorDotOnMainButton {
            mainButton.showsIndicatorDot = showsIndicatorDotOnMainButton
        }

        rebuildButtons()
    }

    private func rebuildButtons() {
        dropDownButtons = items.map { item in
            .init(
                title: item.title,
                badgeText: item.badgeText,
                showsIndicatorDot: item.showsIndicatorDot
            ) { [weak self] title in
                guard let self else { return }
                self.defaultItem = self.items.first(where: { $0.title == title }) ?? .init(title: "")
            }
        }
    }
}

final class SQDropDownButtonViewModel: NSObject {
    let title: String
    let badgeText: String?
    let showsIndicatorDot: Bool
    let selectionHandler: (String) -> Void
    
    init(
        title: String,
        badgeText: String? = nil,
        showsIndicatorDot: Bool = false,
        selectionHandler: @escaping (String) -> Void
    ) {
        self.title = title
        self.badgeText = badgeText
        self.showsIndicatorDot = showsIndicatorDot
        self.selectionHandler = selectionHandler
    }
    
    func selected() {
        selectionHandler(title)
    }
}

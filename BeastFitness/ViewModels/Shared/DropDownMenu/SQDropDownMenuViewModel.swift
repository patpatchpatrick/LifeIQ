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
        
        init(title: String, shouldUpdateTitle: Bool = true) {
            self.title = title
            self.shouldUpdateTitle = shouldUpdateTitle
        }
    }
    var itemSelectionHandler: (String) -> Void
    let items: [Item]
    var defaultItem: Item = .init(title: "") {
        didSet {
            if defaultItem.shouldUpdateTitle {
                mainButton.title = defaultItem.title
            }
            itemSelectionHandler(defaultItem.title)
        }
    }
    lazy var mainButton = SQButtonViewModel(title: defaultItem.title) {}
    
    @Published var dropDownButtons = [SQDropDownButtonViewModel]()
    
    init(defaultItem: Item, items: [Item], itemSelectionHandler: @escaping (String) -> Void) {
        self.items = items
        self.itemSelectionHandler = itemSelectionHandler
        super.init()
        self.defaultItem = defaultItem
        dropDownButtons = items.map { .init(title: $0.title) { [weak self] title in
            guard let self else { return }
            self.defaultItem = items.first(where: { $0.title == title }) ?? .init(title: "")
        } }
    }
}

final class SQDropDownButtonViewModel: NSObject {
    let title: String
    let selectionHandler: (String) -> Void
    
    init(title: String, selectionHandler: @escaping (String) -> Void) {
        self.title = title
        self.selectionHandler = selectionHandler
    }
    
    func selected() {
        selectionHandler(title)
    }
}

//
//  SQMultiSelectViewModel.swift
//  BeastFitness
//

import Foundation

@MainActor
final class SQMultiSelectViewModel: ObservableObject {
    struct Item: Identifiable, Hashable {
        let id: String
        let title: String
    }

    let items: [Item]
    @Published private(set) var selectedIds: Set<String>
    var selectionChanged: ((Set<String>) -> Void)?

    init(
        items: [Item],
        selectedIds: Set<String> = [],
        selectionChanged: ((Set<String>) -> Void)? = nil
    ) {
        self.items = items
        self.selectedIds = selectedIds
        self.selectionChanged = selectionChanged
    }

    func isSelected(_ item: Item) -> Bool {
        selectedIds.contains(item.id)
    }

    func toggle(_ item: Item) {
        if selectedIds.contains(item.id) {
            selectedIds.remove(item.id)
        } else {
            selectedIds.insert(item.id)
        }
        selectionChanged?(selectedIds)
    }

    func setSelection(_ ids: Set<String>) {
        selectedIds = ids
        selectionChanged?(selectedIds)
    }
}

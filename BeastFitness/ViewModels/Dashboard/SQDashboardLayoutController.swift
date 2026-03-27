//
//  SQDashboardLayoutController.swift
//  BeastFitness
//

import Foundation
import SwiftUI

@MainActor
protocol SQDashboardLayoutInterface: AnyObject { }

@MainActor
@Observable
final class SQDashboardLayoutController: SQDashboardLayoutInterface, Identifiable {
    let id = UUID().uuidString

    let hub: EventHub
    private let layoutService: SQDashboardLayoutServicing
    private let availableGroups: [SQDashboardLayoutGroupDescriptor]
    private let onLayoutUpdated: @MainActor () -> Void

    var editableGroups: [SQDashboardLayoutEditableGroup]

    init(
        hub: EventHub = SQAppState.shared.hub,
        availableGroups: [SQDashboardLayoutGroupDescriptor],
        layoutService: SQDashboardLayoutServicing,
        onLayoutUpdated: @escaping @MainActor () -> Void
    ) {
        self.hub = hub
        self.availableGroups = availableGroups
        self.layoutService = layoutService
        self.onLayoutUpdated = onLayoutUpdated
        self.editableGroups = layoutService.editableGroups(from: availableGroups)
    }

    func moveGroups(from source: IndexSet, to destination: Int) {
        editableGroups.move(fromOffsets: source, toOffset: destination)
        persist()
    }

    func moveSubsections(in groupId: String, from source: IndexSet, to destination: Int) {
        guard let index = editableGroups.firstIndex(where: { $0.id == groupId }) else { return }
        editableGroups[index].subsections.move(fromOffsets: source, toOffset: destination)
        persist()
    }

    func toggleGroupVisibility(_ groupId: String) {
        guard let index = editableGroups.firstIndex(where: { $0.id == groupId }) else { return }
        editableGroups[index].isHidden.toggle()
        persist()
    }

    func toggleSubsectionVisibility(groupId: String, subsectionId: String) {
        guard let groupIndex = editableGroups.firstIndex(where: { $0.id == groupId }) else { return }
        guard let subsectionIndex = editableGroups[groupIndex].subsections.firstIndex(where: { $0.id == subsectionId }) else { return }

        editableGroups[groupIndex].subsections[subsectionIndex].isHidden.toggle()
        persist()
    }

    func resetLayout() {
        layoutService.reset()
        editableGroups = layoutService.editableGroups(from: availableGroups)
        onLayoutUpdated()
    }

    func dismiss() {
        hub.domainEvents.send(.popDashboardRoute)
    }

    private func persist() {
        layoutService.save(editableGroups: editableGroups)
        onLayoutUpdated()
    }
}

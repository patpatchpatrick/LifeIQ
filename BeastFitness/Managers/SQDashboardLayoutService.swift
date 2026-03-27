//
//  SQDashboardLayoutService.swift
//  BeastFitness
//

import Foundation

struct SQDashboardLayoutSubsectionDescriptor: Identifiable, Equatable {
    let id: String
    let groupId: String
    let title: String
    let defaultPriority: Int

    var storageKey: String {
        "\(groupId)::\(id)"
    }
}

struct SQDashboardLayoutGroupDescriptor: Identifiable, Equatable {
    let id: String
    let title: String
    let defaultPriority: Int
    let subsections: [SQDashboardLayoutSubsectionDescriptor]
}

struct SQDashboardLayoutEditableSubsection: Identifiable, Equatable {
    let id: String
    let groupId: String
    let title: String
    let defaultPriority: Int
    var isHidden: Bool

    var storageKey: String {
        "\(groupId)::\(id)"
    }
}

struct SQDashboardLayoutEditableGroup: Identifiable, Equatable {
    let id: String
    let title: String
    let defaultPriority: Int
    var isHidden: Bool
    var subsections: [SQDashboardLayoutEditableSubsection]
}

@MainActor
protocol SQDashboardLayoutServicing {
    func descriptors(from groups: [SQDashboardSectionGroupViewModel]) -> [SQDashboardLayoutGroupDescriptor]
    func editableGroups(from descriptors: [SQDashboardLayoutGroupDescriptor]) -> [SQDashboardLayoutEditableGroup]
    func save(editableGroups: [SQDashboardLayoutEditableGroup])
    func reset()
    func apply(to groups: [SQDashboardSectionGroupViewModel]) -> [SQDashboardSectionGroupViewModel]
}

@MainActor
final class SQDashboardLayoutService: SQDashboardLayoutServicing {
    private struct Preferences: Codable {
        static let currentVersion = 1

        var version: Int
        var groupOrder: [String]
        var hiddenGroupIds: [String]
        var subsectionOrderByGroupId: [String: [String]]
        var hiddenSubsectionKeys: [String]
    }

    private struct LegacyPreferencesV0: Codable {
        var groupOrder: [String]
        var hiddenGroupIds: [String]
        var subsectionOrderByGroupId: [String: [String]]
        var hiddenSubsectionKeys: [String]
    }

    private let defaults: SQUserDefaults
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(defaults: SQUserDefaults = .shared) {
        self.defaults = defaults
    }

    func descriptors(from groups: [SQDashboardSectionGroupViewModel]) -> [SQDashboardLayoutGroupDescriptor] {
        groups.map { group in
            .init(
                id: group.id,
                title: group.title,
                defaultPriority: group.defaultPriority,
                subsections: group.sections.map { section in
                    .init(
                        id: section.id,
                        groupId: group.id,
                        title: section.title,
                        defaultPriority: section.defaultPriority
                    )
                }
            )
        }
    }

    func editableGroups(from descriptors: [SQDashboardLayoutGroupDescriptor]) -> [SQDashboardLayoutEditableGroup] {
        let preferences = loadPreferences()
        let hiddenGroupIds = Set(preferences.hiddenGroupIds)
        let hiddenSubsectionKeys = Set(preferences.hiddenSubsectionKeys)

        return orderedGroups(from: descriptors, storedOrder: preferences.groupOrder).map { group in
            let subsectionOrder = preferences.subsectionOrderByGroupId[group.id] ?? []
            return SQDashboardLayoutEditableGroup(
                id: group.id,
                title: group.title,
                defaultPriority: group.defaultPriority,
                isHidden: hiddenGroupIds.contains(group.id),
                subsections: orderedSubsections(from: group.subsections, storedOrder: subsectionOrder).map { subsection in
                    .init(
                        id: subsection.id,
                        groupId: subsection.groupId,
                        title: subsection.title,
                        defaultPriority: subsection.defaultPriority,
                        isHidden: hiddenSubsectionKeys.contains(subsection.storageKey)
                    )
                }
            )
        }
    }

    func save(editableGroups: [SQDashboardLayoutEditableGroup]) {
        let preferences = Preferences(
            version: Preferences.currentVersion,
            groupOrder: editableGroups.map(\.id),
            hiddenGroupIds: editableGroups.filter(\.isHidden).map(\.id),
            subsectionOrderByGroupId: editableGroups.reduce(into: [:]) { result, group in
                result[group.id] = group.subsections.map(\.id)
            },
            hiddenSubsectionKeys: editableGroups.flatMap { group in
                group.subsections.filter(\.isHidden).map(\.storageKey)
            }
        )

        if let data = try? encoder.encode(preferences) {
            defaults.setDashboardLayoutPreferencesData(data)
        }
    }

    func reset() {
        defaults.clearDashboardLayoutPreferences()
    }

    func apply(to groups: [SQDashboardSectionGroupViewModel]) -> [SQDashboardSectionGroupViewModel] {
        let preferences = loadPreferences()
        let hiddenGroupIds = Set(preferences.hiddenGroupIds)
        let hiddenSubsectionKeys = Set(preferences.hiddenSubsectionKeys)
        let ordered = orderedGroups(from: clonedGroups(from: groups), storedOrder: preferences.groupOrder)

        return ordered.compactMap { group in
            guard !hiddenGroupIds.contains(group.id) else {
                return nil
            }

            let subsectionOrder = preferences.subsectionOrderByGroupId[group.id] ?? []
            group.sections = orderedSubsections(from: group.sections, storedOrder: subsectionOrder).filter {
                !hiddenSubsectionKeys.contains(subsectionStorageKey(groupId: group.id, subsectionId: $0.id))
            }

            guard !group.sections.isEmpty else {
                return nil
            }

            return group
        }
    }

    private func loadPreferences() -> Preferences {
        guard
            let data = defaults.getDashboardLayoutPreferencesData(),
            !data.isEmpty
        else {
            return .init(
                version: Preferences.currentVersion,
                groupOrder: [],
                hiddenGroupIds: [],
                subsectionOrderByGroupId: [:],
                hiddenSubsectionKeys: []
            )
        }

        if let preferences = try? decoder.decode(Preferences.self, from: data) {
            return migratedPreferences(from: preferences)
        }

        if let legacyPreferences = try? decoder.decode(LegacyPreferencesV0.self, from: data) {
            return .init(
                version: Preferences.currentVersion,
                groupOrder: legacyPreferences.groupOrder,
                hiddenGroupIds: legacyPreferences.hiddenGroupIds,
                subsectionOrderByGroupId: legacyPreferences.subsectionOrderByGroupId,
                hiddenSubsectionKeys: legacyPreferences.hiddenSubsectionKeys
            )
        }

        return .init(
            version: Preferences.currentVersion,
            groupOrder: [],
            hiddenGroupIds: [],
            subsectionOrderByGroupId: [:],
            hiddenSubsectionKeys: []
        )
    }

    private func migratedPreferences(from preferences: Preferences) -> Preferences {
        switch preferences.version {
        case Preferences.currentVersion:
            return preferences
        default:
            return .init(
                version: Preferences.currentVersion,
                groupOrder: preferences.groupOrder,
                hiddenGroupIds: preferences.hiddenGroupIds,
                subsectionOrderByGroupId: preferences.subsectionOrderByGroupId,
                hiddenSubsectionKeys: preferences.hiddenSubsectionKeys
            )
        }
    }

    private func orderedGroups(
        from groups: [SQDashboardSectionGroupViewModel],
        storedOrder: [String]
    ) -> [SQDashboardSectionGroupViewModel] {
        let orderLookup = Dictionary(uniqueKeysWithValues: storedOrder.enumerated().map { ($1, $0) })

        return groups.sorted { lhs, rhs in
            let lhsIndex = orderLookup[lhs.id]
            let rhsIndex = orderLookup[rhs.id]

            switch (lhsIndex, rhsIndex) {
            case let (lhsIndex?, rhsIndex?):
                return lhsIndex < rhsIndex
            case (_?, nil):
                return true
            case (nil, _?):
                return false
            case (nil, nil):
                return lhs.defaultPriority < rhs.defaultPriority
            }
        }
    }

    private func orderedGroups(
        from groups: [SQDashboardLayoutGroupDescriptor],
        storedOrder: [String]
    ) -> [SQDashboardLayoutGroupDescriptor] {
        let orderLookup = Dictionary(uniqueKeysWithValues: storedOrder.enumerated().map { ($1, $0) })

        return groups.sorted { lhs, rhs in
            let lhsIndex = orderLookup[lhs.id]
            let rhsIndex = orderLookup[rhs.id]

            switch (lhsIndex, rhsIndex) {
            case let (lhsIndex?, rhsIndex?):
                return lhsIndex < rhsIndex
            case (_?, nil):
                return true
            case (nil, _?):
                return false
            case (nil, nil):
                return lhs.defaultPriority < rhs.defaultPriority
            }
        }
    }

    private func orderedSubsections(
        from subsections: [SQDashboardSubsectionViewModel],
        storedOrder: [String]
    ) -> [SQDashboardSubsectionViewModel] {
        let orderLookup = Dictionary(uniqueKeysWithValues: storedOrder.enumerated().map { ($1, $0) })

        return subsections.sorted { lhs, rhs in
            let lhsIndex = orderLookup[lhs.id]
            let rhsIndex = orderLookup[rhs.id]

            switch (lhsIndex, rhsIndex) {
            case let (lhsIndex?, rhsIndex?):
                return lhsIndex < rhsIndex
            case (_?, nil):
                return true
            case (nil, _?):
                return false
            case (nil, nil):
                return lhs.defaultPriority < rhs.defaultPriority
            }
        }
    }

    private func orderedSubsections(
        from subsections: [SQDashboardLayoutSubsectionDescriptor],
        storedOrder: [String]
    ) -> [SQDashboardLayoutSubsectionDescriptor] {
        let orderLookup = Dictionary(uniqueKeysWithValues: storedOrder.enumerated().map { ($1, $0) })

        return subsections.sorted { lhs, rhs in
            let lhsIndex = orderLookup[lhs.id]
            let rhsIndex = orderLookup[rhs.id]

            switch (lhsIndex, rhsIndex) {
            case let (lhsIndex?, rhsIndex?):
                return lhsIndex < rhsIndex
            case (_?, nil):
                return true
            case (nil, _?):
                return false
            case (nil, nil):
                return lhs.defaultPriority < rhs.defaultPriority
            }
        }
    }

    private func subsectionStorageKey(groupId: String, subsectionId: String) -> String {
        "\(groupId)::\(subsectionId)"
    }

    private func clonedGroups(from groups: [SQDashboardSectionGroupViewModel]) -> [SQDashboardSectionGroupViewModel] {
        groups.map { group in
            let clonedSections = group.sections.map { cloneSubsection($0) }
            let clonedGroup = SQDashboardSectionGroupViewModel(
                id: group.id,
                title: group.title,
                defaultPriority: group.defaultPriority,
                sections: clonedSections
            )
            clonedGroup.isExpanded = group.isExpanded
            return clonedGroup
        }
    }

    private func cloneSubsection(_ section: SQDashboardSubsectionViewModel) -> SQDashboardSubsectionViewModel {
        let clonedDropDown = cloneDropDown(section.dropDownViewModel)

        let clonedSection = SQDashboardSubsectionViewModel(
            id: section.id,
            title: section.title,
            defaultPriority: section.defaultPriority,
            rowsByFilter: section.rowsByFilter,
            dropDownViewModel: clonedDropDown,
            titleButton: section.titleButton,
            columnHeaders: section.columnHeaders,
            rowSpacing: section.rowSpacing,
            maxVisibleRows: section.maxVisibleRows
        )

        clonedSection.isCollapsed = section.isCollapsed
        clonedSection.isLocked = section.isLocked
        clonedSection.onLockedTap = section.onLockedTap

        if clonedSection.activeFilter != section.activeFilter {
            clonedSection.updateActiveFilter(section.activeFilter)
        }

        if section.isShowingAllRows {
            clonedSection.toggleShowingAllRows()
        }

        if let clonedDropDown {
            clonedDropDown.itemSelectionHandler = { [weak clonedSection] selectedFilter in
                clonedSection?.updateActiveFilter(selectedFilter)
            }
        }

        return clonedSection
    }

    private func cloneDropDown(_ dropDown: SQDropDownMenuViewModel?) -> SQDropDownMenuViewModel? {
        guard let dropDown else { return nil }

        return SQDropDownMenuViewModel(
            defaultItem: dropDown.defaultItem,
            items: dropDown.items,
            itemSelectionHandler: { _ in }
        )
    }
}

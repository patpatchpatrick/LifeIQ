//
//  SQDashboardSectionGroupView.swift
//  BeastFitness
//
//  Created by Claude Code on 2026-02-06.
//

import SwiftUI

/// Renders a section group (collapsible header + child sections) in the dashboard.
///
/// This view represents a top-level grouping of related sections (e.g., "Daily Stats", "Workouts").
/// It uses a sticky header that can be tapped to expand/collapse the group's child sections.
struct SQDashboardSectionGroupView: View {
    @Bindable var sectionGroup: SQDashboardSectionGroupViewModel

    // Create a computed binding that inverts isExpanded to isCollapsed
    private var isCollapsed: Binding<Bool> {
        Binding(
            get: { !sectionGroup.isExpanded },
            set: { sectionGroup.isExpanded = !$0 }
        )
    }

    var body: some View {
        Section {
            if sectionGroup.isExpanded {
                ForEach(sectionGroup.sections) { section in
                    SQDashboardSectionView(section: section)
                }
            }
        } header: {
            SQDashboardSectionHeader(
                title: sectionGroup.title,
                isCollapsed: isCollapsed
            )
        }
    }
}

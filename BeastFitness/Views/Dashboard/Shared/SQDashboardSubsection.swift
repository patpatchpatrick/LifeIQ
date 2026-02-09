//
//  SQDashboardSubsection.swift
//  BeastFitness
//
//  Created by Claude on 2026-02-06.
//

import SwiftUI

/// Reusable container for dashboard subsections.
/// Provides collapsible header with optional dropdown menu.
struct SQDashboardSubsection<Content: View>: View {
    var horizontalPadding: CGFloat { .SQSpace.l }
    let title: String
    @Binding var isCollapsed: Bool
    let dropdownMenu: SQDropDownMenu?
    @ViewBuilder let content: () -> Content

    init(
        title: String,
        isCollapsed: Binding<Bool>,
        dropdownMenu: SQDropDownMenu? = nil,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.title = title
        self._isCollapsed = isCollapsed
        self.dropdownMenu = dropdownMenu
        self.content = content
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header button
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isCollapsed.toggle()
                }
            } label: {
                HStack {
                    Text(title)
                        .sqFont(.bodyLarge)
                        .sqForegroundColor(.textTertiary)

                    Spacer()

                    if let dropdownMenu = dropdownMenu {
                        dropdownMenu
                    }

                    SQImageView(
                        image: .init(
                            symbol: isCollapsed ? .chevronDown : .chevronUp,
                            symbolStyle: .colorWithFont(.textSecondary, font: .bodySmall)
                        )
                    )
                    .frame(width: 12, height: 12)
                }
                .padding(.horizontal, SQDashboardView.uiConfig.sectionHeaderHorizPadding)
                .padding(.vertical, SQDashboardView.uiConfig.sectionHeaderHorizPadding)
            }
            .buttonStyle(.plain)

            // Content
            if !isCollapsed {
                content() // PTD THIS ISSUE IS HERE!
                    .padding(.horizontal, SQDashboardView.uiConfig.sectionRowHorizPadding)
                    .padding(.bottom, SQDashboardView.uiConfig.sectionRowVertPadding)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .sqBackgroundColor(.backgroundSecondary)
        .cornerRadius(12)
    }
}

#Preview {
    VStack(spacing: 16) {
        SQDashboardSubsection(
            title: "Metrics",
            isCollapsed: .constant(false)
        ) {
            Text("Metrics content goes here")
                .sqFont(.body)
                .sqForegroundColor(.textSecondary)
                .padding(16)
        }

        SQDashboardSubsection(
            title: "Performance",
            isCollapsed: .constant(true)
        ) {
            Text("Performance content goes here")
                .sqFont(.body)
                .sqForegroundColor(.textSecondary)
                .padding(16)
        }
    }
    .padding(16)
    .sqBackgroundColor(.background)
}

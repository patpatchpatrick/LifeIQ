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
    let title: String
    @Binding var isCollapsed: Bool
    let dropdownMenu: AnyView?
    @ViewBuilder let content: () -> Content

    init(
        title: String,
        isCollapsed: Binding<Bool>,
        dropdownMenu: SQDropDownMenu? = nil,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.title = title
        self._isCollapsed = isCollapsed
        self.dropdownMenu = dropdownMenu.map { AnyView($0) }
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
                        .sqFont(.titleMedium)
                        .sqForegroundColor(.textPrimary)

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
                    .frame(width: 16, height: 16)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .buttonStyle(.plain)

            // Content
            if !isCollapsed {
                content()
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
                .sqFont(.bodyMedium)
                .sqForegroundColor(.textSecondary)
                .padding(16)
        }

        SQDashboardSubsection(
            title: "Performance",
            isCollapsed: .constant(true)
        ) {
            Text("Performance content goes here")
                .sqFont(.bodyMedium)
                .sqForegroundColor(.textSecondary)
                .padding(16)
        }
    }
    .padding(16)
    .sqBackgroundColor(.backgroundPrimary)
}

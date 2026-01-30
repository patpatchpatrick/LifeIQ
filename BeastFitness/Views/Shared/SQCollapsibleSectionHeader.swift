//
//  SQCollapsibleSectionHeader.swift
//  BeastFitness
//
//  Created by Patrick Doyle on 1/29/26.
//

import SwiftUI

/// A shared collapsible section header view used across dashboard sections
/// Provides consistent styling for expandable/collapsible sections with a title and chevron indicator
struct SQCollapsibleSectionHeader<Accessory: View>: View {
    let title: String
    let icon: SQImageSymbol?
    let isExpanded: Bool
    let action: () -> Void
    let accessoryView: Accessory

    init(
        title: String,
        icon: SQImageSymbol? = nil,
        isExpanded: Bool,
        action: @escaping () -> Void,
        @ViewBuilder accessoryView: () -> Accessory = { EmptyView() }
    ) {
        self.title = title
        self.icon = icon
        self.isExpanded = isExpanded
        self.action = action
        self.accessoryView = accessoryView()
    }

    var body: some View {
        Button(action: action) {
            HStack {
                SQDashboardView.cardTitle(title: title, icon: icon)

                accessoryView

                Spacer()

                SQImageView(
                    image: .init(
                        symbol: isExpanded ? .chevronUp : .chevronDown,
                        symbolStyle: .colorWithFont(.textTertiary, font: .bodySmall)
                    )
                )
                .frame(width: 14)
            }
        }
        .padding(.bottom, SQDashboardView.uiConfig.cardInnerTitleBottomPadding)
    }
}

//
//  SQDashboardSectionHeader.swift
//  BeastFitness
//
//  Created by Claude Code on 2/6/26.
//

import SwiftUI

struct SQDashboardSectionHeader: View {
    let title: String
    @Binding var isCollapsed: Bool

    var body: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                isCollapsed.toggle()
            }
        } label: {
            HStack {
                Text(title)
                    .sqFont(.title3)
                    .sqForegroundColor(.textPrimary)

                Spacer()

                SQImageView(
                    image: .init(
                        symbol: isCollapsed ? .chevronDown : .chevronUp,
                        symbolStyle: .colorWithFont(.textSecondary, font: .body)
                    )
                )
                .frame(width: 16, height: 16)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .sqBackgroundColor(.background)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    VStack(spacing: 0) {
        SQDashboardSectionHeader(
            title: "Daily Stats",
            isCollapsed: .constant(false)
        )

        SQDashboardSectionHeader(
            title: "Workouts",
            isCollapsed: .constant(true)
        )
    }
    .sqBackgroundColor(.background)
}

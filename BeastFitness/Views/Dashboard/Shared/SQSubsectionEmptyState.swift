//
//  SQSubsectionEmptyState.swift
//  BeastFitness
//

import SwiftUI

struct SQSubsectionEmptyState: View {
    let message: String
    let icon: SQImageSymbol

    init(message: String, icon: SQImageSymbol = .exclamationmarkCircle) {
        self.message = message
        self.icon = icon
    }

    var body: some View {
        VStack(spacing: 12) {
            SQImageView(image: .init(
                symbol: icon,
                symbolStyle: .colorWithFont(.textSecondary, font: .bodyMedium)
            ))

            Text(message)
                .sqFont(.bodyMedium)
                .sqForegroundColor(.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, 32)
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    SQSubsectionEmptyState(message: "No metrics in this group")
        .sqBackgroundColor(.background)
}

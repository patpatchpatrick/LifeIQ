//
//  SQCallToAction.swift
//  BeastFitness
//
//  Created by Patrick Doyle on 11/24/25.
//

import SwiftUI

struct SQCallToAction: View {
    let viewModel: SQCallToActionViewModel

    var body: some View {
        Button(
            action: { viewModel.onTap?() },
            label: {
                HStack(spacing: .SQSpace.m) {
                    if let icon = viewModel.icon {
                        SQImageView(image: icon)
                            .frame(width: 20, height: 20)
                    }

                    Text(viewModel.title)
                        .sqFont(.bodyBold)
                        .sqShadow()
                        .sqForegroundColor(.textPrimary)
                }
                .padding(.SQSpace.l)
                .frame(maxWidth: .infinity)
                .sqBackgroundColor(.accent(1))
                .cornerRadius(.SQCornerRadius.m)
            })
    }
}

struct SQCallToActionViewModel {
    let icon: SQImage?
    let title: String
    let onTap: (() -> Void)?

    init(icon: SQImage? = nil, title: String, onTap: (() -> Void)?) {
        self.icon = icon
        self.title = title
        self.onTap = onTap
    }
}

#Preview {
    VStack(spacing: .SQSpace.l) {
        // With icon
        SQCallToAction(viewModel: .init(
            icon: .init(symbol: .checkmark),
            title: "Complete daily check-in",
            onTap: nil
        ))

        // Without icon
        SQCallToAction(viewModel: .init(
            title: "Another action",
            onTap: nil
        ))
    }
    .padding()
    .preferredColorScheme(.dark)
}

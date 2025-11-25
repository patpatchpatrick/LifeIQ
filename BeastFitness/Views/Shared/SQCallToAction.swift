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
                Text(viewModel.title)
                    .sqFont(.bodyBold)
                    .sqShadow()
                    .sqForegroundColor(.textPrimary)
                    .padding(.SQSpace.l)
                    .sqBackgroundColor(.accent(1))
                    .cornerRadius(.SQSpace.m)
            })
    }
}

struct SQCallToActionViewModel {
    let title: String
    let onTap: (() -> Void)?
}

#Preview {
    SQCallToAction(viewModel: .init(title: "Complete daily check-in", onTap: nil))
        .preferredColorScheme(.dark)
}

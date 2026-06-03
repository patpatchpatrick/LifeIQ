//
//  SQDashboardHelperNoteRowView.swift
//  BeastFitness
//
//  Created by Codex on 6/3/26.
//

import SwiftUI

struct SQDashboardHelperNoteRowView: View {
    let viewModel: SQDashboardHelperNoteRowViewModel

    var body: some View {
        HStack(alignment: .top, spacing: .SQSpace.s) {
            SQImageView(
                image: .init(
                    symbol: viewModel.icon,
                    symbolStyle: .colorWithFont(.dashboardGlowBlue, font: .bodyExtraSmall)
                )
            )
            .frame(width: 14, height: 14)
            .padding(.top, 2)
            .opacity(0.86)

            Text(viewModel.message)
                .sqFont(.bodyExtraSmall)
                .sqForegroundColor(.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.SQSpace.m)
        .frame(maxWidth: .infinity, alignment: .leading)
        .sqGlassSurface(level: .card, cornerRadius: .SQCornerRadius.l)
    }
}

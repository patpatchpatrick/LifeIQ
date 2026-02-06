//
//  SQTag.swift
//  BeastFitness
//
//  Created by Patrick Doyle on 1/6/26.
//

import SwiftUI

struct SQTag: View {
    let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        Text(text)
            .sqFont(.bodyExtraSmall)
            .sqForegroundColor(.textSecondary)
            .padding(.vertical, 4)
            .padding(.horizontal, 8)
            .background(
                Capsule()
                    .sqForegroundColor(.backgroundSecondaryLight)
            )
            .overlay(
                Capsule()
                    .strokeBorder(SQColor.divider(1).color, lineWidth: 1)
            )
            .fixedSize(horizontal: true, vertical: false)
            .accessibilityLabel(text)
    }
}

//
//  SQDropDownMenuOverlayCard.swift
//  BeastFitness
//

import SwiftUI

struct SQDropDownMenuOverlayCard: View {
    let menu: SQDropDownMenuState.MenuPresentation
    let menuState: SQDropDownMenuState

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(menu.items.enumerated()), id: \.offset) { index, item in
                Button {
                    // Dismiss the overlay first, then fire selection after the animation settles
                    withAnimation(.easeInOut(duration: 0.15)) {
                        menuState.dismiss()
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                        menu.onSelect(item.title)
                    }
                } label: {
                    HStack {
                        Text(item.title)
                            .sqFont(.body)
                            .sqForegroundColor(.textPrimary)
                        Spacer()
                        if item.title == menu.selectedTitle {
                            SQImageView(
                                image: .init(
                                    symbol: .checkmark,
                                    symbolStyle: .colorWithFont(.textPrimary, font: .body)
                                )
                            )
                            .frame(width: 14, height: 14)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                if index < menu.items.count - 1 {
                    Divider()
                        .padding(.leading, 16)
                }
            }
        }
        .frame(minWidth: 160)
        .fixedSize(horizontal: false, vertical: true)
        .sqBackgroundColor(.backgroundSecondary)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.18), radius: 10, x: 0, y: 4)
    }
}

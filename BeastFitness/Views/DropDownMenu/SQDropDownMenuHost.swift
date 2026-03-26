//
//  SQDropDownMenuHost.swift
//  BeastFitness
//

import SwiftUI

struct SQDropDownMenuHost: View {
    @Bindable var menuState: SQDropDownMenuState

    private let horizontalInset: CGFloat = .SQSpace.xl
    private let idealMenuWidth: CGFloat = 220

    private func menuWidth(for availableWidth: CGFloat) -> CGFloat {
        min(idealMenuWidth, max(availableWidth - (horizontalInset * 2), 160))
    }

    private func menuOriginX(for menu: SQDropDownMenuState.MenuPresentation, in availableWidth: CGFloat) -> CGFloat {
        let width = menuWidth(for: availableWidth)
        let isTrailingButton = menu.anchorFrame.midX > availableWidth / 2
        let preferredX = isTrailingButton
            ? menu.anchorFrame.maxX - width
            : menu.anchorFrame.minX
        let maxX = max(horizontalInset, availableWidth - width - horizontalInset)
        return min(max(preferredX, horizontalInset), maxX)
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .topLeading) {
                if let menu = menuState.currentMenu {
                    // Invisible scrim — catches taps outside the card to dismiss
                    Color.clear
                        .ignoresSafeArea()
                        .contentShape(Rectangle())
                        .onTapGesture {
                            withAnimation(.easeInOut(duration: 0.15)) {
                                menuState.dismiss()
                            }
                        }

                    // Floating card — positioned just below and aligned to the button's edge
                    SQDropDownMenuOverlayCard(menu: menu, menuState: menuState)
                        .frame(width: menuWidth(for: proxy.size.width), alignment: .leading)
                        .offset(
                            x: menuOriginX(for: menu, in: proxy.size.width),
                            y: menu.anchorFrame.maxY + 4
                        )
                        .transition(
                            .opacity.combined(with: .scale(
                                scale: 0.92,
                                anchor: menu.anchorFrame.midX > proxy.size.width / 2 ? .topTrailing : .topLeading
                            ))
                        )
                }
            }
        }
        .ignoresSafeArea()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .animation(.easeInOut(duration: 0.15), value: menuState.isPresented)
    }
}

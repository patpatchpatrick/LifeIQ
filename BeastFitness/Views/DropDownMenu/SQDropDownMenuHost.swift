//
//  SQDropDownMenuHost.swift
//  BeastFitness
//

import SwiftUI

/// Positions the dropdown card left-aligned to the button when button is in the left half of the screen,
/// or right-aligned when the button is in the right half — preventing overflow off the right edge.
private struct SQDropDownHorizontalPositionModifier: ViewModifier {
    let anchorFrame: CGRect

    func body(content: Content) -> some View {
        let screenWidth = UIScreen.main.bounds.width
        let isTrailingButton = anchorFrame.midX > screenWidth / 2

        if isTrailingButton {
            // Right-align card to button's right edge
            content
                .frame(maxWidth: .infinity, alignment: .trailing)
                .padding(.trailing, screenWidth - anchorFrame.maxX)
        } else {
            // Left-align card to button's left edge
            content
                .padding(.leading, anchorFrame.minX)
        }
    }
}

struct SQDropDownMenuHost: View {
    @Bindable var menuState: SQDropDownMenuState

    var body: some View {
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
                    .padding(.top, menu.anchorFrame.maxY + 4)
                    .modifier(SQDropDownHorizontalPositionModifier(anchorFrame: menu.anchorFrame))
                    .transition(
                        .opacity.combined(with: .scale(
                            scale: 0.92,
                            anchor: menu.anchorFrame.midX > UIScreen.main.bounds.width / 2 ? .topTrailing : .topLeading
                        ))
                    )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .animation(.easeInOut(duration: 0.15), value: menuState.isPresented)
    }
}

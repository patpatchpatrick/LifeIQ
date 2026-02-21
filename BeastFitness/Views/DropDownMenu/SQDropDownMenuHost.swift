//
//  SQDropDownMenuHost.swift
//  BeastFitness
//

import SwiftUI

struct SQDropDownMenuHost: View {
    @Bindable var menuState: SQDropDownMenuState

    var body: some View {
        ZStack(alignment: .topLeading) {
            if let menu = menuState.currentMenu {
                // Invisible scrim — catches taps outside the card to dismiss
                Color.black.opacity(0.001)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            menuState.dismiss()
                        }
                    }

                // Floating card — positioned just below and aligned to the button's left edge
                SQDropDownMenuOverlayCard(menu: menu, menuState: menuState)
                    .padding(.top, menu.anchorFrame.maxY + 4)
                    .padding(.leading, menu.anchorFrame.minX)
                    .transition(
                        .opacity.combined(with: .scale(scale: 0.92, anchor: .topLeading))
                    )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .animation(.easeInOut(duration: 0.15), value: menuState.isPresented)
    }
}

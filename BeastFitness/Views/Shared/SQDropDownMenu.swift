//
//  SQDropDownMenu.swift
//  BeastFitness
//

import SwiftUI

/// Captures the button's global frame so we can anchor the dropdown card to it.
private struct SQDropDownAnchorKey: PreferenceKey {
    static var defaultValue: CGRect = .zero
    static func reduce(value: inout CGRect, nextValue: () -> CGRect) {
        value = nextValue()
    }
}

struct SQDropDownMenu: View {
    @ObservedObject var menuViewModel: SQDropDownMenuViewModel
    let isDisabled: Bool

    @State private var buttonFrame: CGRect = .zero

    var body: some View {
        SQDropDownButton(viewModel: menuViewModel.mainButton)
            .disabled(isDisabled)
            .frame(height: 30)
            .background(
                GeometryReader { geo in
                    Color.clear
                        .preference(
                            key: SQDropDownAnchorKey.self,
                            value: geo.frame(in: .global)
                        )
                }
            )
            .onPreferenceChange(SQDropDownAnchorKey.self) { frame in
                buttonFrame = frame
            }
            .simultaneousGesture(
                TapGesture().onEnded {
                    guard !isDisabled else { return }
                    let presentation = SQDropDownMenuState.MenuPresentation(
                        anchorFrame: buttonFrame,
                        items: menuViewModel.dropDownButtons,
                        selectedTitle: menuViewModel.mainButton.title,
                        onSelect: { title in
                            menuViewModel.dropDownButtons
                                .first(where: { $0.title == title })?
                                .selected()
                        }
                    )
                    withAnimation(.easeInOut(duration: 0.15)) {
                        SQAppState.shared.dropDownMenuState.present(presentation)
                    }
                }
            )
    }
}

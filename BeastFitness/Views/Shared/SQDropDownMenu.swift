//
//  SQDropDownMenu.swift
//  BeastFitness
//

import SwiftUI


struct SQDropDownMenu: View {
    @ObservedObject var menuViewModel: SQDropDownMenuViewModel
    let isDisabled: Bool
    var showBackground: Bool = true

    @State private var buttonFrame: CGRect = .zero

    var body: some View {
        SQDropDownButton(viewModel: menuViewModel.mainButton, showBackground: showBackground)
            .disabled(isDisabled)
            .frame(height: 30)
            .background(
                GeometryReader { geo in
                    Color.clear
                        .onAppear {
                            buttonFrame = geo.frame(in: .global)
                        }
                        .onChange(of: geo.frame(in: .global)) { _, newFrame in
                            buttonFrame = newFrame
                        }
                }
            )
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

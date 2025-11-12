//
//  Untitled.swift
//  BeastFitness
//
//  Created by Patrick Doyle on 10/21/24.
//

import SwiftUI

struct SQDropDownMenu: View {
    @ObservedObject var menuViewModel: SQDropDownMenuViewModel
    let isDisabled: Bool
    
    @ViewBuilder
    var menu: some View {
        Menu {
            ForEach(menuViewModel.dropDownButtons, id: \.title) { button in
                Button(role: .cancel) {
                    button.selected()
                } label: {
                    Text(button.title)
                }
                .disabled(isDisabled)
            }
        } label: {
            SQDropDownButton(viewModel: menuViewModel.mainButton)
                .disabled(isDisabled)
                .frame(height: 30)
        }
        .menuStyle(NavMenuStyle())
        .disabled(isDisabled)
    }
    
    var body: some View {
        menu
    }
}

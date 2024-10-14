//
//  View+Extensions.swift
//  BeastFitness
//
//  Created by Patrick Doyle on 9/30/24.
//

import SwiftUI

extension View {
    
    @ViewBuilder func redacted(_ isRedacted: Bool, reason: RedactionReasons) -> some View {
        if isRedacted {
            self.redacted(reason: reason)
        } else {
            self
        }
    }
    
}

// MARK: - Nav Bar Menu

extension View {
    @ViewBuilder
    func sqNavMenu(_ viewModel: SQNavBarViewModel) -> some View {
        modifier(SQNavigationMenu(viewModel: viewModel))
    }
}

struct NavMenuStyle : MenuStyle {
    func makeBody(configuration: Configuration) -> some View {
        Menu(configuration)
    }
}

struct SQNavigationMenu: ViewModifier {
    @ObservedObject var viewModel: SQNavBarViewModel
    
    @ViewBuilder
    func menu(for menuViewModel: SQDropDownMenuViewModel) -> some View {
        Menu {
            ForEach(menuViewModel.dropDownButtons, id: \.title) { button in
                Button(role: .cancel) {
                    button.selected()
                } label: {
                    Text(button.title)
                }
                .disabled(!viewModel.allButtonsEnabled)
            }
        } label: {
            SQNavBarButton(viewModel: menuViewModel.mainButton)
                .disabled(!viewModel.allButtonsEnabled)
                .frame(height: 30)
        }
        .menuStyle(NavMenuStyle())
        .disabled(!viewModel.allButtonsEnabled)
    }
    
    func body(content: Content) -> some View {
        content
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    menu(for: viewModel.leadingViewModel)
                        .opacity(viewModel.isVisible ? 1 : 0)
                        .disabled(!viewModel.isVisible)
                }
            }
    }
}

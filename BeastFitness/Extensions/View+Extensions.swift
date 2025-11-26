//
//  View+Extensions.swift
//  BeastFitness
//
//  Created by Patrick Doyle on 9/30/24.
//

import SwiftUI

extension View {
    
    @inline(__always)
     func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
         condition ? AnyView(transform(self)) : AnyView(self)
     }
    
    @ViewBuilder func redacted(_ isRedacted: Bool, reason: RedactionReasons) -> some View {
        if isRedacted {
            self.redacted(reason: reason)
        } else {
            self
        }
    }
    
    func sqForegroundColor(_ color: SQColor) -> some View {
        foregroundColor(color.color)
    }
    
    func sqTintColor(_ color: SQColor) -> some View {
        tint(color.color)
    }
    
    func sqBackgroundColor(_ color: SQColor, opacity: CGFloat = 1) -> some View {
        background(color.color.opacity(opacity))
    }
    
    func sqBorder(_ color: SQColor, width: CGFloat) -> some View {
        border(color.color, width: width)
    }
    
    @ViewBuilder
    func sqBorder(_ color: SQColor, width: CGFloat, cornerRadius: CGFloat = 0, alignment: Alignment? = nil) -> some View {
        if let alignment {
            switch alignment {
            case .bottom, .bottomLeading, .bottomTrailing, .top, .topLeading, .topTrailing:
                // Single line top or bottom border
                overlay (
                    Rectangle()
                        .fill(color.color)
                        .frame(height: width), alignment: alignment)
            case .leading, .trailing:
                // Single line leading or trailing border
                overlay (
                    Rectangle()
                        .fill(color.color)
                        .frame(width: width), alignment: alignment)
            default:
                fatalError("Alignment not supported")
            }
        }
        else {
            // Surrounding border
            overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(color.color, lineWidth: width)
            )
        }
    }
}

// MARK: - Nav Bar Menu

extension View {
    @ViewBuilder
    func sqNavMenu(_ viewModel: SQNavBarViewModel) -> some View {
        modifier(SQNavBarMenu(viewModel: viewModel))
    }
}

struct NavMenuStyle : MenuStyle {
    func makeBody(configuration: Configuration) -> some View {
        Menu(configuration)
    }
}

struct SQNavBarMenu: ViewModifier {
    @ObservedObject var viewModel: SQNavBarViewModel
    
    @ViewBuilder
    var menu: some View {
        SQDropDownMenu(menuViewModel: viewModel.leadingViewModel, isDisabled: !viewModel.allButtonsEnabled)
    }
    
    func body(content: Content) -> some View {
        content
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    menu
                        .opacity(viewModel.isVisible ? 1 : 0)
                        .disabled(!viewModel.isVisible)
                }
            }
    }
}

#if canImport(UIKit)
extension View {
    func sqHideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}
#endif

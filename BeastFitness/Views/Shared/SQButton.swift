//
//  SQButton.swift
//  BeastFitness
//
//  Created by Patrick Doyle on 11/26/25.
//

import SwiftUI

struct WidthHeight {
    let width: CGFloat?
    let height: CGFloat?
}

struct SQButton: View {
    let style: Style
    let shouldHugContent: Bool
    let widthHeight: WidthHeight?
    let title: String?
    let icon: SQImageSymbol?
    let isDisabled: Bool
    let action: () -> Void
    
    init(
        style: Style = .primary,
        shouldHugContent: Bool = false,
        widthHeight: WidthHeight? = nil,
        title: String? = nil,
        icon: SQImageSymbol? = nil,
        isDisabled: Bool = false,
        action: @escaping () -> Void
    ) {
        self.style = style
        self.shouldHugContent = shouldHugContent
        self.widthHeight = widthHeight
        self.title = title
        self.icon = icon
        self.isDisabled = isDisabled
        self.action = action
    }
    
    @ViewBuilder
    var buttonStack: some View {
        HStack(spacing: .SQSpace.s) {
            if let title {
                Text(title)
                    .multilineTextAlignment(.leading)
                    .font(.sqFont(.bodyBold))
                    .foregroundColor(SQColor.textPrimary.color)
            }
            
            if let icon {
                SQImageView(image: .init(symbol: icon))
            }
        }
    }
    
    @ViewBuilder
    var buttonContent: some View {
        buttonStack
            .if(!shouldHugContent) {
                $0.frame(maxWidth: .infinity)
            }
            .if(widthHeight != nil) {
                $0.frame(width: widthHeight?.width, height: widthHeight?.height)
            }
            .if(widthHeight == nil) {
                $0.padding(style.innerPadding)
            }
            .background(isDisabled ? style.disabledBackgroundColor.color : style.backgroundColor.color)
            .cornerRadius(8)
            .opacity(isDisabled ? 0.5 : 1)
    }
    
    var body: some View {
        Button(action: action) {
            buttonContent
        }
        .disabled(isDisabled)
    }
    
    enum Style {
        case primary
        case primarySmall
        case secondary
        
        var backgroundColor: SQColor {
            switch self {
            case .primary, .primarySmall:
                .accent(1)
            case .secondary:
                .backgroundSecondary
            }
        }
        
        var disabledBackgroundColor: SQColor {
            .textDisabled
        }
        
        var innerPadding: CGFloat {
            switch self {
            case .primary, .secondary:
                .SQSpace.xl
            case .primarySmall:
                .SQSpace.m
            }
        }
    }
}

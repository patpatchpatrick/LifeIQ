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
    let isLoading: Bool
    let action: () -> Void
    
    init(
        style: Style = .primary,
        shouldHugContent: Bool = false,
        widthHeight: WidthHeight? = nil,
        title: String? = nil,
        icon: SQImageSymbol? = nil,
        isDisabled: Bool = false,
        isLoading: Bool = false,
        action: @escaping () -> Void
    ) {
        self.style = style
        self.shouldHugContent = shouldHugContent
        self.widthHeight = widthHeight
        self.title = title
        self.icon = icon
        self.isDisabled = isDisabled
        self.isLoading = isLoading
        self.action = action
    }
    
    // MARK: - Content (hidden when loading)
    @ViewBuilder
    var buttonStack: some View {
        HStack(spacing: .SQSpace.m) {
            if let title {
                Text(title)
                    .multilineTextAlignment(.leading)
                    .font(.sqFont(.bodyBold))
                    .foregroundColor(style.foregroundColor.color)
            }
            
            if let icon {
                SQImageView(image: .init(symbol: icon, symbolStyle: .colorWithFont(style.foregroundColor, font: .body)))
                    .frame(height: 15)
            }
        }
        .opacity(isLoading ? 0 : 1)        // 👈 hide while loading
    }
    
    // MARK: - Loading Spinner
    @ViewBuilder
    var loadingSpinner: some View {
        if isLoading {
            ProgressView()
                .progressViewStyle(.circular)
                .tint(style.foregroundColor.color)
        }
    }
    
    // MARK: - Final content
    @ViewBuilder
    var buttonContent: some View {
        ZStack {
            buttonStack
            loadingSpinner     // 👈 overlayed on top when loading
        }
        .if(!shouldHugContent) {
            $0.frame(maxWidth: .infinity)
        }
        .if(widthHeight != nil) {
            $0.frame(width: widthHeight?.width, height: widthHeight?.height)
        }
        .if(widthHeight == nil) {
            $0.padding(style.innerPadding)
        }
        .background(backgroundView)
        .overlay(overlayView)
        .cornerRadius(style.cornerRadius)
        .opacity(isDisabled ? 0.5 : 1)
    }

    @ViewBuilder
    private var backgroundView: some View {
        let backgroundColor = (isDisabled || isLoading)
            ? style.disabledBackgroundColor.color
            : style.backgroundColor.color

        if style == .glassPrimary {
            RoundedRectangle(cornerRadius: style.cornerRadius, style: .continuous)
                .fill(backgroundColor)
        } else {
            RoundedRectangle(cornerRadius: style.cornerRadius, style: .continuous)
                .fill(backgroundColor)
        }
    }

    @ViewBuilder
    private var overlayView: some View {
        if style == .glassPrimary {
            RoundedRectangle(cornerRadius: style.cornerRadius, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(SQColor.isDarkMode ? 0.18 : 0.28),
                            Color.white.opacity(0.03)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .mask(
                    RoundedRectangle(cornerRadius: style.cornerRadius, style: .continuous)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: style.cornerRadius, style: .continuous)
                        .stroke(SQColor.glassStrokeStrong.color, lineWidth: 1)
                )
        }
    }
    
    var body: some View {
        Button(action: action) {
            buttonContent
        }
        .disabled(isDisabled || isLoading)   // 👈 cannot tap while loading
    }
    
    // MARK: - Style
    enum Style: Equatable {
        case primary
        case primarySmall
        case secondary
        case glassPrimary
        
        var backgroundColor: SQColor {
            switch self {
            case .primary, .primarySmall:
                .accent(1)
            case .secondary:
                .backgroundSecondary
            case .glassPrimary:
                .dashboardGlowBlue
            }
        }

        var foregroundColor: SQColor {
            switch self {
            case .glassPrimary:
                .dashboardGlowBlueForeground
            default:
                .textPrimary
            }
        }
        
        var disabledBackgroundColor: SQColor {
            switch self {
            case .glassPrimary:
                .glassCardTint
            default:
                .textDisabled
            }
        }
        
        var innerPadding: CGFloat {
            switch self {
            case .primary, .secondary, .glassPrimary:
                .SQSpace.l
            case .primarySmall:
                .SQSpace.m
            }
        }

        var cornerRadius: CGFloat {
            switch self {
            case .glassPrimary:
                .SQCornerRadius.xl
            default:
                8
            }
        }
    }
}

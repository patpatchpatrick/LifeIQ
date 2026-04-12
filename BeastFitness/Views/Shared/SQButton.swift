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
        let backgroundColor = style.backgroundFillColor(
            isDisabled: isDisabled || isLoading
        )

        if style.usesGlassTreatment {
            RoundedRectangle(cornerRadius: style.cornerRadius, style: .continuous)
                .fill(backgroundColor)
        } else {
            RoundedRectangle(cornerRadius: style.cornerRadius, style: .continuous)
                .fill(backgroundColor)
        }
    }

    @ViewBuilder
    private var overlayView: some View {
        if style.usesGlassTreatment {
            RoundedRectangle(cornerRadius: style.cornerRadius, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(style.glassHighlightOpacity),
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
                        .stroke(style.strokeColor, lineWidth: 1)
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
        
        func backgroundFillColor(isDisabled: Bool) -> Color {
            if isDisabled {
                switch self {
                case .secondary, .glassPrimary:
                    return SQColor.glassCardTint.color
                case .primary, .primarySmall:
                    return SQColor.textDisabled.color
                }
            }

            switch self {
            case .primary, .primarySmall:
                return SQColor.accent(1).color
            case .secondary:
                return SQColor.glassCardTint.color.opacity(SQColor.isDarkMode ? 0.82 : 0.96)
            case .glassPrimary:
                return SQColor.dashboardGlowBlue.color.opacity(SQColor.isDarkMode ? 0.80 : 0.62)
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
            case .secondary, .glassPrimary:
                .SQCornerRadius.xl
            case .primary, .primarySmall:
                8
            }
        }

        var usesGlassTreatment: Bool {
            switch self {
            case .secondary, .glassPrimary:
                true
            case .primary, .primarySmall:
                false
            }
        }

        var strokeColor: Color {
            switch self {
            case .glassPrimary:
                return SQColor.dashboardGlowBlue.color.opacity(SQColor.isDarkMode ? 0.46 : 0.34)
            case .secondary:
                return SQColor.glassStroke.color
            case .primary, .primarySmall:
                return SQColor.border().color
            }
        }

        var glassHighlightOpacity: Double {
            switch self {
            case .glassPrimary:
                return SQColor.isDarkMode ? 0.14 : 0.22
            case .secondary:
                return SQColor.isDarkMode ? 0.10 : 0.18
            case .primary, .primarySmall:
                return 0
            }
        }
    }
}

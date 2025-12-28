//
//  SQPicker.swift
//  BeastFitness
//
//  Created by Patrick Doyle on 12/28/25.
//

import SwiftUI

struct SQDropDown: View {
    let selectedBackgroundColor: SQColor
    let optionsBackgroundColor: SQColor
    
    let options: [SQAlertDropDownViewModel.Option]
    @Binding var selectedId: String

    @State private var isOpen = false
    @State private var optionsHeight: CGFloat = 0

    init(
        options: [SQAlertDropDownViewModel.Option],
        selectedId: Binding<String>,
        selectedBackgroundColor: SQColor = .backgroundSecondaryLight,
        optionsBackgroundColor: SQColor = .backgroundTertiaryDark
    ) {
        self.options = options
        self._selectedId = selectedId
        self.selectedBackgroundColor = selectedBackgroundColor
        self.optionsBackgroundColor = optionsBackgroundColor
        
    }

    var selectedTitle: String {
        options.first { $0.id == selectedId }?.title ?? ""
    }

    var body: some View {
        Button {
            isOpen.toggle()
        } label: {
            HStack {
                Text(selectedTitle)
                    .sqFont(.body)
                    .sqForegroundColor(.accent(1))

                Spacer()

                Image(systemName: SQImageSymbol.chevronDown.rawValue)
                    .font(.system(size: 12, weight: .semibold))
                    .rotationEffect(.degrees(isOpen ? 180 : 0))
            }
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(selectedBackgroundColor.color)
            )
        }
        .buttonStyle(.plain)
        .overlay(alignment: .topLeading) {
            if isOpen {
                optionsList
                    // Move the list above the button:
                    .offset(y: -(optionsHeight + 6)) // 6 = spacing "gap" above the button
                    .opacity(isOpen ? 1 : 0)
                    .zIndex(1)
            }
        }
        .animation(.easeInOut(duration: 0.15), value: isOpen)
    }

    private var optionsList: some View {
        VStack(spacing: 0) {
            ForEach(options) { option in
                Button {
                    selectedId = option.id
                    isOpen = false
                } label: {
                    Text(option.title)
                        .sqFont(.body)
                        .sqForegroundColor(.textPrimary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(10)
                }
                .buttonStyle(.plain)

                if option.id != options.last?.id {
                    Divider()
                }
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(optionsBackgroundColor.color)
        )
        .dropdownShadow()
        .readHeight(into: $optionsHeight)
    }
}

private struct SQHeightPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

private extension View {
    func readHeight(into binding: Binding<CGFloat>) -> some View {
        background(
            GeometryReader { proxy in
                Color.clear
                    .preference(key: SQHeightPreferenceKey.self, value: proxy.size.height)
            }
        )
        .onPreferenceChange(SQHeightPreferenceKey.self) { binding.wrappedValue = $0 }
    }
}

private extension View {
    func dropdownShadow() -> some View {
        self
            // Soft ambient shadow
            .shadow(color: .black.opacity(0.18), radius: 16, x: 0, y: 8)
            // Tight edge shadow (adds separation from background)
            .shadow(color: .black.opacity(0.12), radius: 4, x: 0, y: 2)
    }
}

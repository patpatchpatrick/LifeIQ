//
//  SQAlertCard.swift
//  BeastFitness
//
//  Created by Patrick Doyle on 12/17/25.
//

import SwiftUI

struct SQAlertCard: View {
    let alert: SQAlertViewModel
    let onPrimary: () -> Void
    let onSecondary: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        ZStack(alignment: .topLeading) {
            VStack(spacing: .SQSpace.l) {
                VStack(spacing: 6) {
                    Text(alert.title)
                        .sqFont(.title3)
                        .sqForegroundColor(.textPrimary)
                        .multilineTextAlignment(.center)

                    if let subtitle = alert.subtitle, !subtitle.isEmpty {
                        Text(subtitle)
                            .sqFont(.body)
                            .sqForegroundColor(.textSecondary)
                            .multilineTextAlignment(.center)
                    }
                }

                if let dd = alert.dropDown {
                    dropDownView(dd)
                }

                VStack(spacing: .SQSpace.m) {
                    Button(alert.primary.title) { onPrimary() }
                        .buttonStyle(SQAlertButtonStyle(role: alert.primary.role))
                        .font(SQFont(type: .body).font)

                    if let secondary = alert.secondary {
                        Button(secondary.title) { onSecondary() }
                            .buttonStyle(SQAlertButtonStyle(role: secondary.role))
                            .font(SQFont(type: .body).font)

                    }
                }
            }
            .padding(.SQSpace.xl)

            if alert.canDismiss {
                Button { onDismiss() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .padding(8)
                        .background(Circle().fill(Color.secondary.opacity(0.15)))
                }
                .padding(.SQSpace.xl)
            }
        }
        .frame(maxWidth: 320)
        .sqBackgroundColor(.backgroundSecondary)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(radius: 24)
        .padding(.horizontal, 24)
    }

    @ViewBuilder
    private func dropDownView(_ dd: SQAlertDropDownViewModel) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            if let title = dd.title {
                Text(title)
                    .sqFont(.bodySmallBold)
                    .sqForegroundColor(.textPrimary)
            }

            SQDropDown(
                   options: dd.options,
                   selectedId: Binding(
                       get: { dd.selectedOptionId },
                       set: { dd.selectedOptionId = $0 }
                   )
               )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}


struct SQAlertButtonStyle: ButtonStyle {
    let role: SQAlertViewModel.Action.Role?

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 15, weight: .semibold))
            .frame(maxWidth: .infinity, minHeight: 44)
            .background(backgroundColor)
            .foregroundStyle(foregroundColor)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .opacity(configuration.isPressed ? 0.85 : 1.0)
    }

    private var backgroundColor: Color {
        switch role {
        case .destructive:
            return SQColor.colorErrorRed.color.opacity(0.5)
        case .cancel:
            return SQColor.backgroundSecondaryLight.color
        case .normal, .none:
            return SQColor.accent(1).color
        }
    }

    private var foregroundColor: Color {
        SQColor.textPrimary.color
    }
}

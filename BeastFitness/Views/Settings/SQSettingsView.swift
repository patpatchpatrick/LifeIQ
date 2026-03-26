//
//  SQSettingsView.swift
//  BeastFitness
//
//  Created by Patrick Doyle on 12/17/25.
//

import SwiftUI

struct SQSettingsView: View {
    @Bindable var controller: SQSettingsController

    private var mainScroll: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: .SQSpace.l) {
                heroCard

                VStack(alignment: .leading, spacing: .SQSpace.s) {
                    Text("Preferences")
                        .sqFont(.headerSmall)
                        .sqForegroundColor(.textSecondary)
                        .padding(.horizontal, .SQSpace.xs)

                    ForEach(controller.rows, id: \.id) { row in
                        SQSettingsRowView(row: row)
                    }
                }
            }
            .padding(.horizontal, .SQSpace.l)
            .padding(.top, .SQSpace.l)
            .padding(.bottom, .SQSpace.xl)
        }
    }

    @ViewBuilder
    private var heroCard: some View {
        VStack(spacing: .SQSpace.m) {
            ZStack {
                Circle()
                    .fill(SQColor.glassCardTint.color.opacity(SQColor.isDarkMode ? 0.86 : 0.96))
                    .overlay(
                        Circle()
                            .stroke(SQColor.glassStroke.color, lineWidth: 1)
                    )
                    .frame(width: 78, height: 78)

                SQImageView(
                    image: .init(
                        symbol: .gear,
                        symbolStyle: .colorWithFont(.textPrimary, font: .title2)
                    )
                )
                .frame(width: 30, height: 30)
            }

            VStack(spacing: .SQSpace.xs) {
                Text("Settings")
                    .sqFont(.title3)
                    .sqForegroundColor(.textPrimary)

                Text("Manage preferences, hidden workouts, and advanced options.")
                    .sqFont(.bodyExtraSmall)
                    .sqForegroundColor(.textSecondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, .SQSpace.xl)
        .sqGlassSurface(level: .card, cornerRadius: .SQCornerRadius.xl)
    }

    private var navView: some View {
        mainScroll
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .background {
                SQSheetBackground()
            }
    }

    var body: some View {
        navView
    }
}

private struct SQSettingsRowView: View {
    let row: SQSettingsRowViewModel

    var body: some View {
        Button(action: row.action) {
            HStack(spacing: .SQSpace.m) {
                RoundedRectangle(cornerRadius: .SQCornerRadius.l, style: .continuous)
                    .fill(SQColor.glassCardTint.color.opacity(SQColor.isDarkMode ? 0.84 : 0.96))
                    .frame(width: 38, height: 38)
                    .overlay(
                        RoundedRectangle(cornerRadius: .SQCornerRadius.l, style: .continuous)
                            .stroke(SQColor.glassStroke.color, lineWidth: 1)
                    )
                    .overlay(
                        SQImageView(
                            image: .init(
                                symbol: row.showsChevron ? .gear : .checkmarkCircle,
                                symbolStyle: .colorWithFont(.textPrimary, font: .bodySmall)
                            )
                        )
                        .frame(width: 14, height: 14)
                    )

                VStack(alignment: .leading, spacing: .SQSpace.xs) {
                    Text(row.title)
                        .sqFont(.bodySemiBold)
                        .sqForegroundColor(.textPrimary)

                    if let subtitle = row.subtitle {
                        Text(subtitle)
                            .sqFont(.bodyExtraSmall)
                            .sqForegroundColor(.textSecondary)
                    }
                }

                Spacer(minLength: .SQSpace.m)

                if row.showsChevron {
                    SQImageView(
                        image: .init(
                            symbol: .chevronRight,
                            symbolStyle: .colorWithFont(.textTertiary, font: .bodyExtraSmall)
                        )
                    )
                    .frame(width: 8, height: 12)
                }
            }
            .padding(.horizontal, .SQSpace.l)
            .padding(.vertical, .SQSpace.l)
            .sqGlassSurface(level: .card, cornerRadius: .SQCornerRadius.xl)
        }
        .buttonStyle(.plain)
    }
}

private struct SQSettingsAdvancedView: View {
    let controller: SQSettingsController

    var body: some View {
        VStack(alignment: .leading, spacing: .SQSpace.l) {
            VStack(alignment: .leading, spacing: .SQSpace.xs) {
                Text("Advanced Settings")
                    .sqFont(.title3)
                    .sqForegroundColor(.textPrimary)

                Text("Additional controls and developer-facing options can live here.")
                    .sqFont(.bodyExtraSmall)
                    .sqForegroundColor(.textSecondary)
            }

            SQButton(style: .secondary, shouldHugContent: true, title: "Back") {
                controller.popView()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(.SQSpace.l)
        .background {
            SQSheetBackground()
        }
        .navigationTitle("Advanced")
        .navigationBarTitleDisplayMode(.inline)
    }
}

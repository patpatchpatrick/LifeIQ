//
//  SQSettingsView.swift
//  BeastFitness
//
//  Created by Patrick Doyle on 12/17/25.
//

import SwiftUI

struct SQSettingsView: View {
    @Bindable var controller: SQSettingsController

    private var lastRowId: UUID? { controller.rows.last?.id }

    private var mainScroll: some View {
        List {
            ForEach(controller.rows, id: \.id) { row in
                SQSettingsRowView(
                    row: row,
                    showsDivider: row.id != lastRowId
                )
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }

    private var navView: some View {
        mainScroll
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .background(SQColor.backgroundSheet.color)
    }

    private var navStack: some View {
        NavigationStack(path: $controller.navigationPath) {
            navView
                .navigationDestination(for: SQNavRoute.Settings.self) { route in
                    switch route {
                    case .nested:
                        VStack {
                            Text("Advanced Settings")
                                .sqFont(.title3)
                                .sqForegroundColor(.textPrimary)

                            SQButton(style: .secondary, shouldHugContent: true, title: "Back") {
                                controller.popView()
                            }
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .sqBackgroundColor(.backgroundSheet)
                        .navigationTitle("Advanced")
                        .navigationBarTitleDisplayMode(.inline)
                    }
                }
        }
    }

    var body: some View {
        navStack
    }
}

private struct SQSettingsRowView: View {
    let row: SQSettingsRowViewModel
    let showsDivider: Bool

    var body: some View {
        VStack(spacing: 0) {
            Button(action: row.action) {
                HStack(spacing: .SQSpace.m) {
                    VStack(alignment: .leading, spacing: .SQSpace.xs) {
                        Text(row.title)
                            .sqFont(.body)
                            .sqForegroundColor(.textPrimary)

                        if let subtitle = row.subtitle {
                            Text(subtitle)
                                .sqFont(.bodyBold)
                                .sqForegroundColor(.textSecondary)
                        }
                    }

                    Spacer(minLength: 0)

                    if row.showsChevron {
                        Image(systemName: "chevron.right")
                            .sqForegroundColor(.textSecondary)
                    }
                }
                .padding(.vertical, .SQSpace.l)
                .padding(.horizontal, .SQSpace.xl)
                .background(SQColor.backgroundSheet.color)
            }

            if showsDivider {
                Divider()
                    .sqTintColor(.divider(1))
                    .padding(.horizontal, .SQSpace.xl)
                    .background(SQColor.backgroundSheet.color)
            }
        }
        .listRowInsets(EdgeInsets())
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
    }
}

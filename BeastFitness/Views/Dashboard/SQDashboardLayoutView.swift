//
//  SQDashboardLayoutView.swift
//  BeastFitness
//

import SwiftUI

struct SQDashboardLayoutView: View {
    @Bindable var controller: SQDashboardLayoutController

    var body: some View {
        List {
            Section {
                overviewCard
                    .listRowInsets(.init(top: .SQSpace.l, leading: .SQSpace.l, bottom: .SQSpace.m, trailing: .SQSpace.l))
                    .listRowBackground(Color.clear)
            }

            Section("Sections") {
                ForEach(controller.editableGroups) { group in
                    groupRow(group)
                        .listRowInsets(.init(top: .SQSpace.s, leading: .SQSpace.l, bottom: .SQSpace.s, trailing: .SQSpace.l))
                        .listRowBackground(Color.clear)
                }
                .onMove(perform: controller.moveGroups)
            }

            ForEach(controller.editableGroups) { group in
                Section {
                    ForEach(group.subsections) { subsection in
                        subsectionRow(subsection, in: group)
                            .listRowInsets(.init(top: .SQSpace.s, leading: .SQSpace.xl, bottom: .SQSpace.s, trailing: .SQSpace.l))
                            .listRowBackground(Color.clear)
                    }
                    .onMove { source, destination in
                        controller.moveSubsections(in: group.id, from: source, to: destination)
                    }
                } header: {
                    HStack {
                        Text(group.title)
                            .sqFont(.headerSmall)
                            .sqForegroundColor(.textSecondary)

                        Spacer()

                        Text(group.isHidden ? "Hidden" : "Visible")
                            .sqFont(.bodyExtraSmall)
                            .sqForegroundColor(group.isHidden ? .textTertiary : .textSecondary)
                    }
                    .padding(.horizontal, .SQSpace.l)
                }
            }
        }
        .environment(\.editMode, .constant(.active))
        .scrollContentBackground(.hidden)
        .background {
            SQSheetBackground()
        }
        .navigationTitle("Customize Dashboard")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    controller.dismiss()
                } label: {
                    ZStack {
                        Color.clear

                        SQImageView(
                            image: .init(
                                symbol: .chevronLeft,
                                symbolStyle: .colorWithFont(.textPrimary, font: .title3)
                            )
                        )
                        .frame(width: 16, height: 22)
                    }
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
                }
            }

            ToolbarItem(placement: .topBarTrailing) {
                Button("Reset") {
                    controller.resetLayout()
                }
            }
        }
    }

    private var overviewCard: some View {
        VStack(alignment: .leading, spacing: .SQSpace.m) {
            HStack(spacing: .SQSpace.m) {
                RoundedRectangle(cornerRadius: .SQCornerRadius.l, style: .continuous)
                    .fill(SQColor.glassCardTint.color.opacity(SQColor.isDarkMode ? 0.84 : 0.96))
                    .frame(width: 42, height: 42)
                    .overlay {
                        RoundedRectangle(cornerRadius: .SQCornerRadius.l, style: .continuous)
                            .stroke(SQColor.glassStroke.color, lineWidth: 1)
                    }
                    .overlay {
                        SQImageView(
                            image: .init(
                                symbol: .sliderHorizontal3,
                                symbolStyle: .colorWithFont(.textPrimary, font: .bodySmall)
                            )
                        )
                        .frame(width: 16, height: 16)
                    }

                VStack(alignment: .leading, spacing: .SQSpace.xs) {
                    Text("Reorder and hide dashboard content")
                        .sqFont(.bodySemiBold)
                        .sqForegroundColor(.textPrimary)

                    Text("Drag sections and subsections into the order you want. Hide anything you don’t want on the dashboard. New app sections fall back to their built-in default priority.")
                        .sqFont(.bodyExtraSmall)
                        .sqForegroundColor(.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(.SQSpace.l)
        .sqGlassSurface(level: .card, cornerRadius: .SQCornerRadius.xl)
    }

    private func groupRow(_ group: SQDashboardLayoutEditableGroup) -> some View {
        HStack(spacing: .SQSpace.m) {
            visibilityButton(isHidden: group.isHidden) {
                controller.toggleGroupVisibility(group.id)
            }

            VStack(alignment: .leading, spacing: .SQSpace.xs) {
                Text(group.title)
                    .sqFont(.bodySemiBold)
                    .sqForegroundColor(.textPrimary)

                Text(group.isHidden ? "Hidden from the dashboard" : "Shown on the dashboard")
                    .sqFont(.bodyExtraSmall)
                    .sqForegroundColor(.textSecondary)
            }

            Spacer(minLength: .SQSpace.m)
        }
        .padding(.horizontal, .SQSpace.l)
        .padding(.vertical, .SQSpace.l)
        .sqGlassSurface(level: .card, cornerRadius: .SQCornerRadius.xl)
    }

    private func subsectionRow(
        _ subsection: SQDashboardLayoutEditableSubsection,
        in group: SQDashboardLayoutEditableGroup
    ) -> some View {
        HStack(spacing: .SQSpace.m) {
            visibilityButton(isHidden: subsection.isHidden) {
                controller.toggleSubsectionVisibility(groupId: group.id, subsectionId: subsection.id)
            }

            VStack(alignment: .leading, spacing: .SQSpace.xs) {
                Text(subsection.title)
                    .sqFont(.body)
                    .sqForegroundColor(.textPrimary)

                Text(subsection.isHidden ? "Hidden in \(group.title)" : "Shown in \(group.title)")
                    .sqFont(.bodyExtraSmall)
                    .sqForegroundColor(.textSecondary)
            }

            Spacer(minLength: .SQSpace.m)
        }
        .padding(.horizontal, .SQSpace.l)
        .padding(.vertical, .SQSpace.m)
        .sqGlassSurface(level: .card, cornerRadius: .SQCornerRadius.xl)
    }

    private func visibilityButton(isHidden: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            RoundedRectangle(cornerRadius: .SQCornerRadius.l, style: .continuous)
                .fill(
                    (isHidden ? SQColor.glassCardTint : SQColor.dashboardGlowBlue)
                        .color
                        .opacity(isHidden ? (SQColor.isDarkMode ? 0.72 : 0.92) : (SQColor.isDarkMode ? 0.24 : 0.18))
                )
                .frame(width: 34, height: 34)
                .overlay {
                    RoundedRectangle(cornerRadius: .SQCornerRadius.l, style: .continuous)
                        .stroke(SQColor.glassStroke.color, lineWidth: 1)
                }
                .overlay {
                    SQImageView(
                        image: .init(
                            symbol: isHidden ? .eyeSlash : .eye,
                            symbolStyle: .colorWithFont(.textPrimary, font: .bodyExtraSmall)
                        )
                    )
                    .frame(width: 14, height: 14)
                }
        }
        .buttonStyle(.plain)
    }
}

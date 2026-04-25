//
//  SQViewLabView.swift
//  BeastFitness
//
//  Created by Codex on 4/24/26.
//

import SwiftUI

struct SQViewLabView: View {
    @Bindable var controller: SQViewLabController

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: .SQSpace.l) {
                header
                controls

                switch controller.selectedMode {
                case .gallery:
                    galleryContent
                case .scenario:
                    focusedScenarioContent
                }
            }
            .padding(.horizontal, .SQSpace.l)
            .padding(.top, .SQSpace.l)
            .padding(.bottom, .SQSpace.xl)
        }
        .navigationTitle("View Lab")
        .navigationBarTitleDisplayMode(.inline)
        .background {
            SQSheetBackground()
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: .SQSpace.s) {
            Text("Reusable scenario and engine previews for internal QA.")
                .sqFont(SQFont.FontType.title4)
                .sqForegroundColor(.textPrimary)

            Text(controller.selectedDomain.subtitle)
                .sqFont(SQFont.FontType.bodyExtraSmall)
                .sqForegroundColor(.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var controls: some View {
        VStack(alignment: .leading, spacing: .SQSpace.m) {
            Picker("Mode", selection: $controller.selectedMode) {
                ForEach(SQViewLabController.Mode.allCases) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)

            if SQViewLabController.Domain.allCases.count > 1 {
                Picker("Domain", selection: $controller.selectedDomain) {
                    ForEach(SQViewLabController.Domain.allCases) { domain in
                        Text(domain.rawValue).tag(domain)
                    }
                }
                .pickerStyle(.menu)
            }
        }
    }

    private var galleryContent: some View {
        LazyVStack(alignment: .leading, spacing: .SQSpace.l) {
            ForEach(controller.currentScenarios) { scenario in
                galleryCard(for: scenario)
            }
        }
    }

    private var focusedScenarioContent: some View {
        VStack(alignment: .leading, spacing: .SQSpace.l) {
            if controller.currentScenarios.count > 1 {
                VStack(alignment: .leading, spacing: .SQSpace.xs) {
                    Text("Scenario")
                        .sqFont(SQFont.FontType.headerSmall)
                        .sqForegroundColor(.textSecondary)

                    Picker("Scenario", selection: $controller.selectedScenarioId) {
                        ForEach(controller.currentScenarios) { scenario in
                            Text(scenario.title).tag(scenario.id)
                        }
                    }
                    .pickerStyle(.menu)
                }
            }

            if let scenario = controller.selectedScenario {
                scenarioDetail(for: scenario)
            }
        }
    }

    private func galleryCard(for scenario: SQViewLabController.Scenario) -> some View {
        VStack(alignment: .leading, spacing: .SQSpace.m) {
            HStack(alignment: .top, spacing: .SQSpace.m) {
                VStack(alignment: .leading, spacing: .SQSpace.xs) {
                    Text(scenario.title)
                        .sqFont(SQFont.FontType.title4)
                        .sqForegroundColor(.textPrimary)

                    Text(scenario.subtitle)
                        .sqFont(SQFont.FontType.bodyExtraSmall)
                        .sqForegroundColor(.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)

                Button("Focus") {
                    controller.focus(on: scenario)
                }
                .buttonStyle(.plain)
                .font(.sqFont(SQFont.FontType.bodyExtraSmall))
                .sqForegroundColor(.dashboardGlowBlue)
            }

            if !scenario.tags.isEmpty {
                tagRow(scenario.tags)
            }

            preview(
                for: scenario,
                runtime: controller.runtime(for: scenario),
                isFocused: false
            )
        }
        .padding(.SQSpace.l)
        .sqGlassSurface(level: .card, cornerRadius: .SQCornerRadius.xl)
        .contentShape(Rectangle())
        .onTapGesture {
            controller.focus(on: scenario)
        }
    }

    private func scenarioDetail(for scenario: SQViewLabController.Scenario) -> some View {
        VStack(alignment: .leading, spacing: .SQSpace.m) {
            VStack(alignment: .leading, spacing: .SQSpace.xs) {
                Text(scenario.title)
                    .sqFont(SQFont.FontType.title3)
                    .sqForegroundColor(.textPrimary)

                Text(scenario.subtitle)
                    .sqFont(SQFont.FontType.bodyExtraSmall)
                    .sqForegroundColor(.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if !scenario.tags.isEmpty {
                tagRow(scenario.tags)
            }

            if let runtime = controller.selectedScenarioRuntime {
                preview(for: scenario, runtime: runtime, isFocused: true)
                engineInspector(for: runtime)
            }

            if !scenario.notes.isEmpty {
                VStack(alignment: .leading, spacing: .SQSpace.s) {
                    Text("What This Is Testing")
                        .sqFont(SQFont.FontType.headerSmall)
                        .sqForegroundColor(.textSecondary)

                    ForEach(scenario.notes, id: \.self) { note in
                        HStack(alignment: .top, spacing: .SQSpace.s) {
                            Circle()
                                .fill(SQColor.dashboardGlowBlue.color)
                                .frame(width: 6, height: 6)
                                .padding(.top, 6)

                            Text(note)
                                .sqFont(SQFont.FontType.bodyExtraSmall)
                                .sqForegroundColor(.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                .padding(.SQSpace.l)
                .sqGlassSurface(level: .card, cornerRadius: .SQCornerRadius.xl)
            }
        }
    }

    @ViewBuilder
    private func preview(
        for scenario: SQViewLabController.Scenario,
        runtime: SQViewLabScenarioRuntime,
        isFocused: Bool
    ) -> some View {
        switch runtime.content {
        case .lifeScoreInsights(let content):
            lifeScorePreview(
                scenario: scenario,
                content: content,
                isFocused: isFocused
            )
        }
    }

    private func lifeScorePreview(
        scenario: SQViewLabController.Scenario,
        content: SQViewLabLifeScoreInsightsRuntime,
        isFocused: Bool
    ) -> some View {
        VStack(alignment: .leading, spacing: .SQSpace.m) {
            SQLifeScoreHeroCard(
                viewModel: content.lifeScoreViewModel,
                timeRange: content.timeRange,
                onOpenDetail: isFocused ? {
                    controller.openDetail(for: .init(
                        scenarioId: scenario.id,
                        content: .lifeScoreInsights(content)
                    ))
                } : nil
            )

            if !content.lifeScoreViewModel.changes.isEmpty {
                SQLifeScoreRecentChangesCard(
                    changes: Array(content.lifeScoreViewModel.changes.prefix(3))
                )
            }

            if isFocused {
                Button {
                    controller.openDetail(for: .init(
                        scenarioId: scenario.id,
                        content: .lifeScoreInsights(content)
                    ))
                } label: {
                    Text("Open detail preview")
                        .sqFont(SQFont.FontType.bodyExtraSmall)
                        .sqForegroundColor(.dashboardGlowBlue)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.plain)
                .padding(.top, .SQSpace.xs)
            }
        }
        .padding(.SQSpace.l)
        .background {
            RoundedRectangle(cornerRadius: .SQCornerRadius.xl, style: .continuous)
                .fill(SQColor.backgroundSecondary.color.opacity(SQColor.isDarkMode ? 0.50 : 0.76))
                .overlay {
                    RoundedRectangle(cornerRadius: .SQCornerRadius.xl, style: .continuous)
                        .stroke(SQColor.glassStroke.color.opacity(0.50), lineWidth: 1)
                }
        }
    }

    @ViewBuilder
    private func engineInspector(for runtime: SQViewLabScenarioRuntime) -> some View {
        switch runtime.content {
        case .lifeScoreInsights(let content):
            VStack(alignment: .leading, spacing: .SQSpace.m) {
                Text("Engine Output")
                    .sqFont(SQFont.FontType.title4)
                    .sqForegroundColor(.textPrimary)

                outputGroup(
                    title: "Scenario Input",
                    values: [
                        "Time Range: \(content.input.timeRange.rawValue)",
                        "Check-Ins: \(content.input.checkIns.count)",
                        "Workouts: \(content.input.workouts.count)",
                        "Sleep: \(content.input.sleepData == nil ? "Missing" : "Provided")"
                    ]
                )
                outputGroup(
                    title: "Life Score Output",
                    values: [
                        "Score: \(content.lifeScoreViewModel.score.map(String.init) ?? "Calibrating")",
                        "State: \(content.lifeScoreViewModel.state.title)",
                        "Delta: \(content.lifeScoreViewModel.scoreDeltaText ?? "None")"
                    ]
                )
                outputGroup(
                    title: "Surfaced Insights",
                    values: content.insightsResult.insights.map(\.title)
                )
                outputGroup(
                    title: "Drivers",
                    values: content.insightsResult.drivers.map { "\($0.direction == .supportive ? "+" : "-") \($0.title)" }
                )
                outputGroup(
                    title: "Recent Changes",
                    values: content.insightsResult.changes.map { "\($0.direction == .improved ? "↑" : "↓") \($0.title)" }
                )
                outputGroup(
                    title: "Actions",
                    values: content.insightsResult.actions.map(\.title)
                )
            }
            .padding(.SQSpace.l)
            .sqGlassSurface(level: .card, cornerRadius: .SQCornerRadius.xl)
        }
    }

    private func outputGroup(title: String, values: [String]) -> some View {
        VStack(alignment: .leading, spacing: .SQSpace.xs) {
            Text(title.uppercased())
                .sqFont(SQFont.FontType.headerSmall)
                .sqForegroundColor(.textSecondary)

            if values.isEmpty {
                Text("None")
                    .sqFont(SQFont.FontType.bodyExtraSmall)
                    .sqForegroundColor(.textSecondary)
            } else {
                ForEach(values, id: \.self) { value in
                    HStack(alignment: .top, spacing: .SQSpace.s) {
                        Circle()
                            .fill(SQColor.dashboardGlowBlue.color)
                            .frame(width: 6, height: 6)
                            .padding(.top, 6)

                        Text(value)
                            .sqFont(SQFont.FontType.bodyExtraSmall)
                            .sqForegroundColor(.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
    }

    private func tagRow(_ tags: [String]) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: .SQSpace.xs) {
                ForEach(tags, id: \.self) { tag in
                    Text(tag)
                        .sqFont(SQFont.FontType.bodyExtraSmall)
                        .sqForegroundColor(.textSecondary)
                        .padding(.vertical, 4)
                        .padding(.horizontal, 8)
                        .background {
                            Capsule(style: .continuous)
                                .fill(SQColor.backgroundSecondary.color.opacity(SQColor.isDarkMode ? 0.52 : 0.72))
                        }
                }
            }
        }
    }
}

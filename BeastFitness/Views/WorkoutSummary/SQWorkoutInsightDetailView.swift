//
//  SQWorkoutInsightDetailView.swift
//  BeastFitness
//

import SwiftUI

struct SQWorkoutInsightDetailView: View {
    @State var controller: SQWorkoutInsightDetailController

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: .SQSpace.xl) {
                heroCard

                if !breakdownComponents.isEmpty {
                    breakdownCard
                }

                if !controller.model.examples.isEmpty {
                    guideCard
                }

                if let footnote = controller.model.footnote {
                    noteCard(footnote)
                }
            }
            .padding(.horizontal, .SQSpace.xl)
            .padding(.top, .SQSpace.xl)
            .padding(.bottom, 20)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .navigationTitle(controller.model.title)
        .navigationBarTitleDisplayMode(.inline)
        .background {
            SQSheetBackground()
        }
    }

    private var heroCard: some View {
        VStack(alignment: .leading, spacing: .SQSpace.l) {
            HStack(alignment: .firstTextBaseline, spacing: .SQSpace.s) {
                Text(displayScoreText)
                    .sqFont(.title1)
                    .sqForegroundColor(.textPrimary)

                Text("— \(scoreStateTitle)")
                    .sqFont(.title4)
                    .sqForegroundColor(.textSecondary)
            }

            Text(controller.model.subtitle)
                .sqFont(.bodyExtraSmall)
                .sqForegroundColor(.textPrimary)
                .fixedSize(horizontal: false, vertical: true)

            Text(controller.model.summary)
                .sqFont(.bodyExtraSmall)
                .sqForegroundColor(.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.SQSpace.xl)
        .sqGlassSurface(level: .card, cornerRadius: .SQCornerRadius.xl)
    }

    private var breakdownCard: some View {
        VStack(alignment: .leading, spacing: .SQSpace.l) {
            Text("How This Score Is Calculated")
                .sqFont(.title4)
                .sqForegroundColor(.textPrimary)

            VStack(alignment: .leading, spacing: .SQSpace.m) {
                ForEach(breakdownComponents) { component in
                    componentCard(component)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.SQSpace.xl)
        .sqGlassSurface(level: .card, cornerRadius: .SQCornerRadius.xl)
    }

    private var guideCard: some View {
        VStack(alignment: .leading, spacing: .SQSpace.l) {
            Text("How To Read This Score")
                .sqFont(.title4)
                .sqForegroundColor(.textPrimary)

            VStack(alignment: .leading, spacing: .SQSpace.m) {
                ForEach(controller.model.examples) { example in
                    exampleRow(example)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.SQSpace.xl)
        .sqGlassSurface(level: .card, cornerRadius: .SQCornerRadius.xl)
    }

    private func exampleRow(_ example: SQWorkoutPremiumInsightDetailModel.Example) -> some View {
        VStack(alignment: .leading, spacing: .SQSpace.xs) {
            HStack(alignment: .firstTextBaseline, spacing: .SQSpace.s) {
                Text(example.range)
                    .sqFont(.bodySmallSemiBold)
                    .sqForegroundColor(.textPrimary)

                Spacer(minLength: 0)

                Text(example.title)
                    .sqFont(.bodyExtraSmall)
                    .sqForegroundColor(.textSecondary)
            }

            Text(example.detail)
                .sqFont(.bodyExtraSmall)
                .sqForegroundColor(.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, .SQSpace.xs)
    }

    private func noteCard(_ footnote: String) -> some View {
        VStack(alignment: .leading, spacing: .SQSpace.s) {
            Text("Note")
                .sqFont(.title4)
                .sqForegroundColor(.textPrimary)

            Text(footnote)
                .sqFont(.bodyExtraSmall)
                .sqForegroundColor(.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.SQSpace.xl)
        .sqGlassSurface(level: .card, cornerRadius: .SQCornerRadius.xl)
    }

    private var overallComponent: SQWorkoutPremiumInsightDetailModel.Component? {
        controller.model.components.first(where: { $0.id == "overall" || $0.id == "overall-difficulty" })
            ?? controller.model.components.first
    }

    private var breakdownComponents: [SQWorkoutPremiumInsightDetailModel.Component] {
        let overallId = overallComponent?.id
        return controller.model.components.filter { $0.id != overallId }
    }

    private var displayScoreText: String {
        overallComponent?.value ?? "--/100"
    }

    private var scoreValue: Int? {
        guard let numericText = displayScoreText.split(separator: "/").first else { return nil }
        return Int(numericText)
    }

    private var scoreStateTitle: String {
        guard let scoreValue else { return "Locked" }
        switch scoreValue {
        case 85...:
            return "Strong"
        case 70...84:
            return "Good"
        case 50...69:
            return "Mixed"
        default:
            return "Low"
        }
    }

    private func componentCard(_ component: SQWorkoutPremiumInsightDetailModel.Component) -> some View {
        VStack(alignment: .leading, spacing: .SQSpace.s) {
            HStack(alignment: .top, spacing: .SQSpace.s) {
                Circle()
                    .fill(component.accentColor.color)
                    .frame(width: 10, height: 10)
                    .padding(.top, 4)

                VStack(alignment: .leading, spacing: .SQSpace.s) {
                    HStack(alignment: .firstTextBaseline, spacing: .SQSpace.s) {
                        Text(component.title)
                            .sqFont(.bodySmallSemiBold)
                            .sqForegroundColor(.textPrimary)

                        Spacer(minLength: 0)

                        Text(component.value)
                            .sqFont(.title4)
                            .sqForegroundColor(.textPrimary)
                    }

                    Text(component.detail)
                        .sqFont(.bodyExtraSmall)
                        .sqForegroundColor(.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)

                    if !component.definitionLines.isEmpty {
                        WorkoutScoreDefinitionLinesView(lines: component.definitionLines)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.SQSpace.l)
        .background {
            RoundedRectangle(cornerRadius: .SQCornerRadius.xl, style: .continuous)
                .fill(SQColor.glassCardTint.color.opacity(SQColor.isDarkMode ? 0.78 : 0.98))
                .overlay {
                    RoundedRectangle(cornerRadius: .SQCornerRadius.xl, style: .continuous)
                        .stroke(component.accentColor.color.opacity(SQColor.isDarkMode ? 0.24 : 0.16), lineWidth: 1)
                }
        }
    }
}

private struct WorkoutScoreDefinitionLinesView: View {
    let lines: [SQWorkoutPremiumInsightDetailModel.DefinitionLine]

    var body: some View {
        VStack(alignment: .leading, spacing: .SQSpace.xs) {
            ForEach(lines) { line in
                HStack(alignment: .firstTextBaseline, spacing: .SQSpace.xs) {
                    Text(line.valueText)
                        .sqFont(.bodySmallSemiBold)
                        .sqForegroundColor(.textSecondary)

                    Text(line.summaryText)
                        .sqFont(.bodyExtraSmall)
                        .sqForegroundColor(.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)

                    Spacer(minLength: 0)
                }
            }
        }
        .padding(.top, .SQSpace.xs)
    }
}

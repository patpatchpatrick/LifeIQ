//
//  SQLifeScoreHeroComponents.swift
//  BeastFitness
//
//  Created by Codex on 4/24/26.
//

import SwiftUI

struct SQLifeScoreHeroCard: View {
    let viewModel: SQLifeScoreViewModel
    let timeRange: AppTimeRange
    let onOpenDetail: (() -> Void)?

    private var shouldShowTodayBriefing: Bool {
        timeRange == .today && (
            viewModel.headlineText != nil
            || viewModel.primaryInsight != nil
            || viewModel.refinementPromptText != nil
        )
    }

    private var scoreDeltaColor: SQColor {
        guard let scoreDelta = viewModel.scoreDeltaFromPreviousDay else { return .textSecondary }
        if scoreDelta > 0 {
            return .dashboardGlowMint
        } else if scoreDelta < 0 {
            return .colorErrorRed
        } else {
            return .textSecondary
        }
    }

    private var scoreDeltaSymbol: SQImageSymbol? {
        guard let scoreDelta = viewModel.scoreDeltaFromPreviousDay, scoreDelta != 0 else { return nil }
        return scoreDelta > 0 ? .arrowUp : .arrowDown
    }

    private var primaryAction: SQInsightAction? {
        viewModel.actions.first
    }

    private var compactActionText: String? {
        guard let summary = primaryAction?.summary else { return nil }
        let cleaned = summary
            .replacingOccurrences(of: "This recent shift looks favorable. ", with: "")
            .replacingOccurrences(of: "Keep the pattern steady and see if it holds.", with: "Keep it steady.")
            .replacingOccurrences(of: " while it holds and see if the rest of the day follows.", with: " while it holds.")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return punctuatedSentence(cleaned)
    }

    private func humanizedHeroText(_ text: String) -> String {
        let humanized = text
            .replacingOccurrences(of: "Sleep Quality", with: "Sleep")
            .replacingOccurrences(of: "Sleep Hours", with: "Sleep")
            .replacingOccurrences(of: "Workout Performance", with: "Performance")
        return punctuatedSentence(humanized)
    }

    private func punctuatedSentence(_ text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return trimmed }

        let endingPunctuation = CharacterSet(charactersIn: ".!?")
        if let scalar = trimmed.unicodeScalars.last, endingPunctuation.contains(scalar) {
            return trimmed
        }

        return "\(trimmed)."
    }

    var body: some View {
        VStack(spacing: .SQSpace.m) {
            VStack(spacing: .SQSpace.s) {
                SQLifeScoreOrbView(viewModel: viewModel, size: 156, scoreFont: .title1)

                if let scoreDeltaText = viewModel.scoreDeltaText,
                   let scoreDeltaSymbol,
                   shouldShowTodayBriefing {
                    HStack(alignment: .center, spacing: 4) {
                        SQImageView(
                            image: .init(
                                symbol: scoreDeltaSymbol,
                                symbolStyle: .colorWithFont(scoreDeltaColor, font: .bodyExtraSmall)
                            )
                        )
                        .frame(width: 10, height: 10)

                        Text(scoreDeltaText.replacingOccurrences(of: "↑ ", with: "").replacingOccurrences(of: "↓ ", with: ""))
                            .sqFont(.bodyExtraSmall)
                            .sqForegroundColor(.textSecondary)
                    }
                }

                Text(viewModel.state.title)
                    .sqFont(.bodySmallSemiBold)
                    .sqForegroundColor(.textSecondary)

                if shouldShowTodayBriefing {
                    VStack(spacing: .SQSpace.s) {
                        if let summaryText = viewModel.headlineText ?? viewModel.primaryInsight?.title {
                            heroBriefing(
                                summary: humanizedHeroText(summaryText),
                                action: compactActionText
                            )
                            .padding(.top, .SQSpace.m)
                        }

                        if let refinementPromptText = viewModel.refinementPromptText {
                            HeroBriefingRow(
                                text: punctuatedSentence(refinementPromptText),
                                tone: .refinement
                            )
                            .frame(maxWidth: 300, alignment: .leading)
                        }
                    }
                    .padding(.top, .SQSpace.s)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                onOpenDetail?()
            }

        }
        .frame(maxWidth: .infinity)
        .padding(.top, 18)
        .padding(.bottom, 10)
    }

    private func heroBriefing(summary: String, action: String?) -> some View {
        VStack(alignment: .leading, spacing: .SQSpace.s) {
            HeroBriefingRow(
                text: summary,
                tone: .summary
            )

            if let action, !action.isEmpty {
                HeroBriefingRow(
                    text: action,
                    tone: .action
                )
            }
        }
        .frame(maxWidth: 300, alignment: .leading)
    }
}

struct SQLifeScoreRecentChangesCard: View {
    let changes: [SQInsightChange]
    let onAccessoryTap: (() -> Void)?

    init(
        changes: [SQInsightChange],
        onAccessoryTap: (() -> Void)? = nil
    ) {
        self.changes = changes
        self.onAccessoryTap = onAccessoryTap
    }

    var body: some View {
        VStack(alignment: .leading, spacing: .SQSpace.s) {
            HStack(spacing: .SQSpace.s) {
                Text("Recently (2 days)")
                    .sqFont(.headerSmall)
                    .sqForegroundColor(.textSecondary)

                Spacer(minLength: 0)

                if let onAccessoryTap {
                    Button {
                        onAccessoryTap()
                    } label: {
                        SQImageView(
                            image: .init(
                                symbol: .chevronRight,
                                symbolStyle: .colorWithFont(.textSecondary, font: .bodyExtraSmall)
                            )
                        )
                        .frame(width: 12, height: 12)
                    }
                    .buttonStyle(.plain)
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                ForEach(changes) { change in
                    HeroChangeRow(change: change)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.SQSpace.l)
        .background {
            RoundedRectangle(cornerRadius: .SQCornerRadius.xl, style: .continuous)
                .fill(SQColor.glassCardTint.color.opacity(SQColor.isDarkMode ? 0.52 : 0.72))
                .overlay {
                    RoundedRectangle(cornerRadius: .SQCornerRadius.xl, style: .continuous)
                        .stroke(SQColor.glassStroke.color.opacity(0.65), lineWidth: 1)
                }
        }
    }
}

struct HeroDriverChip: View {
    let driver: SQInsightDriver

    private var color: SQColor {
        driver.direction == .supportive ? .dashboardGlowMint : .colorErrorRed
    }

    private var symbolText: String {
        driver.direction == .supportive ? "+" : "-"
    }

    private var movementSymbolText: String {
        let normalizedDeltaText = driver.deltaText.trimmingCharacters(in: .whitespacesAndNewlines)

        if normalizedDeltaText.contains("-") {
            return "↓"
        } else if normalizedDeltaText.contains("+") {
            return "↑"
        } else if driver.recentAverage > driver.baselineAverage {
            return "↑"
        } else if driver.recentAverage < driver.baselineAverage {
            return "↓"
        } else {
            return "→"
        }
    }

    var body: some View {
        HStack(alignment: .center, spacing: 4) {
            Text(symbolText)
                .sqFont(.bodyExtraSmall)
                .sqForegroundColor(.textPrimary)
                .frame(width: 7, alignment: .center)

            Text(driver.title)
                .sqFont(.bodyExtraSmall)
                .sqForegroundColor(.textPrimary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: 78, alignment: .center)

            Text(movementSymbolText)
                .sqFont(.bodyExtraSmall)
                .sqForegroundColor(.textPrimary)
                .frame(width: 8, alignment: .center)
        }
        .frame(maxWidth: 104, minHeight: 24)
        .padding(.vertical, 3)
        .padding(.horizontal, 4)
        .background {
            Capsule(style: .continuous)
                .fill(color.color.opacity(SQColor.isDarkMode ? 0.16 : 0.10))
        }
        .overlay {
            Capsule(style: .continuous)
                .stroke(color.color.opacity(SQColor.isDarkMode ? 0.30 : 0.20), lineWidth: 1)
        }
    }
}

struct HeroChangeRow: View {
    let change: SQInsightChange

    private var color: SQColor {
        change.direction == .improved ? .dashboardGlowMint : .colorErrorRed
    }

    private var symbolText: String {
        change.direction == .improved ? "↑" : "↓"
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: .SQSpace.xs) {
            Text(symbolText)
                .sqFont(.bodyExtraSmall)
                .sqForegroundColor(color)

            Text(change.title)
                .sqFont(.bodyExtraSmall)
                .sqForegroundColor(.textPrimary)
                .lineLimit(1)
        }
    }
}

struct HeroBriefingRow: View {
    enum Tone {
        case summary
        case action
        case refinement
    }

    let text: String
    let tone: Tone

    private var color: SQColor {
        switch tone {
        case .summary:
            return .textPrimary
        case .action:
            return .textSecondary
        case .refinement:
            return .dashboardGlowBlue
        }
    }

    var body: some View {
        Text(text)
            .sqFont(.bodyExtraSmall)
            .sqForegroundColor(color)
            .fixedSize(horizontal: false, vertical: true)
    }
}

struct SQLifeScoreOrbView: View {
    let viewModel: SQLifeScoreViewModel
    let size: CGFloat
    let scoreFont: SQFont.FontType

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isAnimating = false

    private var auraSize: CGFloat { size * 0.98 }
    private var orbSize: CGFloat { size * 0.72 }
    private var currentLineWidth: CGFloat { max(6, size * 0.055) }
    private var usesQuePalette: Bool {
        switch viewModel.state {
        case .strong:
            return true
        case .primed, .balanced, .rebounding, .slightlyOff, .dipping, .underPressure, .calibrating:
            return false
        }
    }
    private var primaryAccent: Color {
        usesQuePalette ? SQColor.hex("#6FCFF6").color : viewModel.state.primaryColor.color
    }
    private var secondaryAccent: Color {
        usesQuePalette ? SQColor.hex("#35D9E1").color : viewModel.state.secondaryColor.color
    }
    private var deepAccent: Color {
        usesQuePalette ? SQColor.hex("#2A76D9").color : viewModel.state.primaryColor.color
    }
    private var mintAccent: Color {
        usesQuePalette ? SQColor.hex("#8CEEBB").color : viewModel.state.secondaryColor.color
    }
    private var greenAccent: Color {
        usesQuePalette ? SQColor.hex("#B8F47D").color : viewModel.state.secondaryColor.color
    }

    var body: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color.clear,
                            secondaryAccent.opacity(usesQuePalette ? (SQColor.isDarkMode ? 0.11 : 0.08) : (SQColor.isDarkMode ? 0.10 : 0.08)),
                            primaryAccent.opacity(usesQuePalette ? (SQColor.isDarkMode ? 0.34 : 0.24) : (SQColor.isDarkMode ? 0.34 : 0.24)),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: auraSize * 0.12,
                        endRadius: auraSize * 0.52
                    )
                )
                .frame(width: auraSize, height: auraSize)
                .blur(radius: size * 0.08)
                .scaleEffect(usesQuePalette ? (isAnimating ? 1.04 : 0.99) : (isAnimating ? 1.06 : 0.99))
                .opacity(usesQuePalette ? (isAnimating ? 0.88 : 0.70) : (isAnimating ? 0.96 : 0.78))
                .shadow(
                    color: primaryAccent.opacity(usesQuePalette ? (SQColor.isDarkMode ? 0.42 : 0.26) : (SQColor.isDarkMode ? 0.45 : 0.24)),
                    radius: size * 0.16,
                    x: 0,
                    y: 0
                )

            Circle()
                .fill(
                    RadialGradient(
                        colors: usesQuePalette ? [
                            Color.white.opacity(SQColor.isDarkMode ? 0.06 : 0.04),
                            secondaryAccent.opacity(SQColor.isDarkMode ? 0.28 : 0.20),
                            primaryAccent.opacity(SQColor.isDarkMode ? 0.34 : 0.24),
                            Color.clear,
                            deepAccent.opacity(SQColor.isDarkMode ? 0.64 : 0.48)
                        ] : [
                            Color.white.opacity(SQColor.isDarkMode ? 0.10 : 0.08),
                            secondaryAccent.opacity(SQColor.isDarkMode ? 0.18 : 0.14),
                            primaryAccent.opacity(SQColor.isDarkMode ? 0.24 : 0.18),
                            Color.clear,
                            primaryAccent.opacity(SQColor.isDarkMode ? 0.74 : 0.56)
                        ],
                        center: usesQuePalette ? .init(x: 0.47, y: 0.40) : .init(x: 0.47, y: 0.44),
                        startRadius: 1,
                        endRadius: orbSize * 0.74
                    )
                )
                .frame(width: orbSize, height: orbSize)
                .overlay {
                    if usesQuePalette {
                        Circle()
                            .fill(
                                RadialGradient(
                                    colors: [
                                        greenAccent.opacity(SQColor.isDarkMode ? 0.54 : 0.42),
                                        mintAccent.opacity(SQColor.isDarkMode ? 0.34 : 0.26),
                                        secondaryAccent.opacity(SQColor.isDarkMode ? 0.10 : 0.08),
                                        Color.clear
                                    ],
                                    center: .init(x: 0.52, y: 0.90),
                                    startRadius: 0,
                                    endRadius: orbSize * 0.58
                                )
                            )
                    }
                }
                .overlay {
                    if usesQuePalette {
                        Circle()
                            .trim(from: 0.55, to: 0.95)
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        mintAccent.opacity(0.35),
                                        greenAccent.opacity(0.76),
                                        secondaryAccent.opacity(0.42)
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                ),
                                style: StrokeStyle(lineWidth: currentLineWidth * 0.78, lineCap: .round)
                            )
                            .frame(width: orbSize * 0.84, height: orbSize * 0.84)
                            .rotationEffect(.degrees(isAnimating ? -11 : -7))
                            .blur(radius: 0.55)
                            .shadow(color: greenAccent.opacity(0.20), radius: 8, x: 0, y: 2)
                    }
                }
                .overlay {
                    Circle()
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(usesQuePalette ? 0.42 : 0.95),
                                    usesQuePalette ? primaryAccent.opacity(0.46) : secondaryAccent.opacity(0.55),
                                    usesQuePalette ? mintAccent.opacity(0.46) : viewModel.state.primaryColor.color.opacity(0.88)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.4
                        )
                        .blur(radius: 0.4)
                }
                .overlay {
                    Circle()
                        .stroke(
                            AngularGradient(
                                colors: [
                                    primaryAccent.opacity(0.0),
                                    primaryAccent.opacity(usesQuePalette ? 0.10 : 0.60),
                                    Color.white.opacity(usesQuePalette ? 0.04 : 0.85),
                                    mintAccent.opacity(usesQuePalette ? 0.16 : 0.55),
                                    primaryAccent.opacity(0.0)
                                ],
                                center: .center
                            ),
                            lineWidth: usesQuePalette ? currentLineWidth * 0.5 : currentLineWidth
                        )
                        .frame(width: orbSize * 0.90, height: orbSize * 0.90)
                        .blur(radius: 7)
                        .rotationEffect(.degrees(isAnimating ? 18 : -12))
                        .scaleEffect(isAnimating ? 1.02 : 0.98)
                }

            Group {
                if !usesQuePalette {
                    Circle()
                        .trim(from: 0.10, to: 0.58)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.06),
                                    primaryAccent.opacity(0.65),
                                    deepAccent.opacity(0.10)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            style: StrokeStyle(lineWidth: currentLineWidth, lineCap: .round)
                        )
                        .frame(width: orbSize * 0.76, height: orbSize * 0.76)
                        .rotationEffect(.degrees(isAnimating ? 142 : 116))
                        .blur(radius: 2.4)
                }

                if !usesQuePalette {
                    Circle()
                        .trim(from: 0.28, to: 0.76)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color.clear,
                                    deepAccent.opacity(0.46),
                                    Color.white.opacity(0.30),
                                    Color.clear
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            ),
                            style: StrokeStyle(lineWidth: currentLineWidth * 0.7, lineCap: .round)
                        )
                        .frame(width: orbSize * 0.58, height: orbSize * 0.58)
                        .rotationEffect(.degrees(isAnimating ? -38 : -12))
                        .blur(radius: 1.8)
                }
            }
            .blendMode(.plusLighter)

            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color.white.opacity(usesQuePalette ? 0.04 : 0.03),
                            secondaryAccent.opacity(usesQuePalette ? 0.08 : 0.08),
                            SQColor.background.color.opacity(SQColor.isDarkMode ? 0.06 : 0.04),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: orbSize * 0.22
                    )
                )
                .frame(width: orbSize * 0.54, height: orbSize * 0.54)
                .blur(radius: 6)

            Text(viewModel.scoreText)
                .sqFont(scoreFont)
                .sqForegroundColor(.textPrimary)
                .shadow(
                    color: primaryAccent.opacity(0.26),
                    radius: 10,
                    x: 0,
                    y: 0
                )
        }
        .frame(width: size, height: size)
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true)) {
                isAnimating = true
            }
        }
    }
}

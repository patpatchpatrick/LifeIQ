//
//  SQLaunchTutorialView.swift
//  BeastFitness
//
//  Created by Codex on 4/19/26.
//

import SwiftUI

struct SQLaunchTutorialView: View {
    @Bindable var controller: SQLaunchTutorialController

    var body: some View {
        ZStack {
            SQSheetBackground()

            ScrollView(showsIndicators: false) {
                VStack(spacing: .SQSpace.l) {
                    header
                    heroCard
                    detailCard
                    actionArea
                }
                .padding(.horizontal, .SQSpace.l)
                .padding(.vertical, .SQSpace.xl)
                .frame(maxWidth: 560)
                .frame(maxWidth: .infinity)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .interactiveDismissDisabled(true)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: .SQSpace.m) {
            HStack {
                if controller.canGoBack {
                    Button(action: controller.goBack) {
                        HStack(spacing: .SQSpace.xs) {
                            SQImageView(
                                image: .init(
                                    symbol: .chevronLeft,
                                    symbolStyle: .colorWithFont(.textSecondary, font: .bodyExtraSmall)
                                )
                            )
                            .frame(width: 10, height: 10)

                            Text("Back")
                                .sqFont(.bodyExtraSmall)
                                .sqForegroundColor(.textSecondary)
                        }
                        .padding(.horizontal, .SQSpace.s)
                        .padding(.vertical, 6)
                        .background {
                            Capsule(style: .continuous)
                                .fill(SQColor.glassCardTint.color.opacity(SQColor.isDarkMode ? 0.76 : 0.96))
                                .overlay {
                                    Capsule(style: .continuous)
                                        .stroke(SQColor.glassStroke.color, lineWidth: 1)
                                }
                        }
                    }
                    .buttonStyle(.plain)
                }

                Spacer()

                Text(controller.progressTitle)
                    .sqFont(.bodyExtraSmall)
                    .sqForegroundColor(.textSecondary)
            }

            HStack(spacing: .SQSpace.xs) {
                ForEach(Array(SQLaunchTutorialController.Step.allCases.enumerated()), id: \.offset) { _, step in
                    Capsule()
                        .fill(
                            step.rawValue <= controller.currentStep.rawValue
                            ? SQColor.dashboardGlowBlue.color
                            : SQColor.glassStroke.color
                        )
                        .frame(maxWidth: .infinity)
                        .frame(height: 6)
                }
            }
        }
    }

    private var heroCard: some View {
        VStack(spacing: .SQSpace.m) {
            heroOrb

            VStack(spacing: .SQSpace.xs) {
                Text(stepTitle)
                    .sqFont(.title2)
                    .sqForegroundColor(.textPrimary)
                    .multilineTextAlignment(.center)

                Text(stepSubtitle)
                    .sqFont(.bodySmall)
                    .sqForegroundColor(.textSecondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, .SQSpace.xl)
        .padding(.horizontal, .SQSpace.l)
        .sqGlassSurface(level: .card, cornerRadius: .SQCornerRadius.xl)
    }

    private var heroOrb: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            SQColor.dashboardGlowBlue.color.opacity(SQColor.isDarkMode ? 0.34 : 0.24),
                            SQColor.dashboardGlowMint.color.opacity(SQColor.isDarkMode ? 0.18 : 0.10),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 24,
                        endRadius: 124
                    )
                )
                .frame(width: 210, height: 210)
                .blur(radius: 10)

            Image("Que")
                .resizable()
                .scaledToFit()
                .frame(width: 146, height: 146)
                .shadow(color: SQColor.dashboardGlowBlue.color.opacity(0.18), radius: 18, x: 0, y: 14)
        }
        .frame(width: 210, height: 210)
        .overlay(alignment: .bottomTrailing) {
            Circle()
                .fill(stepAccentColor.opacity(SQColor.isDarkMode ? 0.24 : 0.16))
                .frame(width: 44, height: 44)
                .overlay {
                    Circle()
                        .stroke(SQColor.glassStrokeStrong.color, lineWidth: 1)
                }
                .overlay {
                    SQImageView(
                        image: .init(
                            symbol: stepSymbol,
                            symbolStyle: .colorWithFont(stepAccentSQColor, font: .body)
                        )
                    )
                    .frame(width: 18, height: 18)
                }
                .offset(x: 4, y: 4)
        }
        .padding(.bottom, .SQSpace.s)
    }

    @ViewBuilder
    private var detailCard: some View {
        switch controller.currentStep {
        case .overview:
            overviewCard
        case .healthKit:
            healthKitCard
        case .ready:
            readyCard
        }
    }

    private var overviewCard: some View {
        VStack(alignment: .leading, spacing: .SQSpace.m) {
            tutorialFeatureBlock(
                symbol: .checkmarkSquareFill,
                title: "Track daily check-ins",
                subtitle: "Track your daily habits, behavior, and stats in a quick check-in."
            ) {
                SQLaunchTutorialDailyCheckInPreview()
            }

            tutorialFeatureBlock(
                symbol: .chartBar,
                title: "See clearer health insights",
                subtitle: "LifeIQ combines your check-ins with Health data to surface patterns that are easier to act on."
            ) {
                SQLaunchTutorialInsightPreview()
            }

            tutorialFeatureRow(
                symbol: .heart,
                title: "View Health data faster",
                subtitle: "Easily view and analyze sleep, workouts, recovery, and performance from one dashboard."
            )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.SQSpace.l)
        .sqGlassSurface(level: .card, cornerRadius: .SQCornerRadius.xl)
    }

    private var healthKitCard: some View {
        VStack(alignment: .leading, spacing: .SQSpace.m) {
            Text("HealthKit makes the dashboard more complete from day one.")
                .sqFont(.bodySmallSemiBold)
                .sqForegroundColor(.textPrimary)

            tutorialFeatureRow(
                symbol: .moonZzzFill,
                title: "Sleep and recovery context",
                subtitle: "Provides better context around sleep quality, timing, and recovery patterns."
            )

            tutorialFeatureRow(
                symbol: .figureRun,
                title: "Workout and performance detail",
                subtitle: "See richer workout history, performance summaries, cardio data, and trends without piecing it together manually."
            )

            tutorialFeatureRow(
                symbol: .plusCircle,
                title: "Less manual entry",
                subtitle: "Some check-in metrics can be filled from Health data, and LifeIQ can write supported metrics back when you log them."
            )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.SQSpace.l)
        .sqGlassSurface(level: .card, cornerRadius: .SQCornerRadius.xl)
    }

    private var readyCard: some View {
        VStack(alignment: .leading, spacing: .SQSpace.m) {
            tutorialFeatureRow(
                symbol: .personCircleFill,
                title: "Create your account",
                subtitle: "Create your account to unlock check-ins and improve insights."
            )

            tutorialFeatureBlock(
                symbol: .edit,
                title: "Log your first check-in",
                subtitle: "Start with the Check In card on the dashboard."
            ) {
                SQLaunchTutorialCheckInCtaPreview()
            }

            if !controller.isHealthKitConnected {
                tutorialFeatureRow(
                    symbol: .heart,
                    title: "Connect HealthKit later if you want",
                    subtitle: "You can always enable Apple Health access later for richer dashboard context."
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.SQSpace.l)
        .sqGlassSurface(level: .card, cornerRadius: .SQCornerRadius.xl)
    }

    private var actionArea: some View {
        VStack(spacing: .SQSpace.m) {
            switch controller.currentStep {
            case .overview:
                SQButton(style: .glassPrimary, title: "Next") {
                    controller.continueFromOverview()
                }
            case .healthKit:
                SQButton(
                    style: .glassPrimary,
                    title: controller.healthKitButtonTitle,
                    isLoading: controller.isRequestingHealthKitAccess
                ) {
                    controller.enableHealthKitTapped()
                }

                if controller.shouldShowSkipHealthKitButton {
                    SQButton(style: .secondary, title: "Not Now") {
                        controller.skipHealthKitTapped()
                    }
                }
            case .ready:
                SQButton(style: .glassPrimary, title: "Continue to Dashboard") {
                    controller.finishTapped()
                }
            }
        }
    }

    private func tutorialFeatureRow(
        symbol: SQImageSymbol,
        title: String,
        subtitle: String
    ) -> some View {
        HStack(alignment: .top, spacing: .SQSpace.m) {
            Circle()
                .fill(stepAccentColor.opacity(SQColor.isDarkMode ? 0.22 : 0.12))
                .frame(width: 38, height: 38)
                .overlay {
                    SQImageView(
                        image: .init(
                            symbol: symbol,
                            symbolStyle: .colorWithFont(stepAccentSQColor, font: .bodySmall)
                        )
                    )
                    .frame(width: 16, height: 16)
                }

            VStack(alignment: .leading, spacing: .SQSpace.xs) {
                Text(title)
                    .sqFont(.bodySmallSemiBold)
                    .sqForegroundColor(.textPrimary)

                Text(subtitle)
                    .sqFont(.bodyExtraSmall)
                    .sqForegroundColor(.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
    }

    private func tutorialFeatureBlock<Preview: View>(
        symbol: SQImageSymbol,
        title: String,
        subtitle: String,
        @ViewBuilder preview: () -> Preview
    ) -> some View {
        VStack(alignment: .leading, spacing: .SQSpace.m) {
            tutorialFeatureRow(symbol: symbol, title: title, subtitle: subtitle)

            preview()
                .padding(.leading, 50)
        }
    }

    private var stepTitle: String {
        switch controller.currentStep {
        case .overview:
            return "How LifeIQ Works"
        case .healthKit:
            return "Connect HealthKit"
        case .ready:
            return "You're Ready to Go"
        }
    }

    private var stepSubtitle: String {
        switch controller.currentStep {
        case .overview:
            return "Track daily check-ins, combine them with Health data, and use the dashboard to understand what is helping or hurting your health."
        case .healthKit:
            return "Enable Apple Health access for the best experience. It makes your dashboard, sleep, workouts, and recovery views more useful. More shared data improves insights and utility."
        case .ready:
            return "You're all set to start exploring the dashboard, create your account, and log your first check-in."
        }
    }

    private var stepSymbol: SQImageSymbol {
        switch controller.currentStep {
        case .overview:
            return .infoCircle
        case .healthKit:
            return .heart
        case .ready:
            return .checkmark
        }
    }

    private var stepAccentSQColor: SQColor {
        switch controller.currentStep {
        case .overview:
            return .dashboardGlowBlue
        case .healthKit:
            return .dashboardGlowMint
        case .ready:
            return .dashboardGlowMint
        }
    }

    private var stepAccentColor: Color {
        stepAccentSQColor.color
    }
}

private struct SQLaunchTutorialDailyCheckInPreview: View {
    private let moodRow: SQDailyCheckInRowSegmentedControlViewModel
    private let waterRow: SQDailyCheckInTextEntryViewModel

    init() {
        let moodSegments = [
            SQSegmentedControlSegment(id: "1", title: "1"),
            SQSegmentedControlSegment(id: "2", title: "2"),
            SQSegmentedControlSegment(id: "3", title: "3"),
            SQSegmentedControlSegment(id: "4", title: "4"),
            SQSegmentedControlSegment(id: "5", title: "5")
        ]

        let selectedMood = moodSegments[3]
        let moodRow = SQDailyCheckInRowSegmentedControlViewModel(
            field: .metric(id: "tutorial.mood"),
            title: "Mood",
            subtitle: "Quick daily check-in example",
            segments: moodSegments,
            initialSelection: selectedMood
        )
        moodRow.number = "1"

        let waterField = SQTextFieldViewModel(
            font: .init(type: .body),
            placeholder: "0",
            keyboardType: .decimalPad,
            textAutoCap: .never,
            autoCorrectionEnabled: false,
            textChangeFormatter: .decimal(maxDecimalPlaces: 1),
            validationRule: nil
        )
        let waterRow = SQDailyCheckInTextEntryViewModel(
            field: .metric(id: "tutorial.water"),
            title: "Water (oz)",
            subtitle: "Track what matters most to you",
            textFieldViewModel: waterField
        )
        waterRow.number = "2"
        waterRow.initialize(with: "72")

        self.moodRow = moodRow
        self.waterRow = waterRow
    }

    var body: some View {
        VStack(alignment: .leading, spacing: .SQSpace.m) {
            exampleBadge(text: "Check-In Example")

            SQDailyCheckInRow(viewModel: moodRow)
                .allowsHitTesting(false)

            SQDailyCheckInRow(viewModel: waterRow)
                .allowsHitTesting(false)
        }
    }
}

private struct SQLaunchTutorialInsightPreview: View {
    private let viewModel: SQDashboardInsightRowViewModel

    init() {
        let insight = SQInsight(
            id: "tutorial.insight.sleep-energy",
            title: "Sleep and Energy",
            summary: "On days after 8+ hours of sleep, your energy check-ins trend higher.",
            evidenceText: "This is a sample insight preview shown during onboarding.",
            actionText: "Use your check-ins and Health data together to understand what is helping.",
            driverText: "More Sleep",
            outcomeText: "Higher Energy",
            deltaText: "+18%",
            category: .recovery,
            confidence: .medium,
            effect: .positive,
            sampleCount: 12,
            rankingScore: 0.8
        )

        self.viewModel = SQDashboardInsightRowViewModel(model: insight)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: .SQSpace.m) {
            exampleBadge(text: "Insight Example")

            SQDashboardInsightRowView(viewModel: viewModel)
                .allowsHitTesting(false)
        }
    }
}

private struct SQLaunchTutorialCheckInCtaPreview: View {
    private let viewModel = SQCallToActionViewModel.guestDailyCheckInPrompt(signupEnabled: true)

    var body: some View {
        VStack(alignment: .leading, spacing: .SQSpace.m) {
            exampleBadge(text: "Dashboard CTA")

            SQCallToAction(viewModel: viewModel)
                .allowsHitTesting(false)
        }
    }
}

private func exampleBadge(text: String) -> some View {
    Text(text)
        .sqFont(.bodyExtraSmall)
        .sqForegroundColor(.dashboardGlowBlue)
        .padding(.horizontal, .SQSpace.s)
        .padding(.vertical, 4)
        .background {
            Capsule(style: .continuous)
                .fill(SQColor.dashboardGlowBlue.color.opacity(SQColor.isDarkMode ? 0.14 : 0.10))
                .overlay {
                    Capsule(style: .continuous)
                        .stroke(SQColor.glassStrokeStrong.color, lineWidth: 1)
                }
        }
}

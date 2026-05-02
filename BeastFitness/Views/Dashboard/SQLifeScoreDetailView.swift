//
//  SQLifeScoreDetailView.swift
//  BeastFitness
//

import SwiftUI

struct SQLifeScoreDetailView: View {
    @State var controller: SQLifeScoreDetailController
    @State private var isBreakdownExpanded = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: .SQSpace.xl) {
                heroCard
                if !controller.viewModel.drivers.isEmpty {
                    driversCard
                }
                if !controller.viewModel.changes.isEmpty {
                    changesCard
                }
                if !controller.viewModel.actions.isEmpty {
                    actionsCard
                }
                breakdownDisclosure
            }
            .padding(.horizontal, .SQSpace.xl)
            .padding(.top, .SQSpace.xl)
            .padding(.bottom, 20)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .navigationTitle("Life Score")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    presentLifeScoreInfoAlert()
                } label: {
                    ZStack {
                        Color.clear

                        SQImageView(
                            image: .init(
                                symbol: .infoCircle,
                                symbolStyle: .colorWithFont(.textPrimary, font: .bodySmall)
                            )
                        )
                        .frame(width: 18, height: 18)
                    }
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .background {
            SQSheetBackground()
        }
    }

    private func presentLifeScoreInfoAlert() {
        let alert = SQAlertViewModel(
            title: "Life Score",
            subtitle: "Life Score is a daily snapshot of your recent momentum. It looks at signals like sleep, recovery, workouts, habits, and check-ins to estimate whether your life is trending in a healthy direction. It is not a medical score - it is a guide to help you notice what's supporting you and what may need attention.",
            primary: .init(title: "Got it"),
            canDismiss: true
        )

        SQAppState.shared.hub.alertEvents.send(.present(alert))
    }

    private var heroCard: some View {
        VStack(alignment: .leading, spacing: .SQSpace.l) {
            HStack(alignment: .firstTextBaseline, spacing: .SQSpace.s) {
                Text(controller.viewModel.scoreText)
                    .sqFont(.title1)
                    .sqForegroundColor(.textPrimary)

                Text("— \(controller.viewModel.state.title)")
                    .sqFont(.title4)
                    .sqForegroundColor(.textSecondary)
            }

            Text(controller.viewModel.headlineText ?? controller.viewModel.primaryInsight?.title ?? controller.viewModel.state.summary)
                .sqFont(.bodyExtraSmall)
                .sqForegroundColor(.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            if let refinementPromptText = controller.viewModel.refinementPromptText {
                Text(refinementPromptText)
                    .sqFont(.bodyExtraSmall)
                    .sqForegroundColor(.dashboardGlowBlue)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.SQSpace.xl)
        .sqGlassSurface(level: .card, cornerRadius: .SQCornerRadius.xl)
    }

    private var driversCard: some View {
        VStack(alignment: .leading, spacing: .SQSpace.l) {
            VStack(alignment: .leading, spacing: 2) {
                Text("What's Driving It")
                    .sqFont(.title4)
                    .sqForegroundColor(.textPrimary)

                Text(driversSubtitleText)
                    .sqFont(.bodyExtraSmall)
                    .sqForegroundColor(.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(alignment: .leading, spacing: .SQSpace.m) {
                ForEach(controller.viewModel.drivers) { driver in
                    driverRow(driver)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.SQSpace.xl)
        .sqGlassSurface(level: .card, cornerRadius: .SQCornerRadius.xl)
    }

    private var driversSubtitleText: String {
        if let timeframeText = controller.viewModel.driverTimeframeText {
            return timeframeText
        }

        return "Today"
    }

    private var changesCard: some View {
        VStack(alignment: .leading, spacing: .SQSpace.l) {
            VStack(alignment: .leading, spacing: 2) {
                Text("What Changed")
                    .sqFont(.title4)
                    .sqForegroundColor(.textPrimary)

                if let timeframeText = controller.viewModel.changes.first?.timeframeText {
                    Text(timeframeText)
                        .sqFont(.bodyExtraSmall)
                        .sqForegroundColor(.textSecondary)
                }
            }

            VStack(alignment: .leading, spacing: .SQSpace.m) {
                ForEach(controller.viewModel.changes) { change in
                    changeRow(change)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.SQSpace.xl)
        .sqGlassSurface(level: .card, cornerRadius: .SQCornerRadius.xl)
    }

    private var actionsCard: some View {
        VStack(alignment: .leading, spacing: .SQSpace.l) {
            Text("What To Do")
                .sqFont(.title4)
                .sqForegroundColor(.textPrimary)

            VStack(alignment: .leading, spacing: .SQSpace.m) {
                ForEach(controller.viewModel.actions) { action in
                    actionRow(action)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.SQSpace.xl)
        .sqGlassSurface(level: .card, cornerRadius: .SQCornerRadius.xl)
    }

    private func driverRow(_ driver: SQInsightDriver) -> some View {
        let color: SQColor = driver.direction == .supportive ? .dashboardGlowMint : .colorErrorRed

        return HStack(alignment: .center, spacing: .SQSpace.s) {
            Circle()
                .fill(color.color)
                .frame(width: 8, height: 8)

            HStack(alignment: .firstTextBaseline, spacing: .SQSpace.xs) {
                Text(driver.title)
                    .sqFont(.bodyExtraSmall)
                    .sqForegroundColor(.textPrimary)

                Spacer(minLength: 0)

                Text(driverPercentText(driver))
                    .sqFont(.bodyExtraSmall)
                    .sqForegroundColor(.textSecondary)
            }
        }
    }

    private func changeRow(_ change: SQInsightChange) -> some View {
        let color: SQColor = change.direction == .improved ? .dashboardGlowMint : .colorErrorRed

        return HStack(alignment: .center, spacing: .SQSpace.s) {
            Circle()
                .fill(color.color)
                .frame(width: 8, height: 8)

            HStack(alignment: .firstTextBaseline, spacing: .SQSpace.xs) {
                Text(change.title)
                    .sqFont(.bodyExtraSmall)
                    .sqForegroundColor(.textPrimary)

                Spacer(minLength: 0)

                Text(changePercentText(change))
                    .sqFont(.bodyExtraSmall)
                    .sqForegroundColor(.textSecondary)
            }
        }
    }

    private func actionRow(_ action: SQInsightAction) -> some View {
        Text(action.summary)
            .sqFont(.bodyExtraSmall)
            .sqForegroundColor(.textSecondary)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var breakdownDisclosure: some View {
        DisclosureGroup(
            isExpanded: $isBreakdownExpanded,
            content: {
                VStack(alignment: .leading, spacing: .SQSpace.m) {
                    VStack(alignment: .leading, spacing: .SQSpace.m) {
                        ForEach(Array(componentRows.enumerated()), id: \.offset) { _, row in
                            if row.count == 1, let component = row.first {
                                componentCard(component)
                            } else {
                                HStack(alignment: .top, spacing: .SQSpace.s) {
                                    ForEach(row) { component in
                                        componentCard(component)
                                            .frame(maxWidth: .infinity, alignment: .topLeading)
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(.top, .SQSpace.s)
            },
            label: {
                Text("How This Score Is Calculated")
                    .sqFont(.title4)
                    .sqForegroundColor(.textPrimary)
            }
        )
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.SQSpace.xl)
        .sqGlassSurface(level: .card, cornerRadius: .SQCornerRadius.xl)
    }

    private var componentRows: [[SQLifeScoreComponent]] {
        let components = controller.viewModel.components
        var rows = [[SQLifeScoreComponent]]()
        var compactRow = [SQLifeScoreComponent]()

        for component in components {
            if shouldUseFullWidthComponentCard(component) {
                if !compactRow.isEmpty {
                    rows.append(compactRow)
                    compactRow.removeAll()
                }
                rows.append([component])
            } else {
                compactRow.append(component)
                if compactRow.count == 2 {
                    rows.append(compactRow)
                    compactRow.removeAll()
                }
            }
        }

        if !compactRow.isEmpty {
            rows.append(compactRow)
        }

        return rows
    }

    private func shouldUseFullWidthComponentCard(_ component: SQLifeScoreComponent) -> Bool {
        component.detailItems.count >= 3
            || component.id == "sleep"
            || component.id == "workouts"
            || component.id == "trainingPerformance"
            || component.id == "habitsBehaviors"
            || component.id == "personalizedMetrics"
    }

    private func componentCard(_ component: SQLifeScoreComponent) -> some View {
        let tone = tone(for: component.score)

        return VStack(alignment: .leading, spacing: .SQSpace.s) {
            HStack(alignment: .top, spacing: .SQSpace.s) {
                VStack(alignment: .leading, spacing: .SQSpace.s) {
                    HStack(alignment: .center, spacing: .SQSpace.s) {
                        Circle()
                            .fill(tone.color.color)
                            .frame(width: 10, height: 10)

                        Text(component.title)
                            .sqFont(.bodySmallSemiBold)
                            .sqForegroundColor(.textPrimary)
                    }

                    HStack(alignment: .firstTextBaseline, spacing: .SQSpace.xs) {
                        Text("\(component.score)")
                            .sqFont(.title3)
                            .sqForegroundColor(.textPrimary)

                        Text("/100")
                            .sqFont(.bodyExtraSmall)
                            .sqForegroundColor(.textSecondary)
                    }

                    if let scoreDeltaText = component.scoreDeltaText {
                        Text(scoreDeltaText)
                            .sqFont(.bodyExtraSmall)
                            .sqForegroundColor(scoreDeltaColor(for: component.scoreDeltaEffect))
                    }
                }

                Spacer(minLength: 0)

                VStack(alignment: .trailing, spacing: .SQSpace.s) {
                    Text(tone.label)
                        .sqFont(.headerSmall)
                        .sqForegroundColor(.textSecondary)

                    Text(componentWeightText(component))
                        .sqFont(.title4)
                        .sqForegroundColor(.textTertiary)
                }
            }

            Text(component.summary)
                .sqFont(.bodyExtraSmall)
                .sqForegroundColor(.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            if !component.detailItems.isEmpty {
                componentDetailList(component.detailItems)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.SQSpace.l)
        .background {
            RoundedRectangle(cornerRadius: .SQCornerRadius.xl, style: .continuous)
                .fill(SQColor.glassCardTint.color.opacity(SQColor.isDarkMode ? 0.78 : 0.98))
                .overlay {
                    RoundedRectangle(cornerRadius: .SQCornerRadius.xl, style: .continuous)
                        .stroke(tone.color.color.opacity(SQColor.isDarkMode ? 0.40 : 0.22), lineWidth: 1)
                }
        }
    }

    private func componentDetailList(_ items: [SQLifeScoreDetailItem]) -> some View {
        VStack(alignment: .leading, spacing: .SQSpace.xs) {
            VStack(alignment: .leading, spacing: .SQSpace.s) {
                ForEach(items) { item in
                    signalRow(item)
                }
            }
        }
        .padding(.top, .SQSpace.xs)
    }

    private func signalRow(_ item: SQLifeScoreDetailItem) -> some View {
        HStack(alignment: .top, spacing: .SQSpace.s) {
            Circle()
                .fill(item.effect.color.color)
                .frame(width: 8, height: 8)
                .padding(.top, 4)

            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .sqFont(.bodyExtraSmall)
                    .sqForegroundColor(.textPrimary)

                Text(item.valueText)
                    .sqFont(.bodyExtraSmall)
                    .sqForegroundColor(.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)

                if !item.summary.isEmpty {
                    Text(item.summary)
                        .sqFont(.bodyExtraSmall)
                        .sqForegroundColor(.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private func tone(for score: Int) -> (label: String, color: SQColor) {
        switch score {
        case 80...:
            return ("Strong", .dashboardGlowMint)
        case 65...79:
            return ("Good", .dashboardGlowBlue)
        case 45...64:
            return ("Mixed", .dashboardTrendWarm)
        default:
            return ("Low", .colorErrorRed)
        }
    }

    private func scoreDeltaColor(for effect: SQLifeScoreSignalEffect) -> SQColor {
        switch effect {
        case .positive, .neutral:
            return effect.color
        case .negative:
            return .colorFadedRed
        }
    }

    private func driverPercentText(_ driver: SQInsightDriver) -> String {
        signedPercentText(
            magnitude: driver.effectMagnitude,
            isPositive: driver.direction == .supportive
        )
    }

    private func changePercentText(_ change: SQInsightChange) -> String {
        let delta = change.recentAverage - change.priorAverage
        if abs(change.priorAverage) >= 0.1 {
            let percent = (delta / abs(change.priorAverage)) * 100
            return signedPercentText(value: percent)
        }

        return signedPercentText(
            magnitude: change.effectMagnitude,
            isPositive: change.direction == .improved
        )
    }

    private func signedPercentText(magnitude: Double, isPositive: Bool) -> String {
        signedPercentText(value: (isPositive ? 1 : -1) * abs(magnitude))
    }

    private func signedPercentText(value: Double) -> String {
        let rounded = Int(value.rounded())
        if rounded > 0 {
            return "+\(rounded)%"
        }
        return "\(rounded)%"
    }

    private func componentWeightText(_ component: SQLifeScoreComponent) -> String {
        guard component.weight > 0 else { return "Optional" }
        return "\(Int(component.weight.rounded()))%"
    }
}

struct SQRecoveryScoreDetailView: View {
    @State var controller: SQRecoveryScoreDetailController

    private var displayStatusTitle: String {
        switch controller.viewModel.statusTitle {
        case "Solid":
            return "Strong"
        default:
            return controller.viewModel.statusTitle
        }
    }

    private var scoreText: String {
        controller.viewModel.score.map(String.init) ?? "?"
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: .SQSpace.xl) {
                heroCard

                if let warning = controller.viewModel.dataQualityWarning {
                    warningCard(warning)
                }

                explanationCard
            }
            .padding(.horizontal, .SQSpace.xl)
            .padding(.top, .SQSpace.xl)
            .padding(.bottom, 20)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .navigationTitle("Recovery Score")
        .navigationBarTitleDisplayMode(.inline)
        .background {
            SQSheetBackground()
        }
    }

    private var heroCard: some View {
        VStack(alignment: .leading, spacing: .SQSpace.l) {
            HStack(alignment: .firstTextBaseline, spacing: .SQSpace.s) {
                Text(scoreText)
                    .sqFont(.title1)
                    .sqForegroundColor(.textPrimary)

                Text("— \(displayStatusTitle)")
                    .sqFont(.title4)
                    .sqForegroundColor(.textSecondary)
            }

            Text(controller.viewModel.headline)
                .sqFont(.bodyExtraSmall)
                .sqForegroundColor(.textPrimary)
                .fixedSize(horizontal: false, vertical: true)

            Text(controller.viewModel.summary)
                .sqFont(.bodyExtraSmall)
                .sqForegroundColor(.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.SQSpace.xl)
        .sqGlassSurface(level: .card, cornerRadius: .SQCornerRadius.xl)
    }

    private func warningCard(_ warning: String) -> some View {
        VStack(alignment: .leading, spacing: .SQSpace.s) {
            Text("Data Quality")
                .sqFont(.title4)
                .sqForegroundColor(.textPrimary)

            Text(warning)
                .sqFont(.bodyExtraSmall)
                .sqForegroundColor(.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.SQSpace.xl)
        .sqGlassSurface(level: .card, cornerRadius: .SQCornerRadius.xl)
    }

    private func recoveryDriverCard(_ driver: SQDashboardBodyBatteryRowViewModel.Driver) -> some View {
        let accentColor: SQColor = {
            switch driver.tone {
            case .positive:
                return .dashboardGlowMint
            case .negative:
                return .dashboardTrendWarm
            case .neutral:
                return .textTertiary
            }
        }()

        return VStack(alignment: .leading, spacing: .SQSpace.s) {
            HStack(alignment: .top, spacing: .SQSpace.s) {
                VStack(alignment: .leading, spacing: .SQSpace.xs) {
                    Text(driver.title)
                        .sqFont(.bodySmallSemiBold)
                        .sqForegroundColor(.textPrimary)

                    if driver.definitionLines.isEmpty {
                        Text(driver.detailText)
                            .sqFont(.bodyExtraSmall)
                            .sqForegroundColor(.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    } else {
                        SQScoreDefinitionLinesView(lines: driver.definitionLines)
                    }
                }

                Spacer(minLength: 0)

                HStack(alignment: .firstTextBaseline, spacing: .SQSpace.xs) {
                    Text(driver.valueText)
                        .sqFont(.title4)
                        .sqForegroundColor(.textPrimary)

                    if let symbol = driver.symbol {
                        SQImageView(
                            image: .init(
                                symbol: symbol,
                                symbolStyle: .colorWithFont(accentColor, font: .bodyExtraSmall)
                            )
                        )
                        .frame(width: 10, height: 10)
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
                        .stroke(accentColor.color.opacity(SQColor.isDarkMode ? 0.24 : 0.16), lineWidth: 1)
                }
        }
    }

    private var explanationCard: some View {
        VStack(alignment: .leading, spacing: .SQSpace.l) {
            Text("How This Score Is Calculated")
                .sqFont(.title4)
                .sqForegroundColor(.textPrimary)

            Text(calculationIntroText)
                .sqFont(.bodyExtraSmall)
                .sqForegroundColor(.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: .SQSpace.m) {
                ForEach(controller.viewModel.drivers) { driver in
                    recoveryDriverCard(driver)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.SQSpace.xl)
        .sqGlassSurface(level: .card, cornerRadius: .SQCornerRadius.xl)
    }

    private var calculationIntroText: String {
        if controller.viewModel.score == nil {
            return "Recovery Score needs at least one usable signal. When data is available, sleep, strain, check-ins, and heart data can each lift or lower the score."
        }

        return "Recovery Score starts from a neutral baseline, then adjusts for sleep, strain, check-ins, and heart data."
    }
}

private struct SQScoreDefinitionLinesView: View {
    let lines: [SQDashboardBodyBatteryRowViewModel.DefinitionLine]

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

                    if let weightText = line.weightText {
                        Text(weightText)
                            .sqFont(.bodyExtraSmall)
                            .sqForegroundColor(.textTertiary)
                    }
                }
            }
        }
    }
}

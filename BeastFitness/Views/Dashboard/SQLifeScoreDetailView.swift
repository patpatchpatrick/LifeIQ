//
//  SQLifeScoreDetailView.swift
//  BeastFitness
//

import SwiftUI

struct SQLifeScoreDetailView: View {
    @State var controller: SQLifeScoreDetailController
    @State private var isBreakdownExpanded = false

    private var componentColumns: [GridItem] {
        [.init(.adaptive(minimum: 160), spacing: .SQSpace.s, alignment: .topLeading)]
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: .SQSpace.l) {
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
            .padding(.horizontal, .SQSpace.l)
            .padding(.top, .SQSpace.l)
            .padding(.bottom, .SQSpace.xl)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .navigationTitle("Life Score")
        .navigationBarTitleDisplayMode(.inline)
        .background {
            SQSheetBackground()
        }
    }

    private var heroCard: some View {
        VStack(alignment: .leading, spacing: .SQSpace.m) {
            HStack(alignment: .firstTextBaseline, spacing: .SQSpace.s) {
                Text(controller.viewModel.scoreText)
                    .sqFont(.title1)
                    .sqForegroundColor(.textPrimary)

                Text("— \(controller.viewModel.state.title)")
                    .sqFont(.title4)
                    .sqForegroundColor(.textSecondary)
            }

            Text(controller.viewModel.primaryInsight?.title ?? controller.viewModel.state.summary)
                .sqFont(.bodyExtraSmall)
                .sqForegroundColor(.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.SQSpace.l)
        .sqGlassSurface(level: .card, cornerRadius: .SQCornerRadius.xl)
    }

    private var driversCard: some View {
        VStack(alignment: .leading, spacing: .SQSpace.m) {
            Text("What's Driving It")
                .sqFont(.title4)
                .sqForegroundColor(.textPrimary)

            if !controller.viewModel.supportiveDrivers.isEmpty {
                driverGroup(
                    title: "Helping Right Now",
                    drivers: controller.viewModel.supportiveDrivers
                )
            }

            if !controller.viewModel.dragDrivers.isEmpty {
                driverGroup(
                    title: "Dragging Right Now",
                    drivers: controller.viewModel.dragDrivers
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.SQSpace.l)
        .sqGlassSurface(level: .card, cornerRadius: .SQCornerRadius.xl)
    }

    private var changesCard: some View {
        VStack(alignment: .leading, spacing: .SQSpace.m) {
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

            VStack(alignment: .leading, spacing: .SQSpace.s) {
                ForEach(controller.viewModel.changes) { change in
                    changeRow(change)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.SQSpace.l)
        .sqGlassSurface(level: .card, cornerRadius: .SQCornerRadius.xl)
    }

    private var actionsCard: some View {
        VStack(alignment: .leading, spacing: .SQSpace.m) {
            Text("What To Do")
                .sqFont(.title4)
                .sqForegroundColor(.textPrimary)

            VStack(alignment: .leading, spacing: .SQSpace.s) {
                ForEach(controller.viewModel.actions) { action in
                    actionRow(action)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.SQSpace.l)
        .sqGlassSurface(level: .card, cornerRadius: .SQCornerRadius.xl)
    }

    private func driverGroup(title: String, drivers: [SQInsightDriver]) -> some View {
        VStack(alignment: .leading, spacing: .SQSpace.xs) {
            Text(title.uppercased())
                .sqFont(.headerSmall)
                .sqForegroundColor(.textSecondary)

            VStack(alignment: .leading, spacing: .SQSpace.s) {
                ForEach(drivers) { driver in
                    driverRow(driver)
                }
            }
        }
    }

    private func driverRow(_ driver: SQInsightDriver) -> some View {
        let color: SQColor = driver.direction == .supportive ? .dashboardGlowMint : .colorErrorRed

        return HStack(alignment: .top, spacing: .SQSpace.s) {
            Circle()
                .fill(color.color)
                .frame(width: 8, height: 8)
                .padding(.top, 4)

            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .firstTextBaseline, spacing: .SQSpace.xs) {
                    Text(driver.title)
                        .sqFont(.bodyExtraSmall)
                        .sqForegroundColor(.textPrimary)

                    Spacer(minLength: 0)

                    Text(driver.deltaText)
                        .sqFont(.bodyExtraSmall)
                        .sqForegroundColor(.textSecondary)
                }
            }
        }
    }

    private func changeRow(_ change: SQInsightChange) -> some View {
        let color: SQColor = change.direction == .improved ? .dashboardGlowMint : .colorErrorRed

        return HStack(alignment: .top, spacing: .SQSpace.s) {
            Circle()
                .fill(color.color)
                .frame(width: 8, height: 8)
                .padding(.top, 4)

            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .firstTextBaseline, spacing: .SQSpace.xs) {
                    Text(change.title)
                        .sqFont(.bodyExtraSmall)
                        .sqForegroundColor(.textPrimary)

                    Spacer(minLength: 0)

                    Text(change.deltaText)
                        .sqFont(.bodyExtraSmall)
                        .sqForegroundColor(.textSecondary)
                }
            }
        }
    }

    private func actionRow(_ action: SQInsightAction) -> some View {
        let color: SQColor
        switch action.tone {
        case .maintain:
            color = .dashboardGlowMint
        case .improve:
            color = .dashboardGlowBlue
        case .caution:
            color = .dashboardTrendWarm
        }

        return HStack(alignment: .top, spacing: .SQSpace.s) {
            Circle()
                .fill(color.color)
                .frame(width: 8, height: 8)
                .padding(.top, 4)

            VStack(alignment: .leading, spacing: 2) {
                Text(action.title)
                    .sqFont(.bodyExtraSmall)
                    .sqForegroundColor(.textPrimary)

                Text(action.summary)
                    .sqFont(.bodyExtraSmall)
                    .sqForegroundColor(.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var breakdownDisclosure: some View {
        DisclosureGroup(
            isExpanded: $isBreakdownExpanded,
            content: {
                VStack(alignment: .leading, spacing: .SQSpace.m) {
                    LazyVGrid(columns: componentColumns, alignment: .leading, spacing: .SQSpace.s) {
                        ForEach(controller.viewModel.components) { component in
                            componentCard(component)
                        }
                    }

                    formulaCard
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
        .padding(.SQSpace.l)
        .sqGlassSurface(level: .card, cornerRadius: .SQCornerRadius.xl)
    }

    private func componentCard(_ component: SQLifeScoreComponent) -> some View {
        let tone = tone(for: component.score)
        let positiveItems = component.detailItems.filter { $0.effect == .positive }
        let negativeItems = component.detailItems.filter { $0.effect == .negative }
        let neutralItems = component.detailItems.filter { $0.effect == .neutral }

        return VStack(alignment: .leading, spacing: .SQSpace.s) {
            HStack(alignment: .center, spacing: .SQSpace.s) {
                Circle()
                    .fill(tone.color.color)
                    .frame(width: 10, height: 10)

                Text(component.title)
                    .sqFont(.bodySmallSemiBold)
                    .sqForegroundColor(.textPrimary)

                Spacer(minLength: 0)

                Text(tone.label)
                    .sqFont(.headerSmall)
                    .sqForegroundColor(.textSecondary)
            }

            HStack(alignment: .firstTextBaseline, spacing: .SQSpace.s) {
                Text("\(component.score)")
                    .sqFont(.title3)
                    .sqForegroundColor(.textPrimary)

                Text("/100")
                    .sqFont(.bodyExtraSmall)
                    .sqForegroundColor(.textSecondary)
            }

            Text(component.summary)
                .sqFont(.bodyExtraSmall)
                .sqForegroundColor(.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            if !positiveItems.isEmpty {
                signalGroup(title: "Lifted Score", items: positiveItems)
            }

            if !negativeItems.isEmpty {
                signalGroup(title: "Lowered Score", items: negativeItems)
            }

            if !neutralItems.isEmpty {
                signalGroup(title: "Mixed Signals", items: neutralItems)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.SQSpace.m)
        .background {
            RoundedRectangle(cornerRadius: .SQCornerRadius.xl, style: .continuous)
                .fill(SQColor.glassCardTint.color.opacity(SQColor.isDarkMode ? 0.78 : 0.98))
                .overlay {
                    RoundedRectangle(cornerRadius: .SQCornerRadius.xl, style: .continuous)
                        .stroke(tone.color.color.opacity(SQColor.isDarkMode ? 0.40 : 0.22), lineWidth: 1)
                }
        }
    }

    private func signalGroup(title: String, items: [SQLifeScoreDetailItem]) -> some View {
        VStack(alignment: .leading, spacing: .SQSpace.xs) {
            Text(title.uppercased())
                .sqFont(.headerSmall)
                .sqForegroundColor(.textSecondary)
                .padding(.top, .SQSpace.xs)

            VStack(alignment: .leading, spacing: .SQSpace.s) {
                ForEach(items) { item in
                    signalRow(item)
                }
            }
        }
    }

    private func signalRow(_ item: SQLifeScoreDetailItem) -> some View {
        HStack(alignment: .top, spacing: .SQSpace.s) {
            Circle()
                .fill(item.effect.color.color)
                .frame(width: 8, height: 8)
                .padding(.top, 4)

            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .firstTextBaseline, spacing: .SQSpace.xs) {
                    Text(item.title)
                        .sqFont(.bodyExtraSmall)
                        .sqForegroundColor(.textPrimary)

                    Spacer(minLength: 0)

                    Text(item.valueText)
                        .sqFont(.bodyExtraSmall)
                        .sqForegroundColor(.textSecondary)
                }

                Text(item.summary)
                    .sqFont(.bodyExtraSmall)
                    .sqForegroundColor(.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var formulaCard: some View {
        VStack(alignment: .leading, spacing: .SQSpace.s) {
            Text("Each subscore contributes based on its weight. The final score is the weighted average of all available subscores, then rounded to the nearest whole number.")
                .sqFont(.bodyExtraSmall)
                .sqForegroundColor(.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            Text(formulaText)
                .sqFont(.bodyExtraSmall)
                .sqForegroundColor(.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var formulaText: String {
        let components = controller.viewModel.components
        guard !components.isEmpty else { return "No subscores are currently available." }

        let numerator = components.map { "\(componentContributionNumerator($0))" }.joined(separator: " + ")
        return "(\(numerator)) / \(Int(controller.viewModel.availableWeight.rounded()))"
    }

    private func componentContributionNumerator(_ component: SQLifeScoreComponent) -> String {
        "\(component.score)×\(Int(component.weight.rounded()))"
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
}

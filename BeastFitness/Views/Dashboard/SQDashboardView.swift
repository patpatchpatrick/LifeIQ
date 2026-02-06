//
//  SQDashboardView.swift
//  BeastFitness
//
//  Created by Patrick Doyle on 11/11/25.
//

import SwiftUI

struct SQDashboardView: View {
    @Bindable var controller: SQDashboardController
    @Environment(\.modelContext) private var modelContext
    static let uiConfig = UIConfig()

    // MARK: - Computed Properties for Metrics

    private var filteredMetrics: [SQStatRowData] {
        // Find check-in row viewmodels in section view models
        let checkInRows = controller.state.sectionViewModels
            .flatMap { $0.rows }
            .compactMap { $0 as? SQDashboardDailyCheckInRowViewModel }

        guard let checkInRow = checkInRows.first else { return [] }

        // Extract all metrics from groups
        var allMetrics: [SQStatRowData] = []

        for group in checkInRow.groups {
            // Filter by group if not "All"
            guard controller.state.metricsGroupFilter == "All" || group.name == controller.state.metricsGroupFilter else {
                continue
            }

            // Convert vital rows to stat row data
            for vitalRow in group.rows {
                let metricData = SQStatRowData(
                    id: vitalRow.id,
                    icon: vitalRow.emoji,
                    title: vitalRow.title,
                    avgValue: vitalRow.value,
                    unit: vitalRow.subtitle ?? "",
                    sparklineData: vitalRow.sparklineData,
                    change14d: 0.0  // Placeholder - would need historical comparison
                )
                allMetrics.append(metricData)
            }
        }

        return allMetrics
    }

    private var availableMetricGroups: [String] {
        // Find check-in row viewmodels
        let checkInRows = controller.state.sectionViewModels
            .flatMap { $0.rows }
            .compactMap { $0 as? SQDashboardDailyCheckInRowViewModel }

        guard let checkInRow = checkInRows.first else { return ["All"] }

        // Extract unique group names
        let groupNames = checkInRow.groups.map { $0.name }
        return ["All"] + groupNames.sorted()
    }

    // MARK: - Computed Subsections

    private var metricsSubsection: some View {
        SQDashboardSubsection(
            title: "Metrics",
            isCollapsed: $controller.state.isMetricsCollapsed,
            dropdownMenu: SQDropDownMenu(
                menuViewModel: createMetricsFilterMenu(),
                isDisabled: false
            )
        ) {
            if filteredMetrics.isEmpty {
                SQSubsectionEmptyState(
                    title: "No metrics yet",
                    message: "Complete your daily check-in to track metrics"
                )
            } else {
                SQStatRowSection(rows: filteredMetrics)
            }
        }
    }

    private var performanceSubsection: some View {
        SQDashboardSubsection(
            title: "Performance",
            isCollapsed: $controller.state.isPerformanceCollapsed
        ) {
            Text("Performance content - TODO")
                .padding()
        }
    }

    private var totalsSubsection: some View {
        SQDashboardSubsection(
            title: "Totals",
            isCollapsed: $controller.state.isTotalsCollapsed,
            dropdownMenu: SQDropDownMenu(
                menuViewModel: createTotalsFilterMenu(),
                isDisabled: false
            )
        ) {
            Text("Totals content - TODO")
                .padding()
        }
    }

    private var activitiesSubsection: some View {
        SQDashboardSubsection(
            title: "Activities",
            isCollapsed: $controller.state.isActivitiesCollapsed,
            dropdownMenu: SQDropDownMenu(
                menuViewModel: createActivitiesFilterMenu(),
                isDisabled: false
            )
        ) {
            Text("Activities content - TODO")
                .padding()
        }
    }

    // MARK: - Filter Menu Creators

    private func createMetricsFilterMenu() -> SQDropDownMenuViewModel {
        let items = availableMetricGroups.map {
            SQDropDownMenuViewModel.Item(title: $0)
        }
        return SQDropDownMenuViewModel(
            defaultItem: .init(title: controller.state.metricsGroupFilter),
            items: items
        ) { [controller] selectedTitle in
            controller.state.metricsGroupFilter = selectedTitle
        }
    }

    private func createTotalsFilterMenu() -> SQDropDownMenuViewModel {
        let items = TotalsType.allCases.map {
            SQDropDownMenuViewModel.Item(title: $0.rawValue)
        }
        return SQDropDownMenuViewModel(
            defaultItem: .init(title: controller.state.totalsTypeFilter.rawValue),
            items: items
        ) { [controller] selectedTitle in
            if let type = TotalsType.allCases.first(where: { $0.rawValue == selectedTitle }) {
                controller.state.totalsTypeFilter = type
            }
        }
    }

    private func createActivitiesFilterMenu() -> SQDropDownMenuViewModel {
        let items = ["All", "Running", "Cycling"].map {
            SQDropDownMenuViewModel.Item(title: $0)
        }
        return SQDropDownMenuViewModel(
            defaultItem: .init(title: controller.state.activitiesTypeFilter),
            items: items
        ) { [controller] selectedTitle in
            controller.state.activitiesTypeFilter = selectedTitle
        }
    }

    var mainScroll: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Dashboard header with time range picker
                if !controller.state.isLoading {
                    HStack {
                        Text("Dashboard")
                            .sqFont(.titleLarge)
                            .sqForegroundColor(.textPrimary)

                        Spacer()

                        SQDropDownMenu(
                            menuViewModel: controller.timeRangeMenuViewModel,
                            isDisabled: false
                        )
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }

                // Loading indicator
                if controller.state.isLoading {
                    VStack(spacing: .SQSpace.xl) {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .scaleEffect(1.5)
                            .padding(.top, 100)

                        Text("Syncing daily check-ins...")
                            .sqFont(.bodySmall)
                            .sqForegroundColor(.textSecondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.SQSpace.xxl)
                }

                // Content - only show when not loading
                if !controller.state.isLoading {
                    // Daily Check-In CTA Banner
                    if let dailyCheckInCtaViewModel = controller.state.dailyCheckInCtaViewModel {
                        SQCallToAction(viewModel: dailyCheckInCtaViewModel)
                            .padding(.horizontal, 16)
                            .padding(.bottom, 16)
                    }

                    // Main sections with sticky headers
                    LazyVStack(spacing: 0, pinnedViews: [.sectionHeaders]) {
                        // Daily Stats Section
                        Section {
                            if !controller.state.isDailyStatsCollapsed {
                                VStack(spacing: 12) {
                                    metricsSubsection
                                    performanceSubsection
                                }
                                .padding(.horizontal, 16)
                                .padding(.bottom, 16)
                            }
                        } header: {
                            SQDashboardSectionHeader(
                                title: "Daily Stats",
                                isCollapsed: $controller.state.isDailyStatsCollapsed
                            )
                        }

                        // Workouts Section
                        Section {
                            if !controller.state.isWorkoutsCollapsed {
                                VStack(spacing: 12) {
                                    totalsSubsection
                                    activitiesSubsection
                                }
                                .padding(.horizontal, 16)
                                .padding(.bottom, 16)
                            }
                        } header: {
                            SQDashboardSectionHeader(
                                title: "Workouts",
                                isCollapsed: $controller.state.isWorkoutsCollapsed
                            )
                        }
                    }
                }

                Spacer()
            }
        }
    }

    var body: some View {
        mainScroll
            .navigationBarTitleDisplayMode(.inline)
           .toolbar {
               ToolbarItem(placement: .topBarLeading) {
                   HStack(spacing: .SQSpace.l) {
                       // TODO: Remove mock
                       SQUserIcon(user: .mock)
                       .frame(width: 34, height: 34)
                       
                       // Multiline welcome text
                       VStack(alignment: .leading, spacing: 2) {
                           Text("Welcome back! 👋🏻")
                               .font(.system(size: 13, weight: .medium))
                               .foregroundStyle(Color.secondary)
                           
                           // TODO: - Replace with actual user
                           Text(SQUser.mock.name)
                               .font(.system(size: 17, weight: .semibold))
                               .foregroundStyle(Color.primary)
                       }
                       .fixedSize(horizontal: true, vertical: false)
                   }
                   .padding(.SQSpace.l)
               }
               ToolbarItem(placement: .topBarTrailing) {
                   Button {
                       controller.state.hub.domainEvents.send(.displaySettings)
                   } label: {
                       Image(systemName: SQImageSymbol.gear.rawValue)
                   }
               }
           }
            .background(SQColor.background.color.ignoresSafeArea())
            .task {
                await controller.loadUI(for: modelContext)
            }
            .task { controller.attach(context: modelContext) }
            .sheet(isPresented: .init(
                get: { controller.state.isDailyCheckInSheetVisible },
                set: { isVisible in controller.state.toggleDailyCheckInSheetVisibility(isVisible) })) {
                    if let dailyCheckInViewModel = controller.state.dailyCheckInViewModel {
                        SQDailyCheckInView(viewModel: dailyCheckInViewModel)
                    }
                }
            .sheet(isPresented: .init(
                get: { controller.state.isWorkoutListSheetVisible },
                set: { isVisible in controller.state.toggleWorkoutListSheetVisibility(isVisible) })) {
                    if let workoutListController = controller.state.workoutsListController {
                        SQWorkoutsListView(controller: workoutListController)
                    }
                }
    }
}

// MARK: - UI Config
/// Controls shared UI configuration for the dashboard sub-views

extension SQDashboardView {
    
    struct UIConfig {
        let cardInnerTitleBottomPadding: CGFloat = .SQSpace.xl
        let cardSectionSpacing: CGFloat = .SQSpace.xxl
        let sectionHorizPadding: CGFloat = .SQSpace.l
    }
    
    @ViewBuilder
    static func sectionTitle(title: String) -> some View {
        Text(title)
            .sqFont(.title2)
            .sqForegroundColor(.textPrimary)
            .padding(.bottom, .SQSpace.xl)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    @ViewBuilder
    static func cardTitle(title: String, icon: SQImageSymbol? = nil) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: .SQSpace.m) {
            Text(title)
                .sqFont(.title3)
                .sqForegroundColor(.textPrimary)
            
            if let icon {
                SQImageView(image: .init(symbol: icon, symbolStyle: .colorWithFont(.textPrimary, font: .bodyExtraSmall)))
                    .frame(width: 14)
            }
        }
    }
    
    @ViewBuilder
        static func card<Content: View>(
            background: SQColor = SQColor.backgroundSecondary,
            innerHoriz: CGFloat = .SQSpace.l,
            innerVert: CGFloat = .SQSpace.l,
            cornerRadius: CGFloat = .SQCornerRadius.m,
            outerHoriz: CGFloat? = .SQSpace.l,
            outerVert: CGFloat? = nil,
            @ViewBuilder content: () -> Content
        ) -> some View {
            content()
                .padding(.horizontal, innerHoriz)
                .padding(.vertical, innerVert)
                .sqBackgroundColor(background)
                .cornerRadius(cornerRadius)
        }
}

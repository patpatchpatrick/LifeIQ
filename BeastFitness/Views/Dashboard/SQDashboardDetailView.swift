//
//  SQDashboardDetailView.swift
//  BeastFitness
//
//  Created by Codex on 5/30/26.
//

import SwiftUI

struct SQDashboardDetailView: View {
    @Bindable var controller: SQDashboardDetailController

    var body: some View {
        VStack(spacing: 0) {
            header

            ScrollView {
                VStack(spacing: .SQSpace.l) {
                    ForEach(controller.sections) { section in
                        SQDashboardSectionView(section: section)
                    }
                }
                .padding(.horizontal, .SQSpace.l)
                .padding(.top, .SQSpace.m)
                .padding(.bottom, .SQSpace.xl)
            }
            .disabled(controller.isLoading)
            .redacted(controller.isLoading, reason: .placeholder)
        }
        .background {
            SQSheetBackground()
        }
        .toolbar(.hidden, for: .navigationBar)
    }

    private var header: some View {
        HStack(alignment: .center, spacing: .SQSpace.m) {
            Text(controller.title)
                .sqFont(.title2)
                .sqForegroundColor(.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.82)

            Spacer(minLength: .SQSpace.m)

            if let timeRangeMenuViewModel = controller.timeRangeMenuViewModel {
                SQDropDownMenu(
                    menuViewModel: timeRangeMenuViewModel,
                    isDisabled: controller.isLoading
                )
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 14)
        .padding(.bottom, 8)
    }
}

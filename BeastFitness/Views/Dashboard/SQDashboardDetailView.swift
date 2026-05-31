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
        ScrollView {
            VStack(spacing: .SQSpace.l) {
                ForEach(controller.sections) { section in
                    SQDashboardSectionView(section: section)
                }
            }
            .padding(.horizontal, .SQSpace.l)
            .padding(.top, .SQSpace.l)
            .padding(.bottom, .SQSpace.xl)
        }
        .navigationTitle(controller.title)
        .navigationBarTitleDisplayMode(.inline)
        .background {
            SQSheetBackground()
        }
    }
}

//
//  SQRootLeaderboardSection.swift
//  BeastFitness
//
//  Created by Patrick Doyle on 10/21/24.
//

import Foundation
import SwiftUI

struct SQRootLeaderboardSectionHeader: View {
    let title: String
    
    var mainBody: some View {
        Text(title)
            .sqFont(.title1)
            .foregroundColor(SQColor.textPrimary.color)
            .padding(.bottom, 12)
    }
    
    var body: some View {
        mainBody
            .listRowInsets(EdgeInsets())
    }
}

struct SQRootLeaderboardSection: View {
    var viewModel: SQRootLeaderboardSectionViewModel
    let headerRowHeight: CGFloat = 25
    let rowHeight: CGFloat = 50
    let rowSpacing: CGFloat = 20
    
    var body: some View {
        Section(header: SQRootLeaderboardSectionHeader(title: viewModel.title)) {
            ScrollView(.vertical) {
                VStack(alignment: .leading, spacing: rowSpacing) {
                    HStack(spacing: 0) {
                        if let dropDownMenuViewModel = viewModel.activityTypeDropDownMenuViewModel {
                            SQDropDownMenu(menuViewModel: dropDownMenuViewModel, isDisabled: false)
                        }
                        
                        Spacer()
                    }
                    
                    ForEach(Array(viewModel.rows.enumerated()), id: \.1) { (index, rowViewModel) in
                        VStack(spacing: 0) {
                            SQRootLeaderboardSectionRow(viewModel: rowViewModel)
                                .frame(height: rowHeight)
                            
                            if index < viewModel.rows.count - 1 {
                                Color(SQColor.divider.color)
                                    .frame(height: 1)
                                    .padding(.top, 8)
                            }
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.horizontal, 8)
            .padding(.vertical, 8)
            .listRowInsets(.init(top: 0, leading: 0, bottom: 0, trailing: 0))
            .frame(maxWidth: .infinity)
            .background(SQColor.backgroundSecondary.color)
            .cornerRadius(8)
        }
        .redacted(viewModel.isPlaceholder, reason: .placeholder)
    }
}

struct SQRootLeaderboardSectionRow: View {
    var viewModel: SQRootLeaderboardSectionRowViewModel
    
    var body: some View {
        HStack(alignment: .center, spacing: 0) {
            Text(viewModel.rankString)
                .padding(.trailing, 25)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(viewModel.title)
                    .sqFont(.body)
                    .foregroundColor(SQColor.textPrimary.color)
                    .fixedSize(horizontal: true, vertical: true)
                
                Text(viewModel.subtitle)
                    .sqFont(.body)
                    .foregroundColor(SQColor.textPrimary.color)
                    .fixedSize(horizontal: true, vertical: true)
            }
            
            Spacer()
            
            Text(viewModel.outputString)
                .sqFont(.bodyBold)
                .foregroundColor(SQColor.textPrimary.color)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
    }
}

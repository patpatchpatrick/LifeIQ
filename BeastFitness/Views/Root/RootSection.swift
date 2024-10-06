//
//  RootSection.swift
//  BeastFitness
//
//  Created by Patrick Doyle on 9/30/24.
//

import SwiftUI

struct RootActivitySection: View {
    var viewModel: RootActivitySectionViewModel
    
    var body: some View {
        Section(header: Text(viewModel.title)) {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(viewModel.rows) {
                    RootActivitySectionRow(viewModel: $0)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 8)
            .listRowInsets(.init(top: 0, leading: 0, bottom: 0, trailing: 0))
            .frame(maxWidth: .infinity)
            .background(SQColor.backgroundContainer.color)
            .cornerRadius(8)
        }
        .redacted(viewModel.isPlaceholder, reason: .placeholder)
    }
}

struct RootActivitySectionRow: View {
    var viewModel: RootActivitySectionRowViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(viewModel.title)
                .font(.caption)
                .padding(.bottom, 12)
            
            ForEach(viewModel.subRows) {
                RootActivitySectionSubRow(viewModel: $0)
            }
        }
        .frame(maxWidth: .infinity,  alignment: .leading)
    }
}

struct RootActivitySectionSubRow: View {
    var viewModel: RootActivitySectionSubRowViewModel
    
    var body: some View {
        Text(viewModel.title)
            .font(.footnote)
            .background(Color.orange)
    }
}

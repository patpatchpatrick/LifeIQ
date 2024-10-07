//
//  RootSection.swift
//  BeastFitness
//
//  Created by Patrick Doyle on 9/30/24.
//

import SwiftUI

struct RootActivitySectionHeader: View {
    let title: String
    
    var mainBody: some View {
        Text(title)
    }
    
    var body: some View {
        mainBody
            .listRowInsets(EdgeInsets())
    }
}

struct RootActivitySection: View {
    var viewModel: RootActivitySectionViewModel
    
    var body: some View {
        Section(header: RootActivitySectionHeader(title: viewModel.title)) {
            ScrollView(.horizontal) {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(viewModel.rows) {
                        RootActivitySectionRow(viewModel: $0)
                    }
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
        HStack(spacing: 0) {
            ForEach(viewModel.columns) {
                RootActivitySectionColumn(viewModel: $0)
            }
        }
        .frame(maxWidth: .infinity,  alignment: .leading)
    }
}

struct RootActivitySectionColumn: View {
    var viewModel: RootActivitySectionColumnViewModel
    
    var body: some View {
        Text(viewModel.title)
            .font(.footnote)
            .background(Color.orange)
            .frame(width: 100)
    }
}

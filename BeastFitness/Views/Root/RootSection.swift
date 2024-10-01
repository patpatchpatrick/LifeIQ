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
            ForEach(viewModel.rows) {
                RootActivitySectionRow(viewModel: $0)
            }
        }
        .redacted(viewModel.isPlaceholder, reason: .placeholder)
    }
}

struct RootActivitySectionRow: View {
    var viewModel: RootActivitySectionRowViewModel
    
    var body: some View {
        Text(viewModel.title)
            .font(.caption)
            .background(Color.green)
        
        ForEach(viewModel.subRows) {
            RootActivitySectionSubRow(viewModel: $0)
        }
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

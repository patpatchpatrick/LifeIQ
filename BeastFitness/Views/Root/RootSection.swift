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
    let headerRowHeight: CGFloat = 25
    let rowHeight: CGFloat = 50
    let rowSpacing: CGFloat = 12
    
    var body: some View {
        Section(header: RootActivitySectionHeader(title: viewModel.title)) {
            HStack(alignment: .center, spacing: 0) {
                VStack(alignment: .leading, spacing: rowSpacing) {
                    if viewModel.headerRowViewModel != nil {
                        /// Placeholder for the header row
                        Text("")
                            .frame(height: headerRowHeight)
                    }
                    
                    ForEach(viewModel.rows) {
                        Text($0.workoutType?.name ?? "")
                            .frame(height: rowHeight)
                            .background(Color.purple)
                    }
                }.frame(maxHeight: .infinity)
                
                ScrollView(.horizontal) {
                    VStack(alignment: .leading, spacing: rowSpacing) {
                        if let headerRowViewModel = viewModel.headerRowViewModel {
                            RootActivitySectionHeaderRow(viewModel: headerRowViewModel)
                                .frame(height: headerRowHeight)
                        }
                        
                        ForEach(viewModel.rows) {
                            RootActivitySectionRow(viewModel: $0)
                                .frame(height: rowHeight)
                                .background(Color.pink)
                        }
                    }
                }.frame(maxHeight: .infinity)
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

struct Item: Identifiable {
    let id = UUID()
    var item: String
    var description: String = "This is the item description"
    var quantity: Int = 1
    var price: Double = 0
}

struct RootActivitySectionHeaderRow: View {
    var viewModel: RootActivitySectionHeaderRowViewModel
    
    var body: some View {
        HStack(spacing: 0) {
            ForEach(viewModel.columns) {
                RootActivitySectionColumnHeader(viewModel: $0)
                    .frame(width: $0.columnType.width)
            }
        }
        .frame(maxWidth: .infinity,  alignment: .leading)
    }
}

struct RootActivitySectionColumnHeader: View {
    var viewModel: RootActivitySectionColumnHeaderViewModel
    
    var body: some View {
        Text(viewModel.title)
            .font(.footnote)
            .background(Color.cyan)
            .frame(width: 100)
    }
}

struct RootActivitySectionRow: View {
    var viewModel: RootActivitySectionRowViewModel
    
    var body: some View {
        HStack(spacing: 0) {
            ForEach(viewModel.columns) {
                RootActivitySectionColumn(viewModel: $0)
                    .frame(width: $0.columnType.width)
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
    }
}

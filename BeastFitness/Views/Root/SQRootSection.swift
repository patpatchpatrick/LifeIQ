//
//  RootSection.swift
//  BeastFitness
//
//  Created by Patrick Doyle on 9/30/24.
//

import SwiftUI

struct SQRootActivitySectionHeader: View {
    let title: String
    
    var mainBody: some View {
        Text(title)
    }
    
    var body: some View {
        mainBody
            .listRowInsets(EdgeInsets())
    }
}

struct SQRootActivitySection: View {
    var viewModel: SQRootActivitySectionViewModel
    let headerRowHeight: CGFloat = 25
    let rowHeight: CGFloat = 50
    let rowSpacing: CGFloat = 12
    
    var body: some View {
        Section(header: SQRootActivitySectionHeader(title: viewModel.title)) {
            HStack(alignment: .center, spacing: 0) {
                VStack(alignment: .leading, spacing: rowSpacing) {
                    if viewModel.headerRowViewModel != nil {
                        /// Placeholder for the header row
                        Text("")
                            .frame(height: headerRowHeight)
                    }
                    
                    ForEach(viewModel.rows) {
                        SQImageView(image: $0.workoutType?.image ?? .init())
                            .aspectRatio(contentMode: .fit)
                            .frame(height: 20)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                            .frame(height: rowHeight)
                    }
                }
                .frame(maxHeight: .infinity)
                .frame(width: 50)
                
                ScrollView(.horizontal) {
                    VStack(alignment: .leading, spacing: rowSpacing) {
                        if let headerRowViewModel = viewModel.headerRowViewModel {
                            SQRootActivitySectionHeaderRow(viewModel: headerRowViewModel)
                                .frame(height: headerRowHeight)
                        }
                        
                        ForEach(viewModel.rows) {
                            SQRootActivitySectionRow(viewModel: $0)
                                .frame(height: rowHeight)
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

struct SQRootActivitySectionHeaderRow: View {
    var viewModel: SQRootActivitySectionHeaderRowViewModel
    
    var body: some View {
        HStack(spacing: 0) {
            ForEach(viewModel.columns) {
                SQRootActivitySectionColumnHeader(viewModel: $0)
                    .frame(width: $0.columnType.width)
            }
        }
        .frame(maxWidth: .infinity,  alignment: .leading)
    }
}

struct SQRootActivitySectionColumnHeader: View {
    var viewModel: SQRootActivitySectionColumnHeaderViewModel
    
    var body: some View {
        Text(viewModel.title)
            .font(.footnote)
            .frame(width: 100)
    }
}

struct SQRootActivitySectionRow: View {
    var viewModel: SQRootActivitySectionRowViewModel
    
    var body: some View {
        HStack(spacing: 0) {
            ForEach(viewModel.columns) {
                SQRootActivitySectionColumn(viewModel: $0)
                    .frame(width: $0.columnType.width)
            }
        }
        .frame(maxWidth: .infinity,  alignment: .leading)
    }
}

struct SQRootActivitySectionColumn: View {
    var viewModel: SQRootActivitySectionColumnViewModel
    
    var body: some View {
        Text(viewModel.title)
            .font(.footnote)
    }
}

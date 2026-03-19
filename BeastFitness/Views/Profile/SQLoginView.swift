//
//  SQLoginView.swift
//  BeastFitness
//
//  Created by Patrick Doyle on 3/18/26.
//

import SwiftUI

struct SQLoginView: View {
    @State var controller: SQLoginController

    var body: some View {
        VStack(spacing: 0) {
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .navigationTitle(controller.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    controller.toggleMode()
                } label: {
                    Text(controller.mode.toggleTitle)
                        .sqFont(.body)
                        .sqForegroundColor(.textPrimary)
                }
            }
        }
        .background(SQColor.backgroundSheet.color)
    }
}

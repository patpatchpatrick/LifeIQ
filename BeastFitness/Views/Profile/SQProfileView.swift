//
//  SQProfileView.swift
//  BeastFitness
//
//  Created by Patrick Doyle on 3/18/26.
//

import SwiftUI

struct SQProfileView: View {
    @State var controller: SQProfileController

    var body: some View {
        ScrollView {
            VStack(spacing: .SQSpace.xl) {
                SQImageView(
                    image: .init(
                        symbol: .personCircleFill,
                        symbolStyle: .colorWithFont(.textPrimary, font: .title2)
                    )
                )
                .frame(width: 64, height: 64)
                .padding(.top, .SQSpace.xl)

                HStack(spacing: .SQSpace.m) {
                    SQButton(style: .secondary, shouldHugContent: true, title: "Log in") { }
                    SQButton(style: .secondary, shouldHugContent: true, title: "Sign up") { }
                }
                .frame(maxWidth: .infinity, alignment: .center)

                VStack(spacing: 0) {
                    SQButton(style: .secondary, shouldHugContent: false, title: "Settings") { }
                }
                .frame(maxWidth: .infinity)
            }
            .padding(.horizontal, .SQSpace.xl)
            .padding(.bottom, .SQSpace.xl)
            .frame(maxWidth: .infinity)
        }
        .navigationTitle(controller.title)
        .navigationBarTitleDisplayMode(.inline)
        .background(SQColor.backgroundSheet.color)
    }
}

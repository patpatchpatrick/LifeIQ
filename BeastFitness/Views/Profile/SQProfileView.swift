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

                if controller.loginButtonViewModel != nil || controller.signUpButtonViewModel != nil {
                    HStack(spacing: .SQSpace.m) {
                        if let vm = controller.loginButtonViewModel {
                            SQButton(style: .secondary, shouldHugContent: true, title: vm.title, isDisabled: controller.isLoggingOut) {
                                vm.tapped()
                            }
                        }
                        if let vm = controller.signUpButtonViewModel {
                            SQButton(style: .secondary, shouldHugContent: true, title: vm.title, isDisabled: controller.isLoggingOut) {
                                vm.tapped()
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                    .opacity(controller.isLoggingOut ? 0.5 : 1)
                }

                VStack(spacing: .SQSpace.m) {
                    SQButton(style: .secondary, shouldHugContent: false, title: "Settings", isDisabled: controller.isLoggingOut) { }
                        .opacity(controller.isLoggingOut ? 0.5 : 1)

                    if let vm = controller.logOutButtonViewModel {
                        SQButton(
                            style: .secondary,
                            shouldHugContent: false,
                            title: vm.title,
                            isDisabled: controller.isLoggingOut,
                            isLoading: controller.isLoggingOut
                        ) {
                            vm.tapped()
                        }
                    }
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

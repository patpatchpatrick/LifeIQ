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
        ScrollView {
            VStack(spacing: .SQSpace.xl) {
                VStack(spacing: .SQSpace.m) {
                    SQUITextField(viewModel: controller.emailViewModel)
                    SQUITextField(viewModel: controller.passwordViewModel)
                }

                Spacer()

                SQButton(
                    style: .primary,
                    shouldHugContent: true,
                    title: controller.title,
                    isLoading: controller.isLoading
                ) {
                    controller.loginOrSignUpButtonTapped()
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.bottom, .SQSpace.xl)
                
                Spacer()
            }
        }
        .padding(.horizontal, .SQSpace.xl)
        .padding(.top, .SQSpace.xl)
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
        .disabled(controller.isLoading)
        .opacity(controller.isLoading ? 0.5 : 1)
        .background(SQColor.backgroundSheet.color)
    }
}

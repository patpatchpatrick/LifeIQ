//
//  SQExercisesListItem.swift
//  BeastFitness
//
//  Created by Patrick Doyle on 12/8/25.
//

import SwiftUI

struct SQExercisesListItem: View {
    let viewModel: SQExercisesListItemViewModel

    @ViewBuilder
    private var workoutImage: some View {
        ZStack {
            Circle()
                .sqForegroundColor(.backgroundSecondaryLight)
                .frame(width: 40)

            SQImageView(
                image: .init(
                    symbol: .baseball,
                    symbolStyle: .colorWithFont(.textPrimary, font: .body)
                )
            )
            .frame(width: 20)
        }
    }

    @ViewBuilder
    private var tagPill: some View {
        if let tag = viewModel.tag, !tag.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            SQTag(tag)
        }
    }

    @ViewBuilder
    private var titleRow: some View {
        HStack(alignment: .firstTextBaseline, spacing: .SQSpace.s) {
            Text(viewModel.title)
                .sqFont(.bodyBold)
                .sqForegroundColor(.textPrimary)
                .lineLimit(1)

            Spacer(minLength: .SQSpace.s)

            tagPill
        }
    }

    @ViewBuilder
    private var workoutTitleAndDescription: some View {
        VStack(alignment: .leading, spacing: .SQSpace.xs) {
            titleRow

            Text(viewModel.subtitle)
                .sqFont(.body)
                .sqForegroundColor(.textSecondary)
                .lineLimit(2)
        }
    }

    private var mainHStack: some View {
        HStack(alignment: .top, spacing: .SQSpace.m) {
            workoutImage
            workoutTitleAndDescription
            Spacer(minLength: 0)
        }
    }

    var body: some View {
        mainHStack
            .background(SQColor.background.color)
            .contentShape(Rectangle()) // makes the whole row feel tappable if you wrap it in a Button
    }
}

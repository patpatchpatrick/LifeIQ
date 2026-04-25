//
//  SQModalHost.swift
//  BeastFitness
//
//  Created by Patrick Doyle on 2/2/26.
//

import SwiftUI
import SwiftData

struct SQModalHost: View {
    @Bindable var modalState: SQModalState
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        ZStack {
            if let modal = modalState.currentModal {
                Color.black.opacity(0.45)
                    .ignoresSafeArea()
                    .onTapGesture {
                        modalState.dismiss()
                    }

                switch modal {
                case .datePicker(let dateEntries, let completionMap, let selectedDate, let selectedPeriod, let onDateSelected):
                    SQDatePickerModal(
                        dateEntries: dateEntries,
                        completionMap: completionMap,
                        selectedDate: selectedDate,
                        selectedPeriod: selectedPeriod,
                        onDateSelected: onDateSelected,
                        onDismiss: { modalState.dismiss() }
                    )
                    .transition(.scale(scale: 0.97).combined(with: .opacity))
                }
            }
        }
        .animation(.easeInOut(duration: 0.15), value: modalState.isPresented)
        .zIndex(10_001) // Above alerts
    }
}

//
//  SQDailyCheckInRowSegmentedControlViewModel.swift
//  BeastFitness
//
//  Created by Patrick Doyle on 11/25/25.
//

import SwiftUI

@Observable @MainActor
final class SQDailyCheckInRowSegmentedControlViewModel: SQDailyCheckInRowViewModel {
    // Segments for the control
    let segments: [SQSegmentedControlSegment]

    // Backing storage so we can detect changes
    private var _selectedSegment: SQSegmentedControlSegment? = nil
    var selectedSegment: SQSegmentedControlSegment? {
        get { _selectedSegment }
        set {
            let old = _selectedSegment
            _selectedSegment = newValue

            // Only react when it actually changes
            if old?.id != newValue?.id {
                self.onFocused?(self)
                self.isCompleted = newValue != nil
            }
        }
    }

    // Scale config
    let scaleConfig: ScaleConfig?
    struct ScaleConfig {
        let minText: String
        let maxText: String
    }

    // Designated init using already-mapped segments
    init(
        field: SQDailyCheckInField,
        title: String,
        scaleConfig: ScaleConfig? = .init(minText: "Very low", maxText: "Very high"),
        segments: [SQSegmentedControlSegment],
        initialSelection: SQSegmentedControlSegment? = nil,
        onFocused: ((SQDailyCheckInRowViewModel) -> Void)? = nil
    ) {
        precondition(!segments.isEmpty, "segments must not be empty")
        self.segments = segments
        self._selectedSegment = initialSelection
        self.scaleConfig = scaleConfig
        super.init(field: field, title: title, onFocused: onFocused)
    }

    // Convenience init from your enum-based segments
    convenience init<Segment: SQCheckInSegmentable & Hashable>(
        field: SQDailyCheckInField,
        title: String,
        scaleConfig: ScaleConfig? = .init(minText: "Very low", maxText: "Very high"),
        segments: [Segment],
        initialSelection: Segment? = nil,
        onFocused: ((SQDailyCheckInRowViewModel) -> Void)? = nil
    ) {
        let mappedSegments: [SQSegmentedControlSegment] = segments.map { segment in
            SQSegmentedControlSegment(
                id: segment.segmentId,
                title: segment.segmentTitle
            )
        }

        let initialMappedSelection: SQSegmentedControlSegment? = {
            guard let initial = initialSelection else { return nil }
            return SQSegmentedControlSegment(
                id: initial.segmentId,
                title: initial.segmentTitle
            )
        }()

        self.init(
            field: field,
            title: title,
            scaleConfig: scaleConfig,
            segments: mappedSegments,
            initialSelection: initialMappedSelection,
            onFocused: onFocused
        )
    }
}


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
        title: String,
        number: String,
        scaleConfig: ScaleConfig? = .init(minText: "Very low", maxText: "Very high"),
        segments: [SQSegmentedControlSegment],
        initialSelection: SQSegmentedControlSegment? = nil
    ) {
        precondition(!segments.isEmpty, "segments must not be empty")
        self.segments = segments
        self._selectedSegment = initialSelection
        self.scaleConfig = scaleConfig
        super.init(title: title, number: number)
    }

    // Convenience init from your enum-based segments
    convenience init<Segment: SQCheckInSegmentable & Hashable>(
        title: String,
        number: String,
        scaleConfig: ScaleConfig? = .init(minText: "Very low", maxText: "Very high"),
        segments: [Segment],
        initialSelection: Segment? = nil
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
            title: title,
            number: number,
            scaleConfig: scaleConfig,
            segments: mappedSegments,
            initialSelection: initialMappedSelection
        )
    }
}


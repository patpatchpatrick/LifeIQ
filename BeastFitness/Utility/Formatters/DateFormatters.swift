//
//  TimeFormatter.swift
//  BeastFitness
//
//  Created by Patrick Doyle on 10/7/24.
//

import Foundation

import Foundation

final class SQDateFormatters {
    static let shared = SQDateFormatters()
    private init() {}

    // MARK: - Public Styles

    enum FormattedDateStyle: CaseIterable {
        /// Example: "1/28/23"
        case short
        
        /// Example: "Jan 28, 2023"
        case medium
        
        /// Example: "January 28, 2023"
        case long
        
        /// Example: "Saturday, January 28, 2023 at 3:42 PM"
        case full
        
        /// Example: "3:42 PM"
        case timeOnly
        
        /// Firestore-friendly deterministic key.
        /// Example: "2025-01-22"
        case firebaseDayKey
    }

    // MARK: - Existing Formatters

    lazy var durationFormatter: DateComponentsFormatter = {
        let formatter = DateComponentsFormatter()
        formatter.unitsStyle = .abbreviated
        formatter.zeroFormattingBehavior = .dropAll
        formatter.allowedUnits = [.day, .hour, .minute, .second]
        return formatter
    }()

    lazy var iso8601Formatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.timeZone = .current
        return formatter
    }()

    lazy var dateShortFormatter: DateFormatter = {
        let df = DateFormatter()
        df.locale = .current
        df.timeZone = .current
        df.timeStyle = .short
        df.dateStyle = .short // 1/28/23
        return df
    }()

    // MARK: - Reusable DateFormatter for styled formatting/parsing

    private let baseFormatter: DateFormatter = {
        let df = DateFormatter()
        df.locale = .current
        df.timeZone = .current
        return df
    }()

    private func updateFormatter(with style: FormattedDateStyle) {
        switch style {
        case .short:
            baseFormatter.dateStyle = .short
            baseFormatter.timeStyle = .none
        case .medium:
            baseFormatter.dateStyle = .medium
            baseFormatter.timeStyle = .none
        case .long:
            baseFormatter.dateStyle = .long
            baseFormatter.timeStyle = .none
        case .full:
            baseFormatter.dateStyle = .full
            baseFormatter.timeStyle = .short
        case .timeOnly:
            baseFormatter.dateStyle = .none
            baseFormatter.timeStyle = .short
            
        case .firebaseDayKey:
            baseFormatter.dateStyle = .none
            baseFormatter.timeStyle = .none
            baseFormatter.locale = Locale(identifier: "en_US_POSIX")  // 🔥 important
            baseFormatter.timeZone = TimeZone(identifier: "UTC")
            baseFormatter.dateFormat = "yyyy-MM-dd"
        }
    }

    // MARK: - Public API

    func string(from date: Date, style: FormattedDateStyle) -> String {
        baseFormatter.locale = .current
        baseFormatter.timeZone = .current

        updateFormatter(with: style)
        return baseFormatter.string(from: date)
    }

    /// Parses a date string like `MM/dd/yy` (or equivalent for the style/locale)
    /// into a `Date` by trying the preferred style first, then all others.
    func date(from string: String, preferredStyle: FormattedDateStyle) -> Date? {
        baseFormatter.locale = .current
        baseFormatter.timeZone = .current

        // Try preferred style first, then fall back to the rest
        let styles: [FormattedDateStyle] =
            [preferredStyle] + FormattedDateStyle.allCases.filter { $0 != preferredStyle }

        for style in styles {
            updateFormatter(with: style)
            if let date = baseFormatter.date(from: string) {
                return date
            }
        }

        return nil
    }
}

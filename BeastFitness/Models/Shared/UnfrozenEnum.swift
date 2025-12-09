//
//  UnfrozenEnum.swift
//  BeastFitness
//
//  Created by Patrick Doyle on 12/8/25.
//

import Foundation

public protocol UnfrozenEnum: RawRepresentable, Codable where RawValue: Codable {
    static var unknown: Self { get }
}

public extension UnfrozenEnum {

    // MARK: - Decodable

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let raw = try container.decode(RawValue.self)
        self.init(unfrozenRawValue: raw)
    }

    /// Initializes from a raw value, logging and falling back to `.unknown`
    /// when the raw value doesn't match any known case.
    init(unfrozenRawValue raw: RawValue) {
        guard let value = Self(rawValue: raw) else {
            // BE doesn't consider enum additions as breaking changes,
            // so we log when we see an unknown case to catch changes.
            SQLogger.shared.log("Missing enum value \(raw)", .error, context: .general)
            self = .unknown
            return
        }
        self = value
    }

    // MARK: - Encodable

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

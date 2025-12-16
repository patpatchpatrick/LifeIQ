//
//  SQWorkoutActivityDetails.swift
//  BeastFitness
//
//  Created by Patrick Doyle on 12/15/25.
//

import Foundation

enum SQWorkoutActivityDetails: Codable {
    case strength(SQStrengthDetails)

    private enum CodingKeys: String, CodingKey { case type, payload }
    private enum Kind: String, Codable { case strength }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(Kind.self, forKey: .type)
        switch type {
        case .strength:
            let payload = try container.decode(SQStrengthDetails.self, forKey: .payload)
            self = .strength(payload)
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .strength(let details):
            try container.encode(Kind.strength, forKey: .type)
            try container.encode(details, forKey: .payload)
        }
    }
}

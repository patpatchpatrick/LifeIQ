//
//  SQUnitSystem.swift
//  BeastFitness
//

import Foundation

enum SQUnitSystem: String, Codable, CaseIterable {
    case imperial
    case metric

    static var defaultForCurrentLocale: SQUnitSystem {
        Locale.current.usesMetricSystem ? .metric : .imperial
    }

    var title: String {
        switch self {
        case .imperial:
            return "Imperial"
        case .metric:
            return "Metric"
        }
    }

    var weightUnit: SQUnit {
        switch self {
        case .imperial:
            return .pound
        case .metric:
            return .kilogram
        }
    }

    var heightUnit: SQUnit {
        switch self {
        case .imperial:
            return .inch
        case .metric:
            return .centimeter
        }
    }

    var temperatureUnit: SQUnit {
        switch self {
        case .imperial:
            return .degreesFahrenheit
        case .metric:
            return .degreesCelsius
        }
    }

    var volumeUnit: SQUnit {
        switch self {
        case .imperial:
            return .fluidOunce
        case .metric:
            return .milliliter
        }
    }

    func displayWeight(fromKilograms kilograms: Double?) -> Double? {
        SQUnit.kilogram.convert(kilograms, to: weightUnit)
    }

    func canonicalWeight(fromDisplayWeight weight: Double?) -> Double? {
        weightUnit.convert(weight, to: .kilogram)
    }

    func displayTemperature(fromCelsius celsius: Double?) -> Double? {
        SQUnit.degreesCelsius.convert(celsius, to: temperatureUnit)
    }

    func canonicalTemperature(fromDisplayTemperature temperature: Double?) -> Double? {
        temperatureUnit.convert(temperature, to: .degreesCelsius)
    }

    func displayVolume(fromMilliliters milliliters: Double?) -> Double? {
        SQUnit.milliliter.convert(milliliters, to: volumeUnit)
    }

    func canonicalVolume(fromDisplayVolume value: Double?) -> Double? {
        volumeUnit.convert(value, to: .milliliter)
    }

    func displayHeightPrimary(fromCentimeters centimeters: Double?) -> String {
        guard let centimeters, centimeters > 0 else { return "" }

        switch self {
        case .imperial:
            let inches = Int((SQUnit.centimeter.convert(centimeters, to: .inch) ?? 0).rounded())
            return "\(max(0, inches / 12))"
        case .metric:
            return centimeters.sqStringRoundedTo(places: 1)
        }
    }

    func displayHeightSecondary(fromCentimeters centimeters: Double?) -> String {
        guard let centimeters, centimeters > 0 else { return "" }

        switch self {
        case .imperial:
            let inches = Int((SQUnit.centimeter.convert(centimeters, to: .inch) ?? 0).rounded())
            return "\(max(0, inches % 12))"
        case .metric:
            return ""
        }
    }

    func canonicalHeight(primaryText: String, secondaryText: String) -> Double? {
        switch self {
        case .imperial:
            guard let feet = Int(primaryText), feet > 0 else { return nil }
            let inches = Int(secondaryText) ?? 0
            guard (0...11).contains(inches) else { return nil }
            return SQUnit.inch.convert(Double((feet * 12) + inches), to: .centimeter)
        case .metric:
            guard let centimeters = Double(primaryText), centimeters > 0 else { return nil }
            return centimeters
        }
    }
}

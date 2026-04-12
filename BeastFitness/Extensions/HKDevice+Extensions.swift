//
//  HKDevice+Extensions.swift
//  BeastFitness
//
//  Created by Patrick Doyle on 12/9/25.
//

import HealthKit

extension HKDevice {

    /// Returns a friendly, marketing-style device description.
    /// Example: "Apple Watch Ultra 2", "Apple Watch Series 9", "iPhone 15 Pro Max"
    var friendlyDescription: String {
        // 1. Try hardware-based map
        if let hardware = self.hardwareVersion,
           let known = HKDevice.marketingNames[hardware] {
            return known
        }

        // 2. Fall back to name + model if available
        if let name = self.name, let model = self.model {
            return "\(name) \(model)"
        } else if let model = self.model {
            return model
        }

        // 3. Absolute last resort
        return "Unknown Device"
    }


    /// Mapping of Apple model identifiers -> marketing names
    // TODO: - (Deprecated) Update this list of marketing names to be accurate
    private static let marketingNames: [String: String] = [

        // --- APPLE WATCH (1ST GENERATION) ---
        "Watch1,1": "Apple Watch (1st generation, 38mm)",
        "Watch1,2": "Apple Watch (1st generation, 42mm)",

        // --- APPLE WATCH SERIES 1 ---
        "Watch2,6": "Apple Watch Series 1 (38mm)",
        "Watch2,7": "Apple Watch Series 1 (42mm)",

        // --- APPLE WATCH SERIES 2 ---
        "Watch2,3": "Apple Watch Series 2 (38mm)",
        "Watch2,4": "Apple Watch Series 2 (42mm)",

        // --- APPLE WATCH SERIES 3 ---
        "Watch3,1": "Apple Watch Series 3 (38mm)",
        "Watch3,2": "Apple Watch Series 3 (42mm)",
        "Watch3,3": "Apple Watch Series 3 (38mm)",
        "Watch3,4": "Apple Watch Series 3 (42mm)",

        // --- APPLE WATCH SERIES 4 ---
        "Watch4,1": "Apple Watch Series 4 (40mm)",
        "Watch4,2": "Apple Watch Series 4 (44mm)",
        "Watch4,3": "Apple Watch Series 4 (40mm)",
        "Watch4,4": "Apple Watch Series 4 (44mm)",

        // --- APPLE WATCH SERIES 5 ---
        "Watch5,1": "Apple Watch Series 5 (40mm)",
        "Watch5,2": "Apple Watch Series 5 (44mm)",
        "Watch5,3": "Apple Watch Series 5 (40mm)",
        "Watch5,4": "Apple Watch Series 5 (44mm)",

        // --- APPLE WATCH SE (1ST GENERATION) ---
        "Watch5,9":  "Apple Watch SE (1st generation, 40mm)",
        "Watch5,10": "Apple Watch SE (1st generation, 44mm)",
        "Watch5,11": "Apple Watch SE (1st generation, 40mm)",
        "Watch5,12": "Apple Watch SE (1st generation, 44mm)",

        // --- APPLE WATCH SERIES 6 ---
        "Watch6,1": "Apple Watch Series 6 (40mm)",
        "Watch6,2": "Apple Watch Series 6 (44mm)",
        "Watch6,3": "Apple Watch Series 6 (40mm)",
        "Watch6,4": "Apple Watch Series 6 (44mm)",

        // --- APPLE WATCH SERIES 7 ---
        "Watch6,6": "Apple Watch Series 7 (41mm)",
        "Watch6,7": "Apple Watch Series 7 (45mm)",
        "Watch6,8": "Apple Watch Series 7 (41mm)",
        "Watch6,9": "Apple Watch Series 7 (45mm)",

        // --- APPLE WATCH SE (2ND GENERATION) ---
        "Watch6,10": "Apple Watch SE (2nd generation, 40mm)",
        "Watch6,11": "Apple Watch SE (2nd generation, 44mm)",
        "Watch6,12": "Apple Watch SE (2nd generation, 40mm)",
        "Watch6,13": "Apple Watch SE (2nd generation, 44mm)",

        // --- APPLE WATCH SERIES 8 ---
        "Watch6,14": "Apple Watch Series 8 (41mm)",
        "Watch6,15": "Apple Watch Series 8 (45mm)",
        "Watch6,16": "Apple Watch Series 8 (41mm)",
        "Watch6,17": "Apple Watch Series 8 (45mm)",

        // --- APPLE WATCH ULTRA (1ST GENERATION) ---
        "Watch6,18": "Apple Watch Ultra",

        // --- APPLE WATCH SERIES 9 ---
        "Watch7,1": "Apple Watch Series 9 (41mm)",
        "Watch7,2": "Apple Watch Series 9 (45mm)",
        "Watch7,3": "Apple Watch Series 9 (41mm)",
        "Watch7,4": "Apple Watch Series 9 (45mm)",

        // --- APPLE WATCH ULTRA 2 ---
        "Watch7,5": "Apple Watch Ultra 2",

        // --- APPLE WATCH ULTRA 3 ---
        "Watch7,12": "Apple Watch Ultra 3",

        // --- APPLE WATCH SERIES 10 ---
        "Watch7,8":  "Apple Watch Series 10 (42mm)",
        "Watch7,9":  "Apple Watch Series 10 (46mm)",
        "Watch7,10": "Apple Watch Series 10 (42mm)",
        "Watch7,11": "Apple Watch Series 10 (46mm)",

        // --- APPLE WATCH SE (3RD GENERATION) ---
        "Watch7,13": "Apple Watch SE (3rd generation, 40mm)",
        "Watch7,14": "Apple Watch SE (3rd generation, 44mm)",
        "Watch7,15": "Apple Watch SE (3rd generation, 40mm)",
        "Watch7,16": "Apple Watch SE (3rd generation, 44mm)",

        // --- APPLE WATCH SERIES 11 ---
        "Watch7,17": "Apple Watch Series 11 (42mm)",
        "Watch7,18": "Apple Watch Series 11 (46mm)",
        "Watch7,19": "Apple Watch Series 11 (42mm)",
        "Watch7,20": "Apple Watch Series 11 (46mm)",

        // --- iPHONE (from your original map, keep if you want) ---
        "iPhone14,7": "iPhone 14",
        "iPhone14,8": "iPhone 14 Plus",
        "iPhone15,2": "iPhone 14 Pro",
        "iPhone15,3": "iPhone 14 Pro Max",
        "iPhone15,4": "iPhone 15",
        "iPhone15,5": "iPhone 15 Plus",
        "iPhone16,1": "iPhone 15 Pro",
        "iPhone16,2": "iPhone 15 Pro Max"
    ]

}

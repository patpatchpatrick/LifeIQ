//
//  SQInsightRelationshipDefinition.swift
//  BeastFitness
//
//  Created by Codex on 4/22/26.
//

import Foundation

enum SQInsightClass: String, Hashable {
    case relationship
    case trend
    case baselineChange
    case followUp
    case risk
    case opportunity
    case populationBenchmark
    case cohort
}

enum SQInsightAnalyzerFamily: Hashable {
    case metricBucketComparison
}

enum SQInsightRecommendationFamily: Hashable {
    case reduce
    case increase
    case shiftEarlier
    case shiftLater
    case keepConsistent
    case protectRecovery
    case moderateStrain
    case observeAndCompare
}

enum SQInsightSurfaceIntent: Hashable {
    case today
    case pastWeek
    case pastYear
}

enum SQInsightRelationshipControlRequirement: Hashable {
    case absent
    case present
}

enum SQInsightRelationshipTiming: Hashable {
    case sameDay
    case nextDay(
        controlMetricId: String? = nil,
        controlTitle: String? = nil,
        controlRequirement: SQInsightRelationshipControlRequirement? = nil
    )
}

struct SQInsightRelationshipVariantDefinition: Hashable {
    let id: String
    let priority: Int
    let timing: SQInsightRelationshipTiming
}

struct SQInsightRelationshipDefinition: Hashable {
    let familyKey: String
    let inputSignalId: String
    let inputTitle: String
    let outputSignalId: String
    let outputTitle: String
    let insightClass: SQInsightClass
    let analyzerFamily: SQInsightAnalyzerFamily
    let category: SQInsightCategory
    let recommendationFamily: SQInsightRecommendationFamily
    let variants: [SQInsightRelationshipVariantDefinition]
    let lowBucketUpperBound: Double
    let highBucketLowerBound: Double
    let bucketUnitName: String
    let minimumBucketSampleCount: Int
    let minimumEffectMagnitude: Double
    let expectedEffect: SQInsightEffect
    let driverText: String
    let outcomeText: String
    let strongActionText: String
    let subtleActionText: String
    let isActive: Bool

    init(
        familyKey: String? = nil,
        inputSignalId: String,
        inputTitle: String,
        outputSignalId: String,
        outputTitle: String,
        insightClass: SQInsightClass = .relationship,
        analyzerFamily: SQInsightAnalyzerFamily = .metricBucketComparison,
        category: SQInsightCategory,
        recommendationFamily: SQInsightRecommendationFamily,
        variants: [SQInsightRelationshipVariantDefinition],
        lowBucketUpperBound: Double,
        highBucketLowerBound: Double,
        bucketUnitName: String = "days",
        minimumBucketSampleCount: Int = 2,
        minimumEffectMagnitude: Double = 0.15,
        expectedEffect: SQInsightEffect = .negative,
        driverText: String,
        outcomeText: String,
        strongActionText: String,
        subtleActionText: String? = nil,
        isActive: Bool = true
    ) {
        self.familyKey = familyKey ?? "\(inputSignalId)->\(outputSignalId)"
        self.inputSignalId = inputSignalId
        self.inputTitle = inputTitle
        self.outputSignalId = outputSignalId
        self.outputTitle = outputTitle
        self.insightClass = insightClass
        self.analyzerFamily = analyzerFamily
        self.category = category
        self.recommendationFamily = recommendationFamily
        self.variants = variants
        self.lowBucketUpperBound = lowBucketUpperBound
        self.highBucketLowerBound = highBucketLowerBound
        self.bucketUnitName = bucketUnitName
        self.minimumBucketSampleCount = minimumBucketSampleCount
        self.minimumEffectMagnitude = minimumEffectMagnitude
        self.expectedEffect = expectedEffect
        self.driverText = driverText
        self.outcomeText = outcomeText
        self.strongActionText = strongActionText
        self.subtleActionText = subtleActionText ?? strongActionText
        self.isActive = isActive
    }
}

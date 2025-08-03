//
//  PupilDataProcessor.swift
//  PupillometryApp
//
//  Pupil data validation, interpolation, and anomaly detection
//  Based on the preprocessing pipeline from Pupilometry-ADHD-Pre_processing.ipynb
//

import Foundation
import Accelerate

class PupilDataProcessor {
    
    // MARK: - Constants
    private static let targetSampleCount = 240  // 8 seconds at 30fps
    private static let maxMissingThreshold: Float = 0.8  // 80% missing = invalid trial
    private static let anomalyZThreshold: Float = 3.0  // Z-score threshold for anomalies
    private static let confidenceThreshold: Float = 0.3  // Minimum confidence for valid samples
    
    // MARK: - Data Validation and Processing
    
    static func processTrialData(
        pupilSamples: [Float],
        confidenceScores: [Float],
        timestamps: [TimeInterval],
        trialNumber: Int,
        blockNumber: Int
    ) -> ADHDTrialData? {
        
        print("🔍 Processing trial data - Block \(blockNumber), Trial \(trialNumber)")
        print("📊 Input: \(pupilSamples.count) samples, \(confidenceScores.count) confidence scores")
        
        // Step 1: Validate input data
        guard pupilSamples.count == confidenceScores.count,
              pupilSamples.count == timestamps.count else {
            print("❌ Data length mismatch - skipping trial")
            return nil
        }
        
        // Step 2: Check for minimum data quality
        let validSamples = zip(pupilSamples, confidenceScores).enumerated().compactMap { index, pair in
            return pair.1 >= confidenceThreshold ? pair.0 : nil
        }
        
        let missingPercentage = 1.0 - (Float(validSamples.count) / Float(pupilSamples.count))
        
        if missingPercentage >= maxMissingThreshold {
            print("⚠️ Trial \(trialNumber) has \(Int(missingPercentage * 100))% missing data - marking as invalid")
            return createInvalidTrialData(
                trialNumber: trialNumber,
                blockNumber: blockNumber,
                originalSamples: pupilSamples,
                timestamps: timestamps,
                missingCount: pupilSamples.count - validSamples.count
            )
        }
        
        // Step 3: Process the data
        let processedData = interpolateAndCleanData(
            samples: pupilSamples,
            confidenceScores: confidenceScores,
            timestamps: timestamps
        )
        
        // Step 4: Calculate quality metrics
        let qualityMetrics = calculateQualityMetrics(
            originalSamples: pupilSamples,
            processedSamples: processedData.samples,
            confidenceScores: confidenceScores,
            interpolatedIndices: processedData.interpolatedIndices,
            anomalyIndices: processedData.anomalyIndices
        )
        
        // Step 5: Determine if trial is valid
        let isValidTrial = qualityMetrics.dataQualityScore >= 0.5 && qualityMetrics.missingSampleCount < (targetSampleCount / 2)
        
        // Note: dotArrays and probePosition will be set by the task controller
        return ADHDTrialData(
            trialNumber: trialNumber,
            blockNumber: blockNumber,
            startTime: timestamps.first ?? 0,
            endTime: timestamps.last ?? 0,
            pupilSamples: processedData.samples,
            sampleTimestamps: timestamps,
            dotArrays: [], // To be filled by task controller
            probePosition: .zero, // To be filled by task controller
            loadCondition: .low, // To be filled by task controller
            distractorType: .none, // To be filled by task controller
            isValidTrial: isValidTrial,
            qualityMetrics: qualityMetrics
        )
    }
    
    // MARK: - Data Interpolation (Based on Cubic Spline from notebook)
    
    private static func interpolateAndCleanData(
        samples: [Float],
        confidenceScores: [Float],
        timestamps: [TimeInterval]
    ) -> (samples: [Float], interpolatedIndices: [Int], anomalyIndices: [Int]) {
        
        var processedSamples = samples
        var interpolatedIndices: [Int] = []
        var anomalyIndices: [Int] = []
        
        // Step 1: Identify missing and anomalous samples
        for (index, (sample, confidence)) in zip(samples, confidenceScores).enumerated() {
            // Mark low confidence as missing
            if confidence < confidenceThreshold {
                processedSamples[index] = Float.nan
            }
            // Detect anomalies using Z-score (simplified approach)
            else if isAnomalousValue(sample, in: samples) {
                anomalyIndices.append(index)
                processedSamples[index] = Float.nan
            }
        }
        
        // Step 2: Handle edge cases (first/last missing values)
        processedSamples = fillEdgeMissingValues(processedSamples)
        
        // Step 3: Interpolate missing values using linear interpolation
        // (Simplified version of cubic spline from the notebook)
        processedSamples = linearInterpolation(processedSamples, interpolatedIndices: &interpolatedIndices)
        
        return (processedSamples, interpolatedIndices, anomalyIndices)
    }
    
    private static func fillEdgeMissingValues(_ samples: [Float]) -> [Float] {
        var result = samples
        
        // Fill first missing values
        if let firstValidIndex = result.firstIndex(where: { !$0.isNaN }) {
            let firstValidValue = result[firstValidIndex]
            for i in 0..<firstValidIndex {
                result[i] = firstValidValue
            }
        }
        
        // Fill last missing values
        if let lastValidIndex = result.lastIndex(where: { !$0.isNaN }) {
            let lastValidValue = result[lastValidIndex]
            for i in (lastValidIndex + 1)..<result.count {
                result[i] = lastValidValue
            }
        }
        
        return result
    }
    
    private static func linearInterpolation(_ samples: [Float], interpolatedIndices: inout [Int]) -> [Float] {
        var result = samples
        
        for i in 0..<result.count {
            if result[i].isNaN {
                // Find surrounding valid values
                let leftIndex = findNearestValidIndex(in: result, from: i, direction: -1)
                let rightIndex = findNearestValidIndex(in: result, from: i, direction: 1)
                
                if let left = leftIndex, let right = rightIndex {
                    let leftValue = result[left]
                    let rightValue = result[right]
                    let ratio = Float(i - left) / Float(right - left)
                    result[i] = leftValue + (rightValue - leftValue) * ratio
                    interpolatedIndices.append(i)
                }
            }
        }
        
        return result
    }
    
    private static func findNearestValidIndex(in samples: [Float], from startIndex: Int, direction: Int) -> Int? {
        var index = startIndex + direction
        while index >= 0 && index < samples.count {
            if !samples[index].isNaN {
                return index
            }
            index += direction
        }
        return nil
    }
    
    // MARK: - Anomaly Detection
    
    private static func isAnomalousValue(_ value: Float, in samples: [Float]) -> Bool {
        let validSamples = samples.compactMap { $0.isNaN ? nil : $0 }
        guard validSamples.count > 10 else { return false }
        
        let mean = validSamples.reduce(0, +) / Float(validSamples.count)
        let variance = validSamples.reduce(0) { $0 + pow($1 - mean, 2) } / Float(validSamples.count - 1)
        let standardDeviation = sqrt(variance)
        
        let zScore = abs(value - mean) / standardDeviation
        return zScore > anomalyZThreshold
    }
    
    // MARK: - Quality Metrics Calculation
    
    private static func calculateQualityMetrics(
        originalSamples: [Float],
        processedSamples: [Float],
        confidenceScores: [Float],
        interpolatedIndices: [Int],
        anomalyIndices: [Int]
    ) -> ADHDTrialData.TrialQualityMetrics {
        
        let missingCount = originalSamples.filter { $0.isNaN }.count +
                          confidenceScores.enumerated().filter { $1 < confidenceThreshold }.count
        
        let averageConfidence = confidenceScores.reduce(0, +) / Float(confidenceScores.count)
        
        // Calculate data quality score (0.0-1.0)
        let missingPenalty = Float(missingCount) / Float(originalSamples.count)
        let interpolationPenalty = Float(interpolatedIndices.count) / Float(originalSamples.count) * 0.5
        let anomalyPenalty = Float(anomalyIndices.count) / Float(originalSamples.count) * 0.3
        
        let dataQualityScore = max(0.0, 1.0 - missingPenalty - interpolationPenalty - anomalyPenalty)
        
        return ADHDTrialData.TrialQualityMetrics(
            missingSampleCount: missingCount,
            interpolatedSampleCount: interpolatedIndices.count,
            anomalyCount: anomalyIndices.count,
            averageConfidence: averageConfidence,
            dataQualityScore: dataQualityScore
        )
    }
    
    private static func createInvalidTrialData(
        trialNumber: Int,
        blockNumber: Int,
        originalSamples: [Float],
        timestamps: [TimeInterval],
        missingCount: Int
    ) -> ADHDTrialData {
        
        let qualityMetrics = ADHDTrialData.TrialQualityMetrics(
            missingSampleCount: missingCount,
            interpolatedSampleCount: 0,
            anomalyCount: 0,
            averageConfidence: 0.0,
            dataQualityScore: 0.0
        )
        
        return ADHDTrialData(
            trialNumber: trialNumber,
            blockNumber: blockNumber,
            startTime: timestamps.first ?? 0,
            endTime: timestamps.last ?? 0,
            pupilSamples: originalSamples,
            sampleTimestamps: timestamps,
            dotArrays: [],
            probePosition: .zero,
            loadCondition: .low,
            distractorType: .none,
            isValidTrial: false,
            qualityMetrics: qualityMetrics
        )
    }
    
    // MARK: - Training Data Compatibility
    
    // Sparse sampling indices from training data (final_data_v3.csv)
    private static let sparseSampleIndices: [Int] = [
        0, 3, 4, 7, 9, 10, 13, 14, 17, 19, 21, 24, 26, 28, 30, 32, 33, 35, 38, 40,
        41, 43, 45, 47, 50, 53, 54, 56, 58, 61, 63, 65, 67, 69, 70, 72, 76, 78, 79, 81,
        84, 85, 87, 89, 91, 94, 95, 97, 101, 103, 104, 106, 108, 110, 113, 115, 117, 118, 120, 122,
        125, 127, 129, 131, 133, 136, 138, 139, 142, 144, 146, 149, 150, 152, 154, 157, 159, 160, 162, 165,
        166, 168, 170, 172, 176, 177, 179, 182, 184, 186, 187, 189, 192, 194, 195, 198, 200, 202, 204, 206,
        208, 210, 213, 215, 216, 218, 220, 224, 226, 228, 230, 232, 233, 235, 238, 240, 241, 243, 245, 248,
        250, 252, 254, 256, 258, 261, 263, 265, 266, 268, 271, 274, 275, 278, 280, 281, 283, 285, 288, 289,
        292, 294, 296, 297, 301, 303, 305, 306, 308, 311, 313, 315, 316, 318, 320, 322, 326, 328, 330, 332,
        334, 335, 337, 340, 342, 343, 345, 347, 350, 352, 354, 356, 358, 360, 362, 364, 367, 368, 371, 374,
        375, 378, 380, 381, 383, 385, 387, 389, 391, 394, 396, 398, 400, 403, 404, 407, 408, 410, 412, 415,
        417, 419, 421, 424, 426, 428, 429, 431, 433, 436, 438, 439, 441, 443, 445, 447, 450, 452, 454, 456,
        458, 460, 462, 464, 466, 468, 471, 474, 475, 478, 479, 482, 483, 485, 488, 489, 492, 494, 496, 499
    ]
    
    // MARK: - Export Format Helpers
    
    static func exportTrialToPrepFormat(_ trialData: ADHDTrialData, subject: Int, adhdIdentifier: String, response: ADHDProtocolResponse?) -> [String: Any] {
        var exportData: [String: Any] = [:]
        
        // Basic trial info
        exportData["Subject"] = subject
        exportData["ADHD_Identifier"] = adhdIdentifier
        exportData["Trial"] = trialData.trialNumber
        exportData["Perform"] = response?.isCorrect == true ? 1 : 0
        exportData["Rtime"] = response?.reactionTime ?? 0
        
        // Add sparse pupil samples using training data indices
        let samples = trialData.pupilSamples
        for sparseIndex in sparseSampleIndices {
            let sampleValue: Float
            if sparseIndex < samples.count {
                sampleValue = samples[sparseIndex]
            } else {
                sampleValue = 0.0  // Pad with zeros if we don't have enough samples
            }
            exportData["\(sparseIndex)"] = sampleValue
        }
        
        // Add computed features (11 features)
        let computedFeatures = calculateComputedFeatures(samples: samples, sampleTimestamps: trialData.sampleTimestamps)
        exportData["Max0_5000"] = computedFeatures.max0_5000
        exportData["Max5000_8000"] = computedFeatures.max5000_8000
        exportData["TPS_start"] = computedFeatures.tpsStart
        exportData["TPS_end"] = computedFeatures.tpsEnd
        exportData["TD"] = computedFeatures.td
        exportData["MaxV"] = computedFeatures.maxV
        exportData["TotalV"] = computedFeatures.totalV
        exportData["MaxA"] = computedFeatures.maxA
        exportData["TotalA"] = computedFeatures.totalA
        exportData["PPS_AT"] = computedFeatures.ppsAT
        exportData["PPS_WM"] = computedFeatures.ppsWM
        
        // Add velocity features (60 velocity samples)
        let velocityFeatures = calculateVelocityFeatures(samples: samples)
        for (index, velocity) in velocityFeatures.enumerated() {
            exportData["velocity_\(index)"] = velocity
        }
        
        return exportData
    }
    
    // MARK: - Computed Features Calculation
    
    private struct ComputedFeatures {
        let max0_5000: Float      // Maximum pupil size in first 5 seconds (0-150 frames at 30fps)
        let max5000_8000: Float   // Maximum pupil size in last 3 seconds (150-240 frames)
        let tpsStart: Float       // Task-relevant pupil size at start
        let tpsEnd: Float         // Task-relevant pupil size at end
        let td: Float             // Total dilation (max - min)
        let maxV: Float           // Maximum velocity
        let totalV: Float         // Total velocity (sum of absolute velocities)
        let maxA: Float           // Maximum acceleration
        let totalA: Float         // Total acceleration (sum of absolute accelerations)
        let ppsAT: Float          // Pupil response during attention phase
        let ppsWM: Float          // Pupil response during working memory phase
    }
    
    private static func calculateComputedFeatures(samples: [Float], sampleTimestamps: [TimeInterval]) -> ComputedFeatures {
        guard !samples.isEmpty else {
            return ComputedFeatures(max0_5000: 0, max5000_8000: 0, tpsStart: 0, tpsEnd: 0, td: 0,
                                  maxV: 0, totalV: 0, maxA: 0, totalA: 0, ppsAT: 0, ppsWM: 0)
        }
        
        // Calculate max in first 5 seconds (0-150 frames at 30fps)
        let firstPhaseEnd = min(150, samples.count)
        let max0_5000 = samples[0..<firstPhaseEnd].max() ?? 0.0
        
        // Calculate max in last 3 seconds (150-240 frames)
        let secondPhaseStart = min(150, samples.count)
        let max5000_8000 = secondPhaseStart < samples.count ? 
            samples[secondPhaseStart..<samples.count].max() ?? 0.0 : 0.0
        
        // Task-relevant pupil sizes
        let tpsStart = samples.first ?? 0.0
        let tpsEnd = samples.last ?? 0.0
        
        // Total dilation (max - min)
        let maxSample = samples.max() ?? 0.0
        let minSample = samples.min() ?? 0.0
        let td = maxSample - minSample
        
        // Calculate velocities and accelerations
        var velocities: [Float] = []
        var accelerations: [Float] = []
        
        for i in 1..<samples.count {
            let velocity = samples[i] - samples[i-1]
            velocities.append(velocity)
            
            if i > 1 {
                let acceleration = velocities[i-1] - velocities[i-2]
                accelerations.append(acceleration)
            }
        }
        
        let maxV = velocities.map { abs($0) }.max() ?? 0.0
        let totalV = velocities.reduce(0) { $0 + abs($1) }
        let maxA = accelerations.map { abs($0) }.max() ?? 0.0
        let totalA = accelerations.reduce(0) { $0 + abs($1) }
        
        // Phase-specific pupil responses
        let attentionPhaseEnd = min(150, samples.count)
        let ppsAT = attentionPhaseEnd > 0 ? samples[0..<attentionPhaseEnd].reduce(0, +) / Float(attentionPhaseEnd) : 0.0
        
        let workingMemoryStart = min(150, samples.count)
        let ppsWM = workingMemoryStart < samples.count ? 
            samples[workingMemoryStart..<samples.count].reduce(0, +) / Float(samples.count - workingMemoryStart) : 0.0
        
        return ComputedFeatures(
            max0_5000: max0_5000,
            max5000_8000: max5000_8000,
            tpsStart: tpsStart,
            tpsEnd: tpsEnd,
            td: td,
            maxV: maxV,
            totalV: totalV,
            maxA: maxA,
            totalA: totalA,
            ppsAT: ppsAT,
            ppsWM: ppsWM
        )
    }
    
    // MARK: - Velocity Features Calculation
    
    private static func calculateVelocityFeatures(samples: [Float]) -> [Float] {
        guard samples.count > 1 else {
            return Array(repeating: 0.0, count: 60) // Return 60 zeros if not enough samples
        }
        
        // Calculate velocities
        var velocities: [Float] = []
        for i in 1..<samples.count {
            let velocity = samples[i] - samples[i-1]
            velocities.append(velocity)
        }
        
        // If we have more than 60 velocity samples, subsample to get exactly 60
        if velocities.count >= 60 {
            let step = Float(velocities.count) / 60.0
            var sampledVelocities: [Float] = []
            
            for i in 0..<60 {
                let index = Int(Float(i) * step)
                let clampedIndex = min(index, velocities.count - 1)
                sampledVelocities.append(velocities[clampedIndex])
            }
            
            return sampledVelocities
        } else {
            // If we have fewer than 60, pad with zeros
            var paddedVelocities = velocities
            while paddedVelocities.count < 60 {
                paddedVelocities.append(0.0)
            }
            return paddedVelocities
        }
    }
    
    // MARK: - Multi-Block Trial Aggregation
    
    static func aggregateBlocksIntoTrial(blocks: [ADHDTrialData], responses: [ADHDProtocolResponse], subject: Int, adhdIdentifier: String) -> [String: Any]? {
        guard !blocks.isEmpty, !responses.isEmpty else {
            print("❌ PupilDataProcessor: No blocks or responses to aggregate")
            return nil
        }
        
        print("📊 PupilDataProcessor: Aggregating \(blocks.count) blocks into 1 trial")
        
        var exportData: [String: Any] = [:]
        
        // Basic trial info - extract trial number from first block
        let trialNumber = blocks.first?.trialNumber ?? 1
        exportData["Subject"] = subject
        exportData["ADHD_Identifier"] = adhdIdentifier
        exportData["Trial"] = trialNumber
        
        // Aggregate performance across all blocks
        let correctResponses = responses.filter { $0.isCorrect }.count
        let averagePerform = Float(correctResponses) / Float(responses.count)
        exportData["Perform"] = round(averagePerform)  // Round to nearest integer (0 or 1)
        
        // Aggregate reaction times across all blocks
        let validReactionTimes = responses.compactMap { $0.reactionTime }
        let averageRtime = validReactionTimes.isEmpty ? 0.0 : validReactionTimes.reduce(0, +) / Double(validReactionTimes.count)
        exportData["Rtime"] = averageRtime
        
        // Combine pupil samples from all blocks
        var allPupilSamples: [Float] = []
        var allTimestamps: [TimeInterval] = []
        
        for block in blocks {
            allPupilSamples.append(contentsOf: block.pupilSamples)
            allTimestamps.append(contentsOf: block.sampleTimestamps)
        }
        
        print("📊 Combined \(allPupilSamples.count) pupil samples from \(blocks.count) blocks")
        
        // Ensure we have at least 240 samples by interpolation if needed
        let processedSamples = ensureMinimumSamples(samples: allPupilSamples, targetCount: 500)  // Target 500 samples (8.33s at 60fps)
        
        // Add sparse pupil samples using training data indices
        for sparseIndex in sparseSampleIndices {
            let sampleValue: Float
            if sparseIndex < processedSamples.count {
                sampleValue = processedSamples[sparseIndex]
            } else {
                sampleValue = 0.0  // Pad with zeros if we don't have enough samples
            }
            exportData["\(sparseIndex)"] = sampleValue
        }
        
        // Add computed features (11 features) using combined samples
        let computedFeatures = calculateComputedFeatures(samples: processedSamples, sampleTimestamps: allTimestamps)
        exportData["Max0_5000"] = computedFeatures.max0_5000
        exportData["Max5000_8000"] = computedFeatures.max5000_8000
        exportData["TPS_start"] = computedFeatures.tpsStart
        exportData["TPS_end"] = computedFeatures.tpsEnd
        exportData["TD"] = computedFeatures.td
        exportData["MaxV"] = computedFeatures.maxV
        exportData["TotalV"] = computedFeatures.totalV
        exportData["MaxA"] = computedFeatures.maxA
        exportData["TotalA"] = computedFeatures.totalA
        exportData["PPS_AT"] = computedFeatures.ppsAT
        exportData["PPS_WM"] = computedFeatures.ppsWM
        
        // Add velocity features (60 velocity samples) using combined samples
        let velocityFeatures = calculateVelocityFeatures(samples: processedSamples)
        for (index, velocity) in velocityFeatures.enumerated() {
            exportData["velocity_\(index)"] = velocity
        }
        
        print("✅ Trial aggregation complete: \(exportData.count) features generated")
        return exportData
    }
    
    // Helper method to ensure minimum sample count through interpolation
    private static func ensureMinimumSamples(samples: [Float], targetCount: Int) -> [Float] {
        guard !samples.isEmpty else {
            print("⚠️ No samples to process - returning zeros")
            return Array(repeating: 0.0, count: targetCount)
        }
        
        if samples.count >= targetCount {
            // If we have enough samples, return the first targetCount
            return Array(samples.prefix(targetCount))
        } else {
            // If we don't have enough samples, interpolate to reach target count
            print("📈 Interpolating from \(samples.count) to \(targetCount) samples")
            
            var interpolatedSamples: [Float] = []
            let ratio = Float(samples.count - 1) / Float(targetCount - 1)
            
            for i in 0..<targetCount {
                let exactIndex = Float(i) * ratio
                let lowerIndex = Int(floor(exactIndex))
                let upperIndex = min(lowerIndex + 1, samples.count - 1)
                let fraction = exactIndex - Float(lowerIndex)
                
                let interpolatedValue = samples[lowerIndex] * (1.0 - fraction) + samples[upperIndex] * fraction
                interpolatedSamples.append(interpolatedValue)
            }
            
            return interpolatedSamples
        }
    }
}
//
//  PythonCompatibleFeatureExtractor.swift
//  PupillometryApp
//
//  Feature extraction that matches the Python training pipeline exactly
//  Generates the same 311 features used to train the CoreML model
//

import Foundation
import Accelerate

class PythonCompatibleFeatureExtractor {
    
    // MARK: - Main Feature Extraction (Matches Python Script)
    
    func extractFeaturesForModel(from measurements: [PupilMeasurement]) -> [Float]? {
        print("🔄 PythonCompatibleFeatureExtractor: Extracting features matching Python pipeline...")
        
        // Step 1: Extract 240 pupil diameter samples
        let pupilSamples = extractPupilSamples(from: measurements)
        guard pupilSamples.count == 240 else {
            print("❌ Expected 240 samples, got \(pupilSamples.count)")
            return nil
        }
        
        // Step 2: Calculate derived features (matches Python calculate_derived_features)
        let derivedFeatures = calculateDerivedFeatures(pupilSamples)
        
        // Step 3: Combine original samples + derived features
        var allFeatures: [Float] = []
        allFeatures.append(contentsOf: pupilSamples)           // 240 features
        allFeatures.append(contentsOf: derivedFeatures)        // ~71 features
        
        print("✅ PythonCompatibleFeatureExtractor: Generated \(allFeatures.count) features")
        return allFeatures
    }
    
    // MARK: - Step 1: Extract 240 Pupil Samples (Matches Training Sparse Indices)
    
    private func extractPupilSamples(from measurements: [PupilMeasurement]) -> [Float] {
        // Extract exactly 240 samples using the SAME SPARSE INDICES as training data
        // Training uses specific indices: 0,3,4,7,9,10,13,14,17,19,21,24,26,28,30...499
        let trainingIndices = getTrainingDataIndices()
        
        let samples = measurements.map { $0.diameterMM }
        
        // Resample to match training data length first
        let resampledSamples: [Float]
        if samples.count != 500 {
            resampledSamples = resampleArray(samples, targetLength: 500)
        } else {
            resampledSamples = samples
        }
        
        // Extract using exact training indices
        var sparseIndexedSamples: [Float] = []
        for index in trainingIndices {
            if index < resampledSamples.count {
                sparseIndexedSamples.append(resampledSamples[index])
            } else {
                sparseIndexedSamples.append(0.0) // Fallback
            }
        }
        
        print("📊 Extracted \(sparseIndexedSamples.count) samples using training sparse indices")
        return sparseIndexedSamples
    }
    
    private func getTrainingDataIndices() -> [Int] {
        // EXACT indices from training CSV header (columns 7-246: pupil samples)
        return [0,3,4,7,9,10,13,14,17,19,21,24,26,28,30,32,33,35,38,40,41,43,45,47,50,53,54,56,58,61,63,65,67,69,70,72,76,78,79,81,84,85,87,89,91,94,95,97,101,103,104,106,108,110,113,115,117,118,120,122,125,127,129,131,133,136,138,139,142,144,146,149,150,152,154,157,159,160,162,165,166,168,170,172,176,177,179,182,184,186,187,189,192,194,195,198,200,202,204,206,208,210,213,215,216,218,220,224,226,228,230,232,233,235,238,240,241,243,245,248,250,252,254,256,258,261,263,265,266,268,271,274,275,278,280,281,283,285,288,289,292,294,296,297,301,303,305,306,308,311,313,315,316,318,320,322,326,328,330,332,334,335,337,340,342,343,345,347,350,352,354,356,358,360,362,364,367,368,371,374,375,378,380,381,383,385,387,389,391,394,396,398,400,403,404,407,408,410,412,415,417,419,421,424,426,428,429,431,433,436,438,439,441,443,445,447,450,452,454,456,458,460,462,464,466,468,471,474,475,478,479,482,483,485,488,489,492,494,496,499]
    }
    
    private func resampleArray(_ array: [Float], targetLength: Int) -> [Float] {
        guard array.count != targetLength else { return array }
        
        var result: [Float] = []
        let step = Float(array.count - 1) / Float(targetLength - 1)
        
        for i in 0..<targetLength {
            let index = Float(i) * step
            let lowerIndex = Int(floor(index))
            let upperIndex = min(lowerIndex + 1, array.count - 1)
            let fraction = index - Float(lowerIndex)
            
            if lowerIndex == upperIndex {
                result.append(array[lowerIndex])
            } else {
                let interpolated = array[lowerIndex] + fraction * (array[upperIndex] - array[lowerIndex])
                result.append(interpolated)
            }
        }
        
        return result
    }
    
    // MARK: - Step 2: Calculate Derived Features (Matches Python Script)
    
    private func calculateDerivedFeatures(_ pupilSamples: [Float]) -> [Float] {
        var features: [Float] = []
        
        // Find peaks (simple peak detection like Python)
        let peaks = findPeaksSimple(pupilSamples)
        
        // Feature calculations matching Python script exactly
        let baselineStart = pupilSamples[0]  // TPS_start
        let baselineEnd = pupilSamples[pupilSamples.count - 1]  // TPS_end
        
        // Calculate Max0_5000 (peak difference in first half)
        let midpoint = pupilSamples.count / 2
        let peaksBeforeMid = peaks.filter { $0 <= midpoint }
        let max0_5000: Float
        if peaksBeforeMid.count > 0 {
            let firstPeak = pupilSamples[peaksBeforeMid[0]]
            let lastPeakBeforeMid = pupilSamples[peaksBeforeMid[peaksBeforeMid.count - 1]]
            max0_5000 = lastPeakBeforeMid - firstPeak
        } else {
            max0_5000 = 0
        }
        
        // Calculate Max5000_8000 (maximum peak in second half)
        let peaksAfterMid = peaks.filter { $0 > midpoint }
        let max5000_8000: Float
        if peaksAfterMid.count > 0 {
            max5000_8000 = findMaximumAtPeaks(peaksAfterMid, values: pupilSamples)
        } else {
            max5000_8000 = 0
        }
        
        // Calculate total distance (TD)
        let totalDistance = calculateTotalDistance(pupilSamples)
        
        // Calculate velocities for post-5000 segment (62.5% to 87.5% of trial)
        let startIdx = Int(Float(pupilSamples.count) * 0.625)  // 5000/8000 = 0.625
        let endIdx = Int(Float(pupilSamples.count) * 0.875)    // 7000/8000 = 0.875
        let segmentSamples = Array(pupilSamples[startIdx..<endIdx])
        
        let (velocities, accelerations) = calculateVelocitiesAndAccelerations(segmentSamples)
        
        let maxV = velocities.max() ?? 0
        let totalV = velocities.reduce(0, +)
        let maxA = accelerations.max() ?? 0
        let totalA = accelerations.reduce(0, +)
        
        // Calculate PPS features
        let pps_at = max0_5000 - baselineStart      // PPS_AT
        let pps_wm = max5000_8000 - baselineStart   // PPS_WM
        
        // Add scalar derived features (11 total - matches Python)
        features.append(max0_5000)       // Max0_5000
        features.append(max5000_8000)    // Max5000_8000  
        features.append(baselineStart)   // TPS_start
        features.append(baselineEnd)     // TPS_end
        features.append(totalDistance)   // TD
        features.append(maxV)            // MaxV
        features.append(totalV)          // TotalV
        features.append(maxA)            // MaxA
        features.append(totalA)          // TotalA
        features.append(pps_at)          // PPS_AT
        features.append(pps_wm)          // PPS_WM
        
        // Add exactly 60 velocity features (matches Python velocity_0 to velocity_59)
        let velocityFeatures = normalizeVelocitiesToCount(velocities, targetCount: 60)
        features.append(contentsOf: velocityFeatures)
        
        print("📊 Derived features: 11 scalar + \(velocityFeatures.count) velocity = \(features.count) total")
        return features
    }
    
    // MARK: - Helper Functions (Match Python Implementation)
    
    private func findPeaksSimple(_ values: [Float]) -> [Int] {
        // Simple peak detection (matches Python find_peaks behavior)
        var peaks: [Int] = []
        
        for i in 1..<(values.count - 1) {
            if values[i] > values[i-1] && values[i] > values[i+1] {
                peaks.append(i)
            }
        }
        
        return peaks
    }
    
    private func findMaximumAtPeaks(_ peaks: [Int], values: [Float]) -> Float {
        // Matches Python find_maximum function
        var maxValue: Float = -1000
        
        for peakIndex in peaks {
            let localMaxima = values[peakIndex]
            if maxValue < localMaxima {
                maxValue = localMaxima
            }
        }
        
        return maxValue
    }
    
    private func calculateTotalDistance(_ values: [Float]) -> Float {
        // Matches Python find_distance function
        var total: Float = 0
        let baseline = values[0]
        
        for i in 1..<values.count {
            total += abs(values[i] - baseline)
        }
        
        return total
    }
    
    private func calculateVelocitiesAndAccelerations(_ values: [Float]) -> ([Float], [Float]) {
        // Matches Python find_velocities function exactly
        var velocities: [Float] = []
        var accelerations: [Float] = []
        
        // Subtract first value (baseline correction)
        let baselineCorrected = values.map { $0 - values[0] }
        
        // Calculate velocities: velocity = values[i] / (i + 1)
        for i in 0..<baselineCorrected.count {
            let velocity = baselineCorrected[i] / Float(i + 1)
            velocities.append(velocity)
        }
        
        // Subtract first velocity from all velocities
        let firstVelocity = velocities[0]
        velocities = velocities.map { $0 - firstVelocity }
        
        // Calculate accelerations: acceleration = velocities[i] / (i + 1)
        for i in 1..<velocities.count {
            let acceleration = velocities[i] / Float(i + 1)
            accelerations.append(acceleration)
        }
        
        return (velocities, accelerations)
    }
    
    private func normalizeVelocitiesToCount(_ velocities: [Float], targetCount: Int) -> [Float] {
        // Ensure exactly targetCount velocity features to match training data
        if velocities.count == targetCount {
            return velocities
        } else if velocities.count > targetCount {
            // Downsample to target count
            return resampleArray(velocities, targetLength: targetCount)
        } else {
            // Pad with zeros if we have fewer velocities
            var normalized = velocities
            while normalized.count < targetCount {
                normalized.append(0.0)
            }
            return normalized
        }
    }
}
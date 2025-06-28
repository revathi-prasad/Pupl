//
//  FeatureExtractor.swift
//  PupillometryApp
//
//  Created by Revathi Prasad on 08/06/25.
//


// FeatureExtractor.swift

import Accelerate
import QuartzCore

class FeatureExtractor {
    private let samplingRate: Double = 60.0 // Hz
    
    func extractFeatures(from measurements: [PupilMeasurement], events: [TaskEvent]) -> ADHDFeatures? {
        guard measurements.count > Int(samplingRate) else { return nil } // Need at least 1 second
        
        // Extract diameter array
        let diameters = measurements.map { $0.diameterMM }
        
        // Calculate baseline (first 500ms)
        let baselineCount = Int(samplingRate * 0.5)
        let baseline = Array(diameters.prefix(baselineCount)).average()
        
        // Calculate phasic response
        let phasic = diameters.map { ($0 - baseline) / baseline * 100 }
        
        // Calculate velocity
        let velocity = calculateVelocity(diameters, samplingRate: samplingRate)
        
        // Calculate acceleration
        let acceleration = calculateVelocity(velocity, samplingRate: samplingRate)
        
        // Extract windows for different task phases
        let attentionWindow = extractWindow(phasic, start: 0, end: 5, samplingRate: samplingRate)
        let memoryWindow = extractWindow(phasic, start: 5, end: 8, samplingRate: samplingRate)
        
        // Calculate behavioral metrics
        let rtData = extractReactionTimes(from: events)
        
        return ADHDFeatures(
            tonicStartMM: baseline,
            tonicEndMM: diameters.last ?? baseline,
            baselineStability: Array(diameters.prefix(baselineCount)).standardDeviation(),
            maxPhasicAttention: attentionWindow.max() ?? 0,
            maxPhasicMemory: memoryWindow.max() ?? 0,
            phasicRange: (phasic.max() ?? 0) - (phasic.min() ?? 0),
            timeToPeak: findTimeToPeak(phasic, samplingRate: samplingRate),
            velocityProfile: velocity,
            accelerationTrend: acceleration,
            totalDistance: calculateTotalDistance(diameters),
            reactionTime: rtData.mean,
            accuracy: rtData.accuracy,
            processingSpeed: Float(1.0 / rtData.mean)  // Convert Double to Float
        )
    }
    
    private func calculateVelocity(_ data: [Float], samplingRate: Double) -> [Float] {
        guard data.count > 1 else { return [] }
        
        var velocity: [Float] = []
        let dt = Float(1.0 / samplingRate)
        
        for i in 1..<data.count {
            let v = (data[i] - data[i-1]) / dt
            // Apply physiological constraints
            let constrainedV = min(max(v, -4.0), 1.0)
            velocity.append(constrainedV)
        }
        
        return velocity
    }
    
    private func extractWindow(_ data: [Float], start: Double, end: Double, samplingRate: Double) -> [Float] {
        let startIndex = Int(start * samplingRate)
        let endIndex = min(Int(end * samplingRate), data.count)
        
        guard startIndex < data.count, endIndex > startIndex else { return [] }
        
        return Array(data[startIndex..<endIndex])
    }
    
    private func findTimeToPeak(_ data: [Float], samplingRate: Double) -> TimeInterval {
        guard let maxValue = data.max(),
              let maxIndex = data.firstIndex(of: maxValue) else { return 0 }
        return Double(maxIndex) / samplingRate
    }
    
    private func calculateTotalDistance(_ data: [Float]) -> Float {
        guard data.count > 1 else { return 0 }
        
        var distance: Float = 0
        for i in 1..<data.count {
            distance += abs(data[i] - data[i-1])
        }
        
        return distance
    }
    
    private func extractReactionTimes(from events: [TaskEvent]) -> (mean: TimeInterval, accuracy: Float) {
        let responses = events.filter { $0.type == .response }
        guard !responses.isEmpty else { return (0, 0) }
        
        let rts = responses.compactMap { $0.data["reactionTime"] as? TimeInterval }
        let correct = responses.compactMap { $0.data["correct"] as? Bool }.filter { $0 }.count
        
        return (
            mean: rts.average(),
            accuracy: Float(correct) / Float(responses.count)
        )
    }
}

// MARK: - Array Extensions
extension Array where Element == Float {
    func average() -> Float {
        guard !isEmpty else { return 0 }
        return reduce(0, +) / Float(count)
    }
    
    func standardDeviation() -> Float {
        guard count > 1 else { return 0 }
        
        let mean = average()
        let variance = map { pow($0 - mean, 2) }.average()
        return sqrt(variance)
    }
}

extension Array where Element == TimeInterval {
    func average() -> TimeInterval {
        guard !isEmpty else { return 0 }
        return reduce(0, +) / Double(count)
    }
}

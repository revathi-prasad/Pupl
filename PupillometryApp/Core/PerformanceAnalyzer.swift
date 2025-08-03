//
//  PerformanceAnalyzer.swift
//  PupillometryApp
//
//  Created by Revathi Prasad on 01/07/25.
//

import Foundation

class PerformanceAnalyzer {
    
    // MARK: - Data Structures
    
    struct GradCPTMetrics {
        let totalTrials: Int
        let targetTrials: Int
        let hits: Int
        let misses: Int
        let falseAlarms: Int
        let correctRejections: Int
        
        // Calculated metrics
        let hitRate: Double
        let falseAlarmRate: Double
        let missRate: Double
        let correctRejectionRate: Double
        let dprime: Double
        let criterion: Double
        let accuracy: Double
        
        // Reaction time metrics
        let meanReactionTime: Double
        let medianReactionTime: Double
        let reactionTimeSD: Double
        let validRTs: [Double]
        
        // Block-by-block analysis
        let blockAnalysis: [BlockMetrics]
    }
    
    struct MemoryTaskMetrics {
        let totalTrials: Int
        let correctResponses: Int
        let incorrectResponses: Int
        let accuracy: Double
        
        // Set size analysis
        let setSize4Accuracy: Double
        let setSize6Accuracy: Double
        let setSize8Accuracy: Double
        
        // Reaction time metrics
        let meanReactionTime: Double
        let medianReactionTime: Double
        let reactionTimeSD: Double
        
        // Working memory capacity estimate
        let kCapacity: Double // Cowan's K
        
        // Performance by trial
        let trialAnalysis: [MemoryTrialMetrics]
    }
    
    struct BlockMetrics {
        let blockNumber: Int
        let hits: Int
        let misses: Int
        let falseAlarms: Int
        let correctRejections: Int
        let dprime: Double
        let meanRT: Double
    }
    
    struct MemoryTrialMetrics {
        let trialNumber: Int
        let setSize: Int
        let correct: Bool
        let reactionTime: Double
    }
    
    struct ResponseData {
        let isTarget: Bool
        let responded: Bool
        let correct: Bool
        let reactionTime: Double?
        let timestamp: TimeInterval
        let trialNumber: Int
    }
    
    struct MemoryResponseData {
        let setSize: Int
        let correct: Bool
        let reactionTime: Double
        let trialNumber: Int
    }
    
    // MARK: - GradCPT Analysis
    
    static func analyzeGradCPTPerformance(responses: [ResponseData]) -> GradCPTMetrics {
        print("📊 PerformanceAnalyzer: Analyzing GradCPT performance for \(responses.count) trials")
        
        let targetTrials = responses.filter { $0.isTarget }
        let nonTargetTrials = responses.filter { !$0.isTarget }
        
        // Calculate hits, misses, false alarms, correct rejections
        let hits = targetTrials.filter { $0.responded && $0.correct }.count
        let misses = targetTrials.filter { !$0.responded }.count
        let falseAlarms = nonTargetTrials.filter { $0.responded }.count
        let correctRejections = nonTargetTrials.filter { !$0.responded }.count
        
        // Calculate rates
        let hitRate = Double(hits) / Double(targetTrials.count)
        let falseAlarmRate = Double(falseAlarms) / Double(nonTargetTrials.count)
        let missRate = Double(misses) / Double(targetTrials.count)
        let correctRejectionRate = Double(correctRejections) / Double(nonTargetTrials.count)
        
        // Calculate d-prime and criterion (signal detection theory)
        let dprime = calculateDPrime(hitRate: hitRate, falseAlarmRate: falseAlarmRate)
        let criterion = calculateCriterion(hitRate: hitRate, falseAlarmRate: falseAlarmRate)
        
        // Overall accuracy
        let accuracy = Double(hits + correctRejections) / Double(responses.count)
        
        // Reaction time analysis (only for responses)
        let validRTs = responses.compactMap { $0.reactionTime }.filter { $0 > 0.1 && $0 < 5.0 } // Filter extreme values
        let meanRT = validRTs.isEmpty ? 0.0 : validRTs.reduce(0, +) / Double(validRTs.count)
        let medianRT = validRTs.isEmpty ? 0.0 : validRTs.sorted()[validRTs.count / 2]
        let rtSD = calculateStandardDeviation(values: validRTs)
        
        // Block-by-block analysis (divide into 5 blocks)
        let blockAnalysis = analyzeGradCPTBlocks(responses: responses)
        
        print("✅ PerformanceAnalyzer: GradCPT Analysis complete - d': \(String(format: "%.3f", dprime)), Accuracy: \(String(format: "%.1f", accuracy * 100))%")
        
        return GradCPTMetrics(
            totalTrials: responses.count,
            targetTrials: targetTrials.count,
            hits: hits,
            misses: misses,
            falseAlarms: falseAlarms,
            correctRejections: correctRejections,
            hitRate: hitRate,
            falseAlarmRate: falseAlarmRate,
            missRate: missRate,
            correctRejectionRate: correctRejectionRate,
            dprime: dprime,
            criterion: criterion,
            accuracy: accuracy,
            meanReactionTime: meanRT,
            medianReactionTime: medianRT,
            reactionTimeSD: rtSD,
            validRTs: validRTs,
            blockAnalysis: blockAnalysis
        )
    }
    
    // MARK: - Memory Task Analysis
    
    static func analyzeMemoryTaskPerformance(responses: [MemoryResponseData]) -> MemoryTaskMetrics {
        print("📊 PerformanceAnalyzer: Analyzing Memory Task performance for \(responses.count) trials")
        
        let correctResponses = responses.filter { $0.correct }.count
        let accuracy = Double(correctResponses) / Double(responses.count)
        
        // Set size specific accuracy
        let setSize4Trials = responses.filter { $0.setSize == 4 }
        let setSize6Trials = responses.filter { $0.setSize == 6 }
        let setSize8Trials = responses.filter { $0.setSize == 8 }
        
        let setSize4Accuracy = setSize4Trials.isEmpty ? 0.0 : Double(setSize4Trials.filter { $0.correct }.count) / Double(setSize4Trials.count)
        let setSize6Accuracy = setSize6Trials.isEmpty ? 0.0 : Double(setSize6Trials.filter { $0.correct }.count) / Double(setSize6Trials.count)
        let setSize8Accuracy = setSize8Trials.isEmpty ? 0.0 : Double(setSize8Trials.filter { $0.correct }.count) / Double(setSize8Trials.count)
        
        // Reaction time analysis
        let reactionTimes = responses.map { $0.reactionTime }.filter { $0 > 0.1 && $0 < 10.0 }
        let meanRT = reactionTimes.isEmpty ? 0.0 : reactionTimes.reduce(0, +) / Double(reactionTimes.count)
        let medianRT = reactionTimes.isEmpty ? 0.0 : reactionTimes.sorted()[reactionTimes.count / 2]
        let rtSD = calculateStandardDeviation(values: reactionTimes)
        
        // Working memory capacity (Cowan's K)
        let kCapacity = calculateWorkingMemoryCapacity(responses: responses)
        
        // Trial-by-trial analysis
        let trialAnalysis = responses.map { response in
            MemoryTrialMetrics(
                trialNumber: response.trialNumber,
                setSize: response.setSize,
                correct: response.correct,
                reactionTime: response.reactionTime
            )
        }
        
        print("✅ PerformanceAnalyzer: Memory Task Analysis complete - Accuracy: \(String(format: "%.1f", accuracy * 100))%, K: \(String(format: "%.2f", kCapacity))")
        
        return MemoryTaskMetrics(
            totalTrials: responses.count,
            correctResponses: correctResponses,
            incorrectResponses: responses.count - correctResponses,
            accuracy: accuracy,
            setSize4Accuracy: setSize4Accuracy,
            setSize6Accuracy: setSize6Accuracy,
            setSize8Accuracy: setSize8Accuracy,
            meanReactionTime: meanRT,
            medianReactionTime: medianRT,
            reactionTimeSD: rtSD,
            kCapacity: kCapacity,
            trialAnalysis: trialAnalysis
        )
    }
    
    // MARK: - Signal Detection Theory Calculations
    
    private static func calculateDPrime(hitRate: Double, falseAlarmRate: Double) -> Double {
        // Correct for extreme values (0 and 1) using standard correction
        let correctedHitRate = max(0.01, min(0.99, hitRate))
        let correctedFARate = max(0.01, min(0.99, falseAlarmRate))
        
        let zHit = normalInverse(correctedHitRate)
        let zFA = normalInverse(correctedFARate)
        
        return zHit - zFA
    }
    
    private static func calculateCriterion(hitRate: Double, falseAlarmRate: Double) -> Double {
        let correctedHitRate = max(0.01, min(0.99, hitRate))
        let correctedFARate = max(0.01, min(0.99, falseAlarmRate))
        
        let zHit = normalInverse(correctedHitRate)
        let zFA = normalInverse(correctedFARate)
        
        return -(zHit + zFA) / 2.0
    }
    
    // Approximation of inverse normal distribution (z-score)
    private static func normalInverse(_ p: Double) -> Double {
        // Beasley-Springer-Moro algorithm approximation
        let a0 = 2.50662823884
        let a1 = -18.61500062529
        let a2 = 41.39119773534
        let a3 = -25.44106049637
        
        let b1 = -8.47351093090
        let b2 = 23.08336743743
        let b3 = -21.06224101826
        let b4 = 3.13082909833
        
        let c0 = 0.3374754822726147
        let c1 = 0.9761690190917186
        let c2 = 0.1607979714918209
        let c3 = 0.0276438810333863
        let c4 = 0.0038405729373609
        let c5 = 0.0003951896511919
        let c6 = 0.0000321767881768
        let c7 = 0.0000002888167364
        let c8 = 0.0000003960315187
        
        let y = p - 0.5
        
        if abs(y) < 0.42 {
            let r = y * y
            return y * (((a3 * r + a2) * r + a1) * r + a0) / ((((b4 * r + b3) * r + b2) * r + b1) * r + 1.0)
        }
        
        let r = p < 0.5 ? p : 1.0 - p
        let s = sqrt(-log(r))
        var t = c0 + s * (c1 + s * (c2 + s * (c3 + s * (c4 + s * (c5 + s * (c6 + s * (c7 + s * c8)))))))
        
        if p < 0.5 {
            t = -t
        }
        
        return t
    }
    
    // MARK: - Working Memory Capacity
    
    private static func calculateWorkingMemoryCapacity(responses: [MemoryResponseData]) -> Double {
        // Cowan's K formula: K = (hit rate - false alarm rate) × set size
        // For change detection: K = set size × (proportion correct - 1/number of alternatives)
        
        var totalK = 0.0
        var validSizes = 0
        
        for setSize in [4, 6, 8] {
            let setSizeResponses = responses.filter { $0.setSize == setSize }
            guard !setSizeResponses.isEmpty else { continue }
            
            let accuracy = Double(setSizeResponses.filter { $0.correct }.count) / Double(setSizeResponses.count)
            
            // For change detection with binary choice (changed/not changed)
            // K = set size × (proportion correct - 0.5) × 2
            let k = Double(setSize) * max(0, (accuracy - 0.5) * 2.0)
            
            totalK += k
            validSizes += 1
        }
        
        return validSizes > 0 ? totalK / Double(validSizes) : 0.0
    }
    
    // MARK: - Block Analysis
    
    private static func analyzeGradCPTBlocks(responses: [ResponseData]) -> [BlockMetrics] {
        let blockSize = responses.count / 5 // Divide into 5 blocks
        var blocks: [BlockMetrics] = []
        
        for blockIndex in 0..<5 {
            let startIndex = blockIndex * blockSize
            let endIndex = min((blockIndex + 1) * blockSize, responses.count)
            
            guard startIndex < endIndex else { continue }
            
            let blockResponses = Array(responses[startIndex..<endIndex])
            
            let targetTrials = blockResponses.filter { $0.isTarget }
            let nonTargetTrials = blockResponses.filter { !$0.isTarget }
            
            let hits = targetTrials.filter { $0.responded && $0.correct }.count
            let misses = targetTrials.filter { !$0.responded }.count
            let falseAlarms = nonTargetTrials.filter { $0.responded }.count
            let correctRejections = nonTargetTrials.filter { !$0.responded }.count
            
            let hitRate = targetTrials.isEmpty ? 0.0 : Double(hits) / Double(targetTrials.count)
            let falseAlarmRate = nonTargetTrials.isEmpty ? 0.0 : Double(falseAlarms) / Double(nonTargetTrials.count)
            
            let dprime = calculateDPrime(hitRate: hitRate, falseAlarmRate: falseAlarmRate)
            
            let blockRTs = blockResponses.compactMap { $0.reactionTime }.filter { $0 > 0.1 && $0 < 5.0 }
            let meanRT = blockRTs.isEmpty ? 0.0 : blockRTs.reduce(0, +) / Double(blockRTs.count)
            
            let blockMetrics = BlockMetrics(
                blockNumber: blockIndex + 1,
                hits: hits,
                misses: misses,
                falseAlarms: falseAlarms,
                correctRejections: correctRejections,
                dprime: dprime,
                meanRT: meanRT
            )
            
            blocks.append(blockMetrics)
        }
        
        return blocks
    }
    
    // MARK: - Statistical Utilities
    
    private static func calculateStandardDeviation(values: [Double]) -> Double {
        guard values.count > 1 else { return 0.0 }
        
        let mean = values.reduce(0, +) / Double(values.count)
        let squaredDifferences = values.map { pow($0 - mean, 2) }
        let variance = squaredDifferences.reduce(0, +) / Double(values.count - 1)
        
        return sqrt(variance)
    }
    
    // MARK: - Export Formatting
    
    static func formatMetricsForExport(gradCPTMetrics: GradCPTMetrics?, memoryMetrics: MemoryTaskMetrics?) -> String {
        var report = "# PupillometryApp Performance Report\n"
        report += "Generated: \(Date())\n\n"
        
        if let gradCPT = gradCPTMetrics {
            report += "## GradCPT Task Results\n"
            report += "- **Total Trials:** \(gradCPT.totalTrials)\n"
            report += "- **Target Trials:** \(gradCPT.targetTrials)\n"
            report += "- **Overall Accuracy:** \(String(format: "%.1f", gradCPT.accuracy * 100))%\n"
            report += "- **d-prime:** \(String(format: "%.3f", gradCPT.dprime))\n"
            report += "- **Hit Rate:** \(String(format: "%.3f", gradCPT.hitRate))\n"
            report += "- **False Alarm Rate:** \(String(format: "%.3f", gradCPT.falseAlarmRate))\n"
            report += "- **Mean Reaction Time:** \(String(format: "%.3f", gradCPT.meanReactionTime))s\n"
            report += "- **RT Standard Deviation:** \(String(format: "%.3f", gradCPT.reactionTimeSD))s\n\n"
            
            report += "### Block Analysis\n"
            for block in gradCPT.blockAnalysis {
                report += "Block \(block.blockNumber): d'=\(String(format: "%.3f", block.dprime)), RT=\(String(format: "%.3f", block.meanRT))s\n"
            }
            report += "\n"
        }
        
        if let memory = memoryMetrics {
            report += "## Memory Task Results\n"
            report += "- **Total Trials:** \(memory.totalTrials)\n"
            report += "- **Overall Accuracy:** \(String(format: "%.1f", memory.accuracy * 100))%\n"
            report += "- **Working Memory Capacity (K):** \(String(format: "%.2f", memory.kCapacity))\n"
            report += "- **Mean Reaction Time:** \(String(format: "%.3f", memory.meanReactionTime))s\n\n"
            
            report += "### Accuracy by Set Size\n"
            report += "- **Set Size 4:** \(String(format: "%.1f", memory.setSize4Accuracy * 100))%\n"
            report += "- **Set Size 6:** \(String(format: "%.1f", memory.setSize6Accuracy * 100))%\n"
            report += "- **Set Size 8:** \(String(format: "%.1f", memory.setSize8Accuracy * 100))%\n\n"
        }
        
        return report
    }
}
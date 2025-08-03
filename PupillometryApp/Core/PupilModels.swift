//  PupillometryApp
//
//  Created by Revathi Prasad on 08/06/25.
//


import Foundation
import CoreGraphics
import QuartzCore

// MARK: - Data Models

// Enhanced facial landmark data
struct FacialLandmarks {
    let timestamp: TimeInterval
    let faceRect: CGRect
    let faceConfidence: Float
    
    // Eye landmarks (MediaPipe format)
    let leftEyeLandmarks: [CGPoint]   // 16 points around left eye
    let rightEyeLandmarks: [CGPoint]  // 16 points around right eye
    let leftIrisLandmarks: [CGPoint]  // 5 points for left iris
    let rightIrisLandmarks: [CGPoint] // 5 points for right iris
    
    // Additional facial features
    let noseLandmarks: [CGPoint]      // Nose bridge and tip
    let mouthLandmarks: [CGPoint]     // Mouth corners and outline
    let jawlineLandmarks: [CGPoint]   // Face contour
    let eyebrowLandmarks: [CGPoint]   // Eyebrow shape
    
    // Head pose estimation
    let headPose: HeadPose
    
    struct HeadPose {
        let pitch: Float  // Up/down rotation
        let yaw: Float    // Left/right rotation  
        let roll: Float   // Tilt rotation
    }
}

// Enhanced measurement with landmark data
struct PupilMeasurement {
    let timestamp: TimeInterval
    let center: CGPoint
    let radiusPixels: Float
    let diameterMM: Float
    let confidence: Float
    let eye: Eye
    
    // NEW: Associated landmark data
    let facialLandmarks: FacialLandmarks?
    let associatedImageFilename: String?  // Reference to saved image
    
    // NEW: Content type tracking for dashboard filtering
    let contentType: ContentType
    let taskPhase: String?  // Additional phase information (e.g., "trial_1", "video_timestamp_30s")
    let videoTimestamp: TimeInterval?  // For YouTube video correlation
    
    // MOBILE ENHANCEMENT: Pupil-corner vector for better mobile tracking
    let eyeCornerInner: CGPoint?  // Inner corner of eye
    let eyeCornerOuter: CGPoint?  // Outer corner of eye
    let pupilToInnerVector: CGVector?  // Vector from pupil to inner corner
    let pupilToOuterVector: CGVector?  // Vector from pupil to outer corner
    
    enum Eye: String {
        case left, right
    }
    
    // Factory method for creating mock measurements (for testing)
    static func createMock(timestamp: TimeInterval = CACurrentMediaTime(),
                         center: CGPoint = CGPoint(x: 200, y: 200),
                         radiusPixels: Float = 25.0,
                         diameterMM: Float = 4.5,
                         confidence: Float = 0.8,
                         eye: Eye = .right,
                         contentType: ContentType = .calibration) -> PupilMeasurement {
        
        return PupilMeasurement(
            timestamp: timestamp,
            center: center,
            radiusPixels: radiusPixels,
            diameterMM: diameterMM,
            confidence: confidence,
            eye: eye,
            facialLandmarks: nil,
            associatedImageFilename: nil,
            contentType: contentType,
            taskPhase: nil,
            videoTimestamp: nil,
            eyeCornerInner: nil,
            eyeCornerOuter: nil,
            pupilToInnerVector: nil,
            pupilToOuterVector: nil
        )
    }
}

struct StereovisionMeasurement {
    let disparity: Float
    let distanceMM: Float
    let calibrationFactor: Float
}

struct CalibrationResult {
    let isValid: Bool
    let accuracy: Double  // 0.0 to 1.0
    let dataPointsCollected: Int
    let averageResponseTime: Double
    let rmsError: Double  // Root mean square error in degrees
    let validationPoints: [CalibrationPoint]
    
    struct CalibrationPoint {
        let targetPosition: CGPoint
        let gazePosition: CGPoint
        let error: Double  // Distance error in degrees
        let confidence: Double
    }
}

// MARK: - Content Type Tracking System
// Enhanced content type tracking for YouTube video integration and phase analysis
enum ContentType: String, CaseIterable, Codable {
    case calibration = "calibration"
    case gradcpt = "gradcpt" 
    case memory = "memory"
    case youtubeVideo1 = "youtube_video_1"
    case youtubeVideo2 = "youtube_video_2"
    case youtubeVideo3 = "youtube_video_3"
    case youtubeVideo4 = "youtube_video_4"
    case baseline = "baseline"
    
    // Display names for UI
    var displayName: String {
        switch self {
        case .calibration: return "🎯 Calibration"
        case .gradcpt: return "🧠 Attention Task (GradCPT)"
        case .memory: return "💭 Memory Assessment"
        case .youtubeVideo1: return "📺 YouTube Ad Video 1"
        case .youtubeVideo2: return "📺 YouTube Ad Video 2"
        case .youtubeVideo3: return "📺 YouTube Ad Video 3"
        case .youtubeVideo4: return "📺 YouTube Ad Video 4"
        case .baseline: return "📊 Baseline"
        }
    }
    
    // Dashboard phase mapping for compatibility
    var dashboardPhase: String {
        switch self {
        case .calibration: return "Calibration"
        case .gradcpt: return "Cognitive Task"
        case .memory: return "Memory Assessment"
        case .youtubeVideo1, .youtubeVideo2, .youtubeVideo3, .youtubeVideo4: return "Video Content"
        case .baseline: return "Baseline"
        }
    }
}

// MARK: - Pathway Type for Clinical vs Consumer Assessment
enum PathwayType: String, CaseIterable, Codable {
    case clinical = "clinical"
    case consumer = "consumer"
    
    var displayName: String {
        switch self {
        case .clinical:
            return "Clinical Assessment"
        case .consumer:
            return "Personal Insights"
        }
    }
    
    var description: String {
        switch self {
        case .clinical:
            return "Comprehensive cognitive assessment with detailed clinical metrics"
        case .consumer:
            return "Personal attention insights and focus metrics"
        }
    }
}

struct TaskEvent {
    let timestamp: TimeInterval
    let type: EventType
    let data: [String: Any]
    let contentType: ContentType  // NEW: Track what content was being viewed
    
    enum EventType: String {
        case stimulusOnset
        case stimulusOffset
        case response
        case trialStart
        case trialEnd
        // NEW: Task-level events for ADHD detection model scope
        case taskStart
        case taskEnd
        // NEW: Video-specific events
        case videoStart
        case videoEnd
        case videoPause
        case videoResume
        case contentTypeChange
    }
}

struct ADHDFeatures {
    // Tonic measurements
    let tonicStartMM: Float
    let tonicEndMM: Float
    let baselineStability: Float
    
    // Phasic measurements
    let maxPhasicAttention: Float
    let maxPhasicMemory: Float
    let phasicRange: Float
    let timeToPeak: TimeInterval
    
    // Temporal dynamics (basic)
    let velocityProfile: [Float]
    let accelerationTrend: [Float]
    let totalDistance: Float
    
    // NEW: Advanced velocity/acceleration features (match Python training)
    let maxVelocity: Float          // MaxV - maximum velocity magnitude
    let totalVelocity: Float        // TotalV - sum of absolute velocities
    let maxAcceleration: Float      // MaxA - maximum acceleration magnitude  
    let totalAcceleration: Float    // TotalA - sum of absolute accelerations
    let velocityTimeSeries: [Float] // 2000-point velocity time series
    let accelerationTimeSeries: [Float] // 2000-point acceleration time series
    
    // NEW: Peak detection features
    let peakCount: Int              // Number of significant peaks
    let averagePeakHeight: Float    // Mean peak amplitude
    let peakLatencies: [TimeInterval] // Timing of peaks
    let dominantPeakLatency: TimeInterval // Primary attention peak timing
    
    // NEW: Entropy and complexity measures
    let pupilEntropy: Float         // Shannon entropy of pupil distribution
    let sustainedDilationIndex: Float // Measure of sustained attention
    let variabilityIndex: Float     // Coefficient of variation
    let complexityScore: Float      // Overall complexity measure
    
    // NEW: Phase-specific features (attention vs memory phases)
    let attentionMaxV: Float        // Max velocity during attention phase (0-5s)
    let attentionTotalV: Float      // Total velocity during attention phase
    let memoryMaxV: Float          // Max velocity during memory phase (5-8s)
    let memoryTotalV: Float        // Total velocity during memory phase
    let phaseTransitionIndex: Float // Measure of phase transition dynamics
    
    // NEW: Frequency domain features
    let dominantFrequency: Float    // Primary oscillation frequency
    let powerSpectralDensity: [Float] // PSD for different frequency bands
    let alphaBandPower: Float       // Power in alpha band (8-12 Hz equivalent)
    
    // Behavioral (existing)
    let reactionTime: TimeInterval
    let accuracy: Float
    let processingSpeed: Float
    
    // NEW: Trial quality metrics
    let dataQualityScore: Float     // Overall data quality (0-1)
    let confidenceScore: Float      // Model confidence in features
}

// MARK: - ADHD Protocol Models (Sternberg Task)

struct ADHDProtocolResponse {
    let trialNumber: Int
    let blockNumber: Int
    let isTarget: Bool          // Was probe dot in memory array?
    let userResponse: Bool      // Did user tap "Yes"?
    let isCorrect: Bool         // Was response correct?
    let reactionTime: TimeInterval
    let loadCondition: LoadCondition  // Low (1 dot) or High (2 dots) per array
    let distractorType: DistractorType
    let timestamp: TimeInterval
    
    enum LoadCondition: String, CaseIterable, Codable {
        case low = "low"     // 1 dot per array (3 total dots to remember)
        case high = "high"   // 2 dots per array (6 total dots to remember)
    }
    
    enum DistractorType: String, CaseIterable, Codable {
        case none = "none"
        case taskRelated = "task"
        case neutral = "neutral"
        case emotional = "emotional"
    }
}

struct ADHDTrialData {
    let trialNumber: Int
    let blockNumber: Int
    let startTime: TimeInterval
    let endTime: TimeInterval
    let pupilSamples: [Float]        // 240 samples (8s × 30fps)
    let sampleTimestamps: [TimeInterval]  // Corresponding timestamps
    let dotArrays: [[CGPoint]]       // 3 arrays of dot positions
    let probePosition: CGPoint       // Position of probe dot
    let loadCondition: ADHDProtocolResponse.LoadCondition
    let distractorType: ADHDProtocolResponse.DistractorType
    let isValidTrial: Bool           // False if too many missing samples/anomalies
    let qualityMetrics: TrialQualityMetrics
    
    struct TrialQualityMetrics {
        let missingSampleCount: Int
        let interpolatedSampleCount: Int
        let anomalyCount: Int
        let averageConfidence: Float
        let dataQualityScore: Float  // 0.0-1.0, higher is better
    }
}

// MARK: - Session Management
class SessionData {
    let sessionID: String = UUID().uuidString
    let startTime: Date = Date()
    var pupilMeasurements: [PupilMeasurement] = []
    var taskEvents: [TaskEvent] = []
    var demographicData: DemographicData?
    
    // NEW: Pathway type tracking for clinical vs consumer
    var pathwayType: PathwayType = .consumer  // Default to consumer pathway
    
    // Enhanced performance tracking
    var gradCPTResponses: [PerformanceAnalyzer.ResponseData] = []
    var memoryTaskResponses: [PerformanceAnalyzer.MemoryResponseData] = []
    var performanceMetrics: PerformanceMetrics?
    
    // NEW: ADHD Protocol data (replaces GradCPT + Memory for clinical pathway)
    var adhdProtocolResponses: [ADHDProtocolResponse] = []
    var adhdTrialData: [ADHDTrialData] = []
    
    // NEW: Image and landmark data
    var capturedImages: [CapturedImage] = []
    var facialLandmarksData: [FacialLandmarks] = []
    
    // NEW: Comprehensive guardrail data
    var guardrailData: GuardrailDataExport?
    
    // NEW: Metadata dictionary for storing additional analysis results
    var metadata: [String: Any] = [:]
    
    
    struct CapturedImage {
        let timestamp: TimeInterval
        let filename: String        // e.g., "img_1625097600.123.jpg"
        let imageData: Data         // Raw JPEG data
        let frameNumber: Int        // Sequential frame counter
        let cameraPosition: String  // "front" or "back"
        let imageSize: CGSize       // Original image dimensions
        let eyeRegionData: Data?    // NEW: Extracted eye region JPEG
        let eyeRegionRect: CGRect   // NEW: Eye region coordinates in full image
        let faceRect: CGRect        // NEW: Face detection rectangle
    }
    
    struct DemographicData: Codable {
        let age: Int
        let gender: String
        let previousDiagnosis: String?
        let medications: String?
    }
    
    struct PerformanceMetrics: Codable {
        let gradCPTMetrics: GradCPTMetricsData?
        let memoryTaskMetrics: MemoryTaskMetricsData?
        let analysisDate: Date
        
        // Simplified metrics structures for Codable compliance
        struct GradCPTMetricsData: Codable {
            let totalTrials: Int
            let targetTrials: Int
            let hits: Int
            let misses: Int
            let falseAlarms: Int
            let correctRejections: Int
            let hitRate: Double
            let falseAlarmRate: Double
            let dprime: Double
            let criterion: Double
            let accuracy: Double
            let meanReactionTime: Double
            let medianReactionTime: Double
            let reactionTimeSD: Double
        }
        
        struct MemoryTaskMetricsData: Codable {
            let totalTrials: Int
            let correctResponses: Int
            let accuracy: Double
            let setSize4Accuracy: Double
            let setSize6Accuracy: Double
            let setSize8Accuracy: Double
            let meanReactionTime: Double
            let medianReactionTime: Double
            let reactionTimeSD: Double
            let kCapacity: Double
        }
    }
    
    // MARK: - Performance Analysis Methods
    
    func calculatePerformanceMetrics() {
        print("📊 SessionData: Calculating performance metrics...")
        
        var gradCPTMetrics: PerformanceAnalyzer.GradCPTMetrics?
        var memoryMetrics: PerformanceAnalyzer.MemoryTaskMetrics?
        
        // Analyze GradCPT performance if data exists
        if !gradCPTResponses.isEmpty {
            gradCPTMetrics = PerformanceAnalyzer.analyzeGradCPTPerformance(responses: gradCPTResponses)
        }
        
        // Analyze Memory Task performance if data exists
        if !memoryTaskResponses.isEmpty {
            memoryMetrics = PerformanceAnalyzer.analyzeMemoryTaskPerformance(responses: memoryTaskResponses)
        }
        
        // Convert to Codable format
        let gradCPTData = gradCPTMetrics.map { metrics in
            PerformanceMetrics.GradCPTMetricsData(
                totalTrials: metrics.totalTrials,
                targetTrials: metrics.targetTrials,
                hits: metrics.hits,
                misses: metrics.misses,
                falseAlarms: metrics.falseAlarms,
                correctRejections: metrics.correctRejections,
                hitRate: metrics.hitRate,
                falseAlarmRate: metrics.falseAlarmRate,
                dprime: metrics.dprime,
                criterion: metrics.criterion,
                accuracy: metrics.accuracy,
                meanReactionTime: metrics.meanReactionTime,
                medianReactionTime: metrics.medianReactionTime,
                reactionTimeSD: metrics.reactionTimeSD
            )
        }
        
        let memoryData = memoryMetrics.map { metrics in
            PerformanceMetrics.MemoryTaskMetricsData(
                totalTrials: metrics.totalTrials,
                correctResponses: metrics.correctResponses,
                accuracy: metrics.accuracy,
                setSize4Accuracy: metrics.setSize4Accuracy,
                setSize6Accuracy: metrics.setSize6Accuracy,
                setSize8Accuracy: metrics.setSize8Accuracy,
                meanReactionTime: metrics.meanReactionTime,
                medianReactionTime: metrics.medianReactionTime,
                reactionTimeSD: metrics.reactionTimeSD,
                kCapacity: metrics.kCapacity
            )
        }
        
        performanceMetrics = PerformanceMetrics(
            gradCPTMetrics: gradCPTData,
            memoryTaskMetrics: memoryData,
            analysisDate: Date()
        )
        
        print("✅ SessionData: Performance metrics calculated successfully")
    }
    
    func addGradCPTResponse(isTarget: Bool, responded: Bool, correct: Bool, reactionTime: Double?, trialNumber: Int) {
        let response = PerformanceAnalyzer.ResponseData(
            isTarget: isTarget,
            responded: responded,
            correct: correct,
            reactionTime: reactionTime,
            timestamp: CACurrentMediaTime(),
            trialNumber: trialNumber
        )
        gradCPTResponses.append(response)
        print("📝 SessionData: Added GradCPT response - Trial \(trialNumber), Target: \(isTarget), Correct: \(correct)")
    }
    
    func addMemoryTaskResponse(setSize: Int, correct: Bool, reactionTime: Double, trialNumber: Int) {
        let response = PerformanceAnalyzer.MemoryResponseData(
            setSize: setSize,
            correct: correct,
            reactionTime: reactionTime,
            trialNumber: trialNumber
        )
        memoryTaskResponses.append(response)
        print("📝 SessionData: Added Memory Task response - Trial \(trialNumber), Set Size: \(setSize), Correct: \(correct)")
    }
    
    // MARK: - ADHD Protocol Methods
    
    func addADHDProtocolResponse(_ response: ADHDProtocolResponse) {
        adhdProtocolResponses.append(response)
        print("📝 SessionData: Added ADHD Protocol response - Block \(response.blockNumber), Trial \(response.trialNumber), Correct: \(response.isCorrect)")
    }
    
    func addADHDTrialData(_ trialData: ADHDTrialData) {
        adhdTrialData.append(trialData)
        print("📝 SessionData: Added ADHD Trial data - Block \(trialData.blockNumber), Trial \(trialData.trialNumber), Samples: \(trialData.pupilSamples.count), Quality: \(trialData.qualityMetrics.dataQualityScore)")
    }
    
    func getValidADHDTrials() -> [ADHDTrialData] {
        return adhdTrialData.filter { $0.isValidTrial }
    }
    
    func calculateADHDDataQuality() -> (validTrials: Int, totalTrials: Int, averageQuality: Float) {
        let validTrials = getValidADHDTrials()
        let totalTrials = adhdTrialData.count
        let averageQuality = totalTrials > 0 ? 
            adhdTrialData.reduce(0) { $0 + $1.qualityMetrics.dataQualityScore } / Float(totalTrials) : 0.0
        
        return (validTrials: validTrials.count, totalTrials: totalTrials, averageQuality: averageQuality)
    }
    
    func generatePerformanceReport() -> String {
        let gradCPTMetrics = gradCPTResponses.isEmpty ? nil : PerformanceAnalyzer.analyzeGradCPTPerformance(responses: gradCPTResponses)
        let memoryMetrics = memoryTaskResponses.isEmpty ? nil : PerformanceAnalyzer.analyzeMemoryTaskPerformance(responses: memoryTaskResponses)
        
        return PerformanceAnalyzer.formatMetricsForExport(gradCPTMetrics: gradCPTMetrics, memoryMetrics: memoryMetrics)
    }
    
}

// MARK: - Polynomial Gaze Mapping

class PolynomialGazeMapper {
    // 2nd-order polynomial coefficients: 6 for x-axis, 6 for y-axis
    private var coefficients: [Double] = Array(repeating: 0.0, count: 12)
    private var isCalibrated = false
    
    private struct CalibrationData {
        let pupilPosition: CGPoint
        let screenPosition: CGPoint
        let confidence: Double
    }
    
    func train(calibrationData: [(pupilPos: CGPoint, screenPos: CGPoint, confidence: Double)]) {
        guard calibrationData.count >= 6 else {
            print("⚠️ PolynomialGazeMapper: Need at least 6 calibration points for 2nd-order polynomial")
            return
        }
        
        print("🎯 PolynomialGazeMapper: Training with \(calibrationData.count) points")
        
        // Build design matrix A and target vectors bx, by
        let designMatrix = buildDesignMatrix(calibrationData.map { $0.pupilPos })
        let screenX = calibrationData.map { Double($0.screenPos.x) }
        let screenY = calibrationData.map { Double($0.screenPos.y) }
        
        // Solve least squares for both x and y coordinates
        guard let coeffsX = solveLeastSquares(designMatrix, screenX),
              let coeffsY = solveLeastSquares(designMatrix, screenY) else {
            print("❌ PolynomialGazeMapper: Failed to solve least squares")
            return
        }
        
        // Store coefficients: [a0, a1, a2, a3, a4, a5, b0, b1, b2, b3, b4, b5]
        coefficients = Array(coeffsX + coeffsY)
        isCalibrated = true
        
        print("✅ PolynomialGazeMapper: Training completed successfully")
        print("📊 Coefficients X: \(coeffsX.map { String(format: "%.4f", $0) })")
        print("📊 Coefficients Y: \(coeffsY.map { String(format: "%.4f", $0) })")
        
        // Validate training accuracy
        validateTraining(calibrationData)
    }
    
    func train(calibrationData: [(pupilPos: CGPoint, screenPos: CGPoint)]) {
        let dataWithDefaultConfidence = calibrationData.map { (pupilPos: $0.pupilPos, screenPos: $0.screenPos, confidence: 1.0) }
        train(calibrationData: dataWithDefaultConfidence)
    }
    
    func mapGaze(pupilPosition: CGPoint) -> CGPoint {
        guard isCalibrated else {
            print("⚠️ PolynomialGazeMapper: Not calibrated, returning pupil position")
            return pupilPosition
        }
        
        let x = Double(pupilPosition.x)
        let y = Double(pupilPosition.y)
        
        // 2nd-order polynomial mapping:
        // screen_x = a0 + a1*x + a2*y + a3*x² + a4*x*y + a5*y²
        // screen_y = b0 + b1*x + b2*y + b3*x² + b4*x*y + b5*y²
        
        let screenX = coefficients[0] + coefficients[1]*x + coefficients[2]*y + 
                     coefficients[3]*x*x + coefficients[4]*x*y + coefficients[5]*y*y
        
        let screenY = coefficients[6] + coefficients[7]*x + coefficients[8]*y + 
                     coefficients[9]*x*x + coefficients[10]*x*y + coefficients[11]*y*y
        
        return CGPoint(x: screenX, y: screenY)
    }
    
    private func buildDesignMatrix(_ pupilPositions: [CGPoint]) -> [[Double]] {
        var matrix: [[Double]] = []
        
        for point in pupilPositions {
            let x = Double(point.x)
            let y = Double(point.y)
            
            // Each row: [1, x, y, x², x*y, y²]
            let row = [1.0, x, y, x*x, x*y, y*y]
            matrix.append(row)
        }
        
        return matrix
    }
    
    private func solveLeastSquares(_ A: [[Double]], _ b: [Double]) -> [Double]? {
        guard A.count == b.count, !A.isEmpty else { return nil }
        
        let m = A.count    // number of equations
        let n = A[0].count // number of unknowns
        
        guard m >= n else { return nil }
        
        // Solve normal equations: A^T * A * x = A^T * b
        let AT = transpose(A)
        let ATA = multiply(AT, A)
        let ATb = multiplyVector(AT, b)
        
        // Solve using Gaussian elimination
        return gaussianElimination(ATA, ATb)
    }
    
    private func transpose(_ matrix: [[Double]]) -> [[Double]] {
        guard !matrix.isEmpty else { return [] }
        
        let rows = matrix.count
        let cols = matrix[0].count
        var result = Array(repeating: Array(repeating: 0.0, count: rows), count: cols)
        
        for i in 0..<rows {
            for j in 0..<cols {
                result[j][i] = matrix[i][j]
            }
        }
        
        return result
    }
    
    private func multiply(_ A: [[Double]], _ B: [[Double]]) -> [[Double]] {
        guard !A.isEmpty, !B.isEmpty, A[0].count == B.count else { return [] }
        
        let m = A.count
        let n = B[0].count
        let p = A[0].count
        
        var result = Array(repeating: Array(repeating: 0.0, count: n), count: m)
        
        for i in 0..<m {
            for j in 0..<n {
                for k in 0..<p {
                    result[i][j] += A[i][k] * B[k][j]
                }
            }
        }
        
        return result
    }
    
    private func multiplyVector(_ A: [[Double]], _ b: [Double]) -> [Double] {
        guard !A.isEmpty, A[0].count == b.count else { return [] }
        
        let m = A.count
        var result = Array(repeating: 0.0, count: m)
        
        for i in 0..<m {
            for j in 0..<A[0].count {
                result[i] += A[i][j] * b[j]
            }
        }
        
        return result
    }
    
    private func gaussianElimination(_ A: [[Double]], _ b: [Double]) -> [Double]? {
        guard A.count == b.count, !A.isEmpty else { return nil }
        
        let n = A.count
        var augmented = A
        let rhs = b
        
        // Add right-hand side as last column
        for i in 0..<n {
            augmented[i].append(rhs[i])
        }
        
        // Forward elimination
        for i in 0..<n {
            // Find pivot
            var maxRow = i
            for k in i+1..<n {
                if abs(augmented[k][i]) > abs(augmented[maxRow][i]) {
                    maxRow = k
                }
            }
            
            // Swap rows
            if maxRow != i {
                augmented.swapAt(i, maxRow)
            }
            
            // Check for singular matrix
            if abs(augmented[i][i]) < 1e-10 {
                print("⚠️ PolynomialGazeMapper: Matrix is singular or nearly singular")
                return nil
            }
            
            // Eliminate column
            for k in i+1..<n {
                let factor = augmented[k][i] / augmented[i][i]
                for j in i..<n+1 {
                    augmented[k][j] -= factor * augmented[i][j]
                }
            }
        }
        
        // Back substitution
        var x = Array(repeating: 0.0, count: n)
        for i in (0..<n).reversed() {
            x[i] = augmented[i][n]
            for j in i+1..<n {
                x[i] -= augmented[i][j] * x[j]
            }
            x[i] /= augmented[i][i]
        }
        
        return x
    }
    
    private func validateTraining(_ calibrationData: [(pupilPos: CGPoint, screenPos: CGPoint, confidence: Double)]) {
        var totalError = 0.0
        var maxError = 0.0
        
        for data in calibrationData {
            let predicted = mapGaze(pupilPosition: data.pupilPos)
            let actual = data.screenPos
            
            let error = sqrt(pow(predicted.x - actual.x, 2) + pow(predicted.y - actual.y, 2))
            totalError += error
            maxError = max(maxError, error)
        }
        
        let meanError = totalError / Double(calibrationData.count)
        let meanErrorDegrees = meanError / 17.0 // Convert pixels to degrees (approximate)
        
        print("📊 PolynomialGazeMapper Validation:")
        print("   - Mean Error: \(String(format: "%.2f", meanError)) pixels (\(String(format: "%.2f", meanErrorDegrees))°)")
        print("   - Max Error: \(String(format: "%.2f", maxError)) pixels (\(String(format: "%.2f", maxError/17.0))°)")
        print("   - Expected Range: 0.99-1.23° (research target)")
    }
    
    func getCalibrationQuality() -> Double {
        return isCalibrated ? 1.0 : 0.0
    }
    
    func reset() {
        coefficients = Array(repeating: 0.0, count: 12)
        isCalibrated = false
        print("🔄 PolynomialGazeMapper: Reset coefficients")
    }
}

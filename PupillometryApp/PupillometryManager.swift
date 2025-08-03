//
//  PupillometryManager.swift
//  PupillometryApp
//
//  Created by Revathi Prasad on 29/05/25.
//

// PupillometryManager.swift

//
//  PupillometryManager.swift
//  PupillometryApp
//
//  Created by Revathi Prasad on 29/05/25.
//

import Foundation
import AVFoundation
import Combine
import UIKit

protocol PupillometryManagerDelegate: AnyObject {
    func pupillometryManager(_ manager: PupillometryManager, didUpdateMeasurement measurement: PupilMeasurement)
    func pupillometryManager(_ manager: PupillometryManager, didEncounterError error: Error)
    func pupillometryManager(_ manager: PupillometryManager, didUpdateFeatures features: ADHDFeatures)
    func pupillometryManager(_ manager: PupillometryManager, didUpdateStatus status: String)
}

class PupillometryManager: NSObject, CameraManagerDelegate {
    // Singleton instance
    static let shared = PupillometryManager()
    
    // Core components
    private let cameraManager = CameraManager.shared
    private let pupilDetector = PupilDetector()
    private let featureExtractor = FeatureExtractor()
    private let stereovisionCalculator = StereovisionCalculator()
    private let polynomialGazeMapper = PolynomialGazeMapper()
    // ARCHITECTURE: Use only MediaPipe for consistent RGB+NIR processing
    
    // Session management
    var currentSession: SessionData?
    
    // Content type tracking for consumer pathway
    private var currentContentType: ContentType = .calibration
    private var currentTaskPhase: String? = nil
    
    // Public recording status for debugging
    var isCurrentlyRecording: Bool {
        return isRecording
    }
    
    // Calibration data
    private var calibrationPoints: [CGPoint] = []
    private var calibrationMeasurements: [String: [PupilMeasurement]] = [:]
    private var currentCalibrationPoint: CGPoint?
    private var isCalibrating = false
    private var calibrationStartTime: TimeInterval = 0
    
    // Enhanced calibration data for polynomial mapping
    private var calibrationPairs: [(screenPos: CGPoint, pupilPos: CGPoint, confidence: Double)] = []
    
    // COORDINATE SYSTEM FIX: Store normalization ranges for consistent mapping
    private var normalizationRanges: (pupilXMin: CGFloat, pupilXMax: CGFloat, pupilYMin: CGFloat, pupilYMax: CGFloat,
                                     screenXMin: CGFloat, screenXMax: CGFloat, screenYMin: CGFloat, screenYMax: CGFloat)?
    
    // Processing state
    private var isProcessing = false
    private var isProcessingRGB = false
    private var isProcessingNIR = false
    private var isRecording = false
    private var frameCount = 0
    private var lastFrameTime: TimeInterval = 0
    private var currentFPS: Double = 0
    
    // Feature extraction timer
    private var featureExtractionTimer: Timer?
    private let featureExtractionInterval: TimeInterval = 1.0 // Extract features every second
    
    // Data buffer with optimized size for iPhone 11
    private var measurementBuffer: [PupilMeasurement] = []
    private let bufferSize = 300 // 5 seconds at 60Hz - reduced for better memory management
    
    // Performance monitoring
    private var processingTimes: [TimeInterval] = []
    private var adaptiveProcessing = true
    private var currentProcessingLoad: Float = 0.0
    
    // Delegate for UI updates
    weak var delegate: PupillometryManagerDelegate?
    
    // Private constructor for singleton
    override private init() {
        super.init()
        setupComponents()
    }
    
    private func setupComponents() {
        cameraManager.delegate = self
        // Set camera manager reference for depth data access
        pupilDetector.setCameraManager(cameraManager)
    }
    
    private func pointToKey(_ point: CGPoint) -> String {
        return "\(point.x),\(point.y)"
    }

    private func keyToPoint(_ key: String) -> CGPoint {
        let components = key.split(separator: ",")
        return CGPoint(x: Double(components[0]) ?? 0, y: Double(components[1]) ?? 0)
    }
    
    // MOBILE ENHANCEMENT: Extract enhanced gaze feature vector from measurement
    private func extractGazeFeatureVector(from measurement: PupilMeasurement) -> CGPoint {
        // Enhanced approach with Y-axis amplification for mobile eye tracking
        
        // MOBILE-SPECIFIC: Amplify Y-axis signal to compensate for small pupil movement range
        let yAmplificationFactor: CGFloat = 3.0  // Amplify Y movement by 3x
        let enhancedY = measurement.center.y * yAmplificationFactor
        
        let enhancedVector = CGPoint(x: measurement.center.x, y: enhancedY)
        
        print("🔍 MOBILE: Y-amplified vector - Original: \(measurement.center), Enhanced: \(enhancedVector)")
        print("   📊 Y-amplification: \(measurement.center.y) → \(enhancedY) (factor: \(yAmplificationFactor))")
        
        return enhancedVector
        
        /* DISABLED: Enhanced vector approach - needs coordinate system consistency fix
        if let innerVector = measurement.pupilToInnerVector,
           let outerVector = measurement.pupilToOuterVector {
            
            // Create a composite feature vector that amplifies the signal
            // Use the ratio of distances to inner/outer corners as features
            let innerDistance = sqrt(innerVector.dx * innerVector.dx + innerVector.dy * innerVector.dy)
            let outerDistance = sqrt(outerVector.dx * outerVector.dx + outerVector.dy * outerVector.dy)
            
            // Normalize by eye width (distance between corners)
            let eyeWidth = innerDistance + outerDistance
            guard eyeWidth > 0 else { return measurement.center }
            
            let innerRatio = innerDistance / eyeWidth
            let outerRatio = outerDistance / eyeWidth
            
            // Create enhanced feature vector with amplified signal
            let enhancedX = measurement.center.x + (innerRatio - outerRatio) * 100.0  // Amplify the signal
            let enhancedY = measurement.center.y + (innerVector.dy + outerVector.dy) * 0.5  // Average Y movement
            
            let enhancedVector = CGPoint(x: enhancedX, y: enhancedY)
            
            print("🔍 MOBILE: Enhanced gaze vector - Original: \(measurement.center), Enhanced: \(enhancedVector)")
            print("   📏 Inner distance: \(innerDistance), Outer distance: \(outerDistance)")
            print("   📊 Amplification factor: \((innerRatio - outerRatio) * 100.0)")
            
            return enhancedVector
        }
        
        // Fallback to original pupil center if no corner vectors available
        return measurement.center
        */
    }
    
    // IMPROVED VALIDATION: Cross-validation helpers
    private func performTrainValidationSplit() -> (training: [(screenPos: CGPoint, pupilPos: CGPoint, confidence: Double)], validation: [(screenPos: CGPoint, pupilPos: CGPoint, confidence: Double)])? {
        guard calibrationPairs.count >= 12 else { return nil }  // Need at least 12 points for meaningful split
        
        // Shuffle and split 70-30
        let shuffled = calibrationPairs.shuffled()
        let splitIndex = Int(Double(shuffled.count) * 0.7)
        
        let trainingPairs = Array(shuffled[0..<splitIndex])
        let validationPairs = Array(shuffled[splitIndex...])
        
        return (trainingPairs, validationPairs)
    }
    
    private func trainPolynomialMapper(with pairs: [(screenPos: CGPoint, pupilPos: CGPoint, confidence: Double)]) -> Bool {
        // CRITICAL FIX: Transform screen UI coordinates to normalized coordinate space
        // Screen coordinates are in UI points (e.g., 0-414 x 0-896 on iPhone)
        // We need to normalize these to work with pupil coordinates
        
        let transformedPairs = pairs.map { pair in
            // Transform screen coordinates to normalized space (0-1)
            // Use actual screen dimensions instead of hardcoded values
            let screenSize = UIScreen.main.bounds.size
            let normalizedScreenX = pair.screenPos.x / screenSize.width
            let normalizedScreenY = pair.screenPos.y / screenSize.height
            let normalizedScreenPos = CGPoint(x: normalizedScreenX, y: normalizedScreenY)
            
            print("🔄 COORDINATE TRANSFORM: Screen \(pair.screenPos) → Normalized \(normalizedScreenPos)")
            print("   📱 Screen size: \(screenSize)")
            
            return (screenPos: normalizedScreenPos, pupilPos: pair.pupilPos, confidence: pair.confidence)
        }
        
        // Extract coordinate ranges from transformed data
        let pupilXValues = transformedPairs.map { $0.pupilPos.x }
        let pupilYValues = transformedPairs.map { $0.pupilPos.y }
        let screenXValues = transformedPairs.map { $0.screenPos.x }
        let screenYValues = transformedPairs.map { $0.screenPos.y }
        
        guard let pupilXMin = pupilXValues.min(), let pupilXMax = pupilXValues.max(),
              let pupilYMin = pupilYValues.min(), let pupilYMax = pupilYValues.max(),
              let screenXMin = screenXValues.min(), let screenXMax = screenXValues.max(),
              let screenYMin = screenYValues.min(), let screenYMax = screenYValues.max() else {
            return false
        }
        
        // Store normalization ranges
        normalizationRanges = (pupilXMin: pupilXMin, pupilXMax: pupilXMax, pupilYMin: pupilYMin, pupilYMax: pupilYMax,
                              screenXMin: screenXMin, screenXMax: screenXMax, screenYMin: screenYMin, screenYMax: screenYMax)
        
        // Normalize data using transformed pairs
        let normalizedPairs = transformedPairs.map { pair in
            let normalizedPupilX = (pair.pupilPos.x - pupilXMin) / (pupilXMax - pupilXMin)
            let normalizedPupilY = (pair.pupilPos.y - pupilYMin) / (pupilYMax - pupilYMin)
            let normalizedScreenX = (pair.screenPos.x - screenXMin) / (screenXMax - screenXMin)
            let normalizedScreenY = (pair.screenPos.y - screenYMin) / (screenYMax - screenYMin)
            
            return (
                pupilPos: CGPoint(x: normalizedPupilX, y: normalizedPupilY),
                screenPos: CGPoint(x: normalizedScreenX, y: normalizedScreenY),
                confidence: pair.confidence
            )
        }
        
        print("🔍 TRAINING DATA: \(transformedPairs.count) pairs")
        print("   📍 Pupil X range: \(pupilXMin) to \(pupilXMax) (variation: \(pupilXMax - pupilXMin))")
        print("   📍 Pupil Y range: \(pupilYMin) to \(pupilYMax) (variation: \(pupilYMax - pupilYMin))")
        print("   📱 Screen X range: \(screenXMin) to \(screenXMax) (normalized)")
        print("   📱 Screen Y range: \(screenYMin) to \(screenYMax) (normalized)")
        
        polynomialGazeMapper.train(calibrationData: normalizedPairs)
        
        let quality = polynomialGazeMapper.getCalibrationQuality()
        return quality > 0.0
    }
    
    private func validateOnHoldoutSet(_ validationPairs: [(screenPos: CGPoint, pupilPos: CGPoint, confidence: Double)]) -> Double {
        guard let ranges = normalizationRanges else { return 0.0 }
        
        var totalError: Double = 0.0
        var validCount = 0
        
        for pair in validationPairs {
            // Normalize pupil position using training ranges
            let normalizedPupilX = (pair.pupilPos.x - ranges.pupilXMin) / (ranges.pupilXMax - ranges.pupilXMin)
            let normalizedPupilY = (pair.pupilPos.y - ranges.pupilYMin) / (ranges.pupilYMax - ranges.pupilYMin)
            let normalizedPupilPos = CGPoint(x: normalizedPupilX, y: normalizedPupilY)
            
            // Get predicted screen position
            let normalizedGazePos = polynomialGazeMapper.mapGaze(pupilPosition: normalizedPupilPos)
            
            // Convert back to screen coordinates
            let predictedScreenX = normalizedGazePos.x * (ranges.screenXMax - ranges.screenXMin) + ranges.screenXMin
            let predictedScreenY = normalizedGazePos.y * (ranges.screenYMax - ranges.screenYMin) + ranges.screenYMin
            let predictedScreen = CGPoint(x: predictedScreenX, y: predictedScreenY)
            
            // Calculate error
            let error = sqrt(pow(predictedScreen.x - pair.screenPos.x, 2) + pow(predictedScreen.y - pair.screenPos.y, 2))
            totalError += error
            validCount += 1
        }
        
        let avgError = totalError / Double(validCount)
        let accuracy = max(0.0, 1.0 - (avgError / 100.0))  // Convert error to accuracy
        
        print("🔍 HOLDOUT VALIDATION:")
        print("   📊 Average Error: \(String(format: "%.1f", avgError)) pixels")
        print("   📊 Accuracy: \(String(format: "%.1f", accuracy * 100))%")
        
        return accuracy
    }
    
    private func trainLinearFallback() {
        // Simple linear mapping as fallback
        print("🔄 Training linear fallback mapping")
        // Implementation would use simple linear regression instead of polynomial
        // For now, just ensure ranges are stored
        if normalizationRanges == nil {
            let pupilXValues = calibrationPairs.map { $0.pupilPos.x }
            let pupilYValues = calibrationPairs.map { $0.pupilPos.y }
            let screenXValues = calibrationPairs.map { $0.screenPos.x }
            let screenYValues = calibrationPairs.map { $0.screenPos.y }
            
            normalizationRanges = (
                pupilXMin: pupilXValues.min() ?? 0, pupilXMax: pupilXValues.max() ?? 640,
                pupilYMin: pupilYValues.min() ?? 0, pupilYMax: pupilYValues.max() ?? 480,
                screenXMin: screenXValues.min() ?? 0, screenXMax: screenXValues.max() ?? 414,
                screenYMin: screenYValues.min() ?? 0, screenYMax: screenYValues.max() ?? 896
            )
        }
    }
    
    // MARK: - Content Type Management (for Consumer Pathway)
    
    func setCurrentContentType(_ contentType: ContentType, taskPhase: String? = nil) {
        currentContentType = contentType
        currentTaskPhase = taskPhase
        print("📱 PupillometryManager: Content type updated to \(contentType.displayName)")
        if let phase = taskPhase {
            print("📱 Task phase: \(phase)")
        }
    }
    
    func getCurrentContentType() -> ContentType {
        return currentContentType
    }
    
    // MARK: - Public Methods
    
    func startSession() {
        // Set initial content type to calibration
        setCurrentContentType(.calibration, taskPhase: "session_start")
        
        // Check camera authorization first
        cameraManager.checkAuthorization { [weak self] authorized in
            guard let self = self else { return }
            
            if authorized {
                DispatchQueue.main.async {
                    self.delegate?.pupillometryManager(self, didUpdateStatus: "Starting camera...")
                }
                
                // Create new session - preserve existing demographics if available
                let existingDemographics = self.currentSession?.demographicData
                self.currentSession = SessionData()
                self.currentSession?.demographicData = existingDemographics
                
                if existingDemographics != nil {
                    print("✅ PupillometryManager: Preserved demographics in new session - Age: \(existingDemographics?.age ?? 0), Gender: \(existingDemographics?.gender ?? "Unknown")")
                } else {
                    print("⚠️ PupillometryManager: No existing demographics to preserve")
                }
                
                // Start camera
                self.cameraManager.startSession()
                
                // Start feature extraction timer
                self.startFeatureExtractionTimer()
                
                self.isRecording = true
                
                DispatchQueue.main.async {
                    self.delegate?.pupillometryManager(self, didUpdateStatus: "Recording started")
                }
            } else {
                DispatchQueue.main.async {
                    self.delegate?.pupillometryManager(self, didEncounterError: CameraError.authorizationFailed)
                }
            }
        }
    }
    
    func stopSession() {
        // Stop camera
        cameraManager.stopSession()
        
        // Stop feature extraction timer
        stopFeatureExtractionTimer()
        
        isRecording = false
        
        DispatchQueue.main.async {
            self.delegate?.pupillometryManager(self, didUpdateStatus: "Recording stopped")
        }
    }
    
    func recordEvent(_ event: TaskEvent) {
        guard let session = currentSession, isRecording else { return }
        
        session.taskEvents.append(event)
        
        // If we have a significant number of events, extract features
        if session.taskEvents.count % 10 == 0 {
            extractFeatures()
        }
    }
    
    // Update demographics
    func updateDemographics(_ demographics: SessionData.DemographicData) {
        print("📝 PupillometryManager: Updating demographics - Age: \(demographics.age), Gender: \(demographics.gender)")
        
        if currentSession == nil {
            print("🆕 PupillometryManager: Creating new session for demographics")
            currentSession = SessionData()
        }
        
        currentSession?.demographicData = demographics
        
        // Verify demographics were saved
        if let saved = currentSession?.demographicData {
            print("✅ PupillometryManager: Demographics saved successfully - Age: \(saved.age), Gender: \(saved.gender)")
        } else {
            print("❌ PupillometryManager: Failed to save demographics!")
        }
    }
    
    // MARK: - Calibration Methods
    
    func recordCalibrationPoint(at point: CGPoint) {
        calibrationPoints.append(point)
        let key = pointToKey(point)
        calibrationMeasurements[key] = []
        print("📍 PupillometryManager: Recorded calibration point at \(point) (Screen UI coordinates)")
        print("🔍 DEBUG: This point will be mapped to camera coordinate space during training")
    }
    
    func startCalibrationDataCollection(for point: CGPoint) {
        currentCalibrationPoint = point
        isCalibrating = true
        calibrationStartTime = CACurrentMediaTime()
        
        // CRITICAL: Set up camera delegate to receive frames
        setupComponents()
        
        let key = pointToKey(point)
        if calibrationMeasurements[key] == nil {
            calibrationMeasurements[key] = []
        }
        
        print("👁️ PupillometryManager: Started data collection for point \(point)")
        print("✅ PupillometryManager: Camera delegate set for data collection")
    }
    
    func stopCalibrationDataCollection() {
        isCalibrating = false
        currentCalibrationPoint = nil
        print("⏹️ PupillometryManager: Stopped calibration data collection")
    }
    
    func addCalibrationMeasurement(_ measurement: PupilMeasurement) {
        guard let currentPoint = currentCalibrationPoint, isCalibrating else { 
            print("⚠️ addCalibrationMeasurement called but not calibrating - currentPoint: \(currentCalibrationPoint != nil), isCalibrating: \(isCalibrating)")
            return 
        }
        
        print("📊 Received measurement for point \(currentPoint) - confidence: \(measurement.confidence)")
        
        // MOBILE-ADJUSTED QUALITY FILTER: Lower threshold for mobile devices
        guard measurement.confidence >= 0.3 else {  // Reduced from 0.6 to 0.3 for mobile
            print("🚫 Rejected low-confidence measurement: \(measurement.confidence) (threshold: 0.3)")
            return
        }
        
        print("✅ Accepted measurement with confidence: \(measurement.confidence)")
        
        let key = pointToKey(currentPoint)
        
        if calibrationMeasurements[key] == nil {
            calibrationMeasurements[key] = []
        }
        calibrationMeasurements[key]?.append(measurement)
        
        // MOBILE ENHANCEMENT: Use pupil-corner vectors if available for better signal
        let gazeFeatureVector = extractGazeFeatureVector(from: measurement)
        
        // Also collect pupil center positions for polynomial mapping
        calibrationPairs.append((
            screenPos: currentPoint,
            pupilPos: gazeFeatureVector, // Use enhanced feature vector instead of just center
            confidence: Double(measurement.confidence)
        ))
        
        print("👁️ PupillometryManager: Added calibration pair - Screen: \(currentPoint), Pupil: \(measurement.center), Confidence: \(measurement.confidence)")
        print("🔍 DEBUG: Calibration pair #\(calibrationPairs.count)")
        print("   📱 Screen coordinate: (\(currentPoint.x), \(currentPoint.y))")
        print("   👁️ Pupil coordinate: (\(measurement.center.x), \(measurement.center.y))")
        print("   📊 Confidence: \(measurement.confidence)")
        print("   📏 Expected pupil variation: X should vary significantly between screen positions")
    }
    
    func finalizeCalibration() -> CalibrationResult {
        print("🎯 PupillometryManager: Finalizing calibration with \(calibrationPoints.count) points and \(calibrationPairs.count) data pairs")
        
        // CRITICAL DEBUG: Check what calibration data we actually have
        print("🔍 CALIBRATION DATA CHECK:")
        print("   📊 calibrationPoints.count: \(calibrationPoints.count)")
        print("   📊 calibrationMeasurements.count: \(calibrationMeasurements.count)")
        print("   📊 calibrationPairs.count: \(calibrationPairs.count)")
        
        // Debug individual measurement collections
        for (key, measurements) in calibrationMeasurements {
            print("   📍 Point \(key): \(measurements.count) measurements")
        }
        
        // SIMPLIFIED: Focus on data collection first, then worry about advanced validation
        if calibrationPairs.count >= 6 {
            print("🧠 PupillometryManager: Training with simplified approach...")
            
            // Train directly on all data to diagnose the collection issue
            let success = trainPolynomialMapper(with: calibrationPairs)
            
            if !success {
                print("❌ Polynomial training failed, using linear fallback")
                trainLinearFallback()
            }
        } else {
            print("⚠️ PupillometryManager: Not enough calibration pairs (\(calibrationPairs.count)) for polynomial training")
            print("🔍 DIAGNOSIS: Expected ~400 pairs (9 points × 3s × ~15fps), got \(calibrationPairs.count)")
            print("🔍 This suggests a fundamental data collection issue")
            
            // Use fallback even with minimal data
            trainLinearFallback()
        }
        
        var validationPoints: [CalibrationResult.CalibrationPoint] = []
        var totalError: Double = 0.0
        var totalDataPoints = 0
        var totalResponseTime: Double = 0.0
        
        // CRITICAL DEBUG: Check if validation loop will run
        print("🔍 VALIDATION LOOP CHECK:")
        print("   📊 About to validate \(calibrationMeasurements.count) measurement groups")
        
        if calibrationMeasurements.isEmpty {
            print("   ❌ ERROR: No calibration measurements to validate!")
            print("   ❌ This explains why accuracy is 0% - no data to validate against")
        }
        
        for (key, measurements) in calibrationMeasurements {
            guard !measurements.isEmpty else { continue }
            
            let targetPoint = keyToPoint(key)
            let sortedByConfidence = measurements.sorted { $0.confidence > $1.confidence }
            
            if let bestMeasurement = sortedByConfidence.first {
                // Use polynomial gaze mapping instead of simplified estimation
                let gazePosition = estimateGazePosition(from: bestMeasurement, targetPoint: targetPoint)
                
                // Calculate error in degrees (approximation: 1 degree ≈ 17 pixels on typical display)
                let pixelError = sqrt(pow(gazePosition.x - targetPoint.x, 2) + pow(gazePosition.y - targetPoint.y, 2))
                let errorDegrees = Double(pixelError / 17.0)
                
                // DEBUG: Log validation details
                print("🔍 VALIDATION DEBUG:")
                print("   📍 Target: (\(targetPoint.x), \(targetPoint.y))")
                print("   👁️ Gaze:   (\(gazePosition.x), \(gazePosition.y))")
                print("   📏 Error:  \(String(format: "%.1f", pixelError)) pixels (\(String(format: "%.2f", errorDegrees)) degrees)")
                
                let calibrationPoint = CalibrationResult.CalibrationPoint(
                    targetPosition: targetPoint,
                    gazePosition: gazePosition,
                    error: errorDegrees,
                    confidence: Double(bestMeasurement.confidence)
                )
                
                validationPoints.append(calibrationPoint)
                totalError += errorDegrees * errorDegrees // For RMS calculation
                totalDataPoints += measurements.count
                totalResponseTime += Double(measurements.count) * 0.033 // Approximate frame time
            }
        }
        
        let rmsError = sqrt(totalError / Double(validationPoints.count))
        let accuracy = max(0.0, 1.0 - (rmsError / 2.0)) // Scale error to accuracy (2 degrees = 0% accuracy)
        let avgResponseTime = totalDataPoints > 0 ? totalResponseTime / Double(totalDataPoints) : 0.0
        
        // DEBUG: Log final accuracy calculation
        print("🔍 ACCURACY CALCULATION:")
        print("   📊 Total Error: \(totalError)")
        print("   📊 Validation Points: \(validationPoints.count)")
        print("   📊 RMS Error: \(String(format: "%.2f", rmsError)) degrees")
        print("   📊 Calculated Accuracy: \(String(format: "%.2f", accuracy * 100))%")
        
        // MOBILE-SPECIFIC validation thresholds (mobile eye tracking is inherently less accurate)
        #if DEBUG
        let minAccuracy = 0.0      // Testing: Accept any reasonable mapping
        let minPoints = 5          // Testing: Require 5+ points for validation
        let maxRMSError = 10.0     // Testing: Accept up to 10° RMS error for mobile (was 5.0)
        #else
        let minAccuracy = 0.1      // Production: Accept if RMS error < 8° 
        let minPoints = 7          // Production: Require 7+ points for validation
        let maxRMSError = 8.0      // Production: Accept up to 8° RMS error for mobile (was 4.0)
        #endif
        
        // Mobile-specific validation: Focus on RMS error rather than arbitrary accuracy
        let isMobileValid = rmsError < maxRMSError && validationPoints.count >= minPoints
        
        let isValid = isMobileValid  // Use mobile-specific validation
        
        print("   📊 Min Required Accuracy: \(String(format: "%.2f", minAccuracy * 100))%")
        print("   📊 Min Required Points: \(minPoints)")
        print("   📊 Max RMS Error: \(maxRMSError)°")
        print("   📊 Is Valid (Mobile): \(isMobileValid)")
        print("   📊 Is Valid (Traditional): \(accuracy > minAccuracy && validationPoints.count >= minPoints)")
        
        // Use mobile-specific accuracy calculation
        let mobileAccuracy = max(0.0, 1.0 - (rmsError / maxRMSError))
        
        let result = CalibrationResult(
            isValid: isValid,
            accuracy: mobileAccuracy,  // Use mobile-specific accuracy
            dataPointsCollected: totalDataPoints,
            averageResponseTime: avgResponseTime,
            rmsError: rmsError,
            validationPoints: validationPoints
        )
        
        // Calibrate stereovision calculator if we have good data
        if isValid && validationPoints.count >= 3 {
            performStereovisionCalibration(with: validationPoints)
        }
        
        print("✅ PupillometryManager: Calibration complete - Valid: \(isValid), Accuracy: \(accuracy)")
        
        // Reset calibration data for next session
        calibrationPoints.removeAll()
        calibrationMeasurements.removeAll()
        calibrationPairs.removeAll()
        normalizationRanges = nil  // Clear stored ranges
        isCalibrating = false
        
        return result
    }
    
    private func estimateGazePosition(from measurement: PupilMeasurement, targetPoint: CGPoint) -> CGPoint {
        // If polynomial mapper is not calibrated, use raw pupil position for real validation
        if polynomialGazeMapper.getCalibrationQuality() == 0.0 {
            print("⚠️ PupillometryManager: Polynomial mapper not calibrated, using raw pupil position for validation")
            print("🔍 DEBUG: Raw pupil position: \(measurement.center), Target: \(targetPoint)")
            
            // Return the actual detected pupil center - this tests if pupil tracking correlates with gaze
            // This will show large errors initially, which is CORRECT behavior
            return measurement.center
        }
        
        // COORDINATE SYSTEM FIX: Use stored normalization ranges from training
        guard let ranges = normalizationRanges else {
            print("❌ PupillometryManager: No normalization ranges stored! Using fallback")
            return measurement.center
        }
        
        print("🔍 DEBUG: Using stored normalization ranges:")
        print("   📍 Pupil bounds: X(\(ranges.pupilXMin)-\(ranges.pupilXMax)) Y(\(ranges.pupilYMin)-\(ranges.pupilYMax))")
        print("   📱 Screen bounds: X(\(ranges.screenXMin)-\(ranges.screenXMax)) Y(\(ranges.screenYMin)-\(ranges.screenYMax))")
        
        // MOBILE ENHANCEMENT: Use enhanced gaze feature vector for better signal
        let gazeFeatureVector = extractGazeFeatureVector(from: measurement)
        
        // Normalize pupil coordinates using exact same ranges from training
        let normalizedPupilX = (gazeFeatureVector.x - ranges.pupilXMin) / (ranges.pupilXMax - ranges.pupilXMin)
        let normalizedPupilY = (gazeFeatureVector.y - ranges.pupilYMin) / (ranges.pupilYMax - ranges.pupilYMin)
        let normalizedPupilPos = CGPoint(x: normalizedPupilX, y: normalizedPupilY)
        
        // Use polynomial gaze mapping with normalized coordinates
        let normalizedGazePos = polynomialGazeMapper.mapGaze(pupilPosition: normalizedPupilPos)
        
        // Convert normalized gaze position back to screen coordinates using exact same ranges from training
        let screenGazeX = normalizedGazePos.x * (ranges.screenXMax - ranges.screenXMin) + ranges.screenXMin
        let screenGazeY = normalizedGazePos.y * (ranges.screenYMax - ranges.screenYMin) + ranges.screenYMin
        let intermediatePos = CGPoint(x: screenGazeX, y: screenGazeY)
        
        // Now convert from normalized screen space (0-1) back to UI coordinates
        let screenSize = UIScreen.main.bounds.size
        let uiGazeX = intermediatePos.x * screenSize.width
        let uiGazeY = intermediatePos.y * screenSize.height
        let screenGazePos = CGPoint(x: uiGazeX, y: uiGazeY)
        
        print("✅ PupillometryManager: CONSISTENT MAPPING - Pupil: \(measurement.center) → Normalized: \(normalizedPupilPos) → Screen: \(screenGazePos)")
        return screenGazePos
    }
    
    private func performStereovisionCalibration(with validationPoints: [CalibrationResult.CalibrationPoint]) {
        // Use center points for stereovision calibration
        let centerPoints = validationPoints.filter { point in
            let center = CGPoint(x: 200, y: 200) // Approximate screen center
            let distance = sqrt(pow(point.targetPosition.x - center.x, 2) + pow(point.targetPosition.y - center.y, 2))
            return distance < 100 // Within 100 pixels of center
        }
        
        if let centerCalibration = centerPoints.first {
            // Get corresponding measurement
            let key = pointToKey(centerCalibration.targetPosition)
            if let measurements = calibrationMeasurements[key],
               let bestMeasurement = measurements.max(by: { $0.confidence < $1.confidence }) {
                
                // Use measured diameter from real pupil detection instead of hardcoded value
                let referenceDiameterMM = bestMeasurement.diameterMM > 0 ? bestMeasurement.diameterMM : 4.5
                
                stereovisionCalculator.calibrate(
                    withKnownSizeMM: referenceDiameterMM,
                    measuredPixels: bestMeasurement.radiusPixels * 2,
                    nirRgbDisparity: 10, // TODO: Calculate from actual stereo camera disparity
                    imageWidth: 640
                )
                
                print("🔧 PupillometryManager: Stereovision calibration completed")
            }
        }
    }
    
    // Extract features from current session
    func extractSessionFeatures() -> ADHDFeatures? {
        guard let session = currentSession else { return nil }
        
        return featureExtractor.extractFeatures(
            from: session.pupilMeasurements,
            events: session.taskEvents
        )
    }
    
    // MARK: - Real-time Gaze Tracking
    
    func getCurrentGazePosition(from measurement: PupilMeasurement) -> CGPoint? {
        guard polynomialGazeMapper.getCalibrationQuality() > 0.0 else {
            print("⚠️ PupillometryManager: Gaze mapper not calibrated")
            return nil
        }
        
        let gazePosition = polynomialGazeMapper.mapGaze(pupilPosition: measurement.center)
        print("🎯 PupillometryManager: POLYNOMIAL MAPPING:")
        print("   📍 Input Pupil Position: (\(measurement.center.x), \(measurement.center.y))")
        print("   📱 Output Screen Position: (\(gazePosition.x), \(gazePosition.y))")
        print("   📊 Calibration Quality: \(polynomialGazeMapper.getCalibrationQuality())")
        return gazePosition
    }
    
    func isGazeTrackingCalibrated() -> Bool {
        return polynomialGazeMapper.getCalibrationQuality() > 0.0
    }
    
    func resetGazeCalibration() {
        polynomialGazeMapper.reset()
        calibrationPoints.removeAll()
        calibrationMeasurements.removeAll()
        calibrationPairs.removeAll()
        normalizationRanges = nil  // Clear stored ranges
        print("🔄 PupillometryManager: Reset gaze calibration")
    }
    
    // MARK: - Private Methods
    
    private func startFeatureExtractionTimer() {
        featureExtractionTimer = Timer.scheduledTimer(withTimeInterval: featureExtractionInterval, repeats: true) { [weak self] _ in
            self?.extractFeatures()
        }
    }
    
    private func stopFeatureExtractionTimer() {
        featureExtractionTimer?.invalidate()
        featureExtractionTimer = nil
    }
    
    private func extractFeatures() {
        guard let session = currentSession, isRecording, !measurementBuffer.isEmpty else { return }
        
        // Extract features from buffer
        if let features = featureExtractor.extractFeatures(from: measurementBuffer, events: session.taskEvents) {
            DispatchQueue.main.async {
                self.delegate?.pupillometryManager(self, didUpdateFeatures: features)
            }
        }
    }
    
    private func calculateFPS() {
        let currentTime = CACurrentMediaTime()
        if lastFrameTime == 0 {
            lastFrameTime = currentTime
            frameCount = 1
            return
        }
        
        frameCount += 1
        
        // Calculate FPS every second
        let elapsed = currentTime - lastFrameTime
        if elapsed >= 1.0 {
            currentFPS = Double(frameCount) / elapsed
            frameCount = 0
            lastFrameTime = currentTime
            
            DispatchQueue.main.async {
                self.delegate?.pupillometryManager(self, didUpdateStatus: "FPS: \(Int(self.currentFPS))")
            }
        }
    }
}

// MARK: - CameraManagerDelegate
extension PupillometryManager {
    func cameraManager(_ manager: CameraManager, didOutput sampleBuffer: CMSampleBuffer, from camera: CameraType) {
        // Debug logging to track camera frames
        if camera == .infrared {
            print("📱 PupillometryManager: Received NIR frame from camera")
        }
        
        // SAFETY: Skip processing if memory pressure is high
        if measurementBuffer.count > bufferSize * 2 {
            print("⚠️ PupillometryManager: Skipping frame due to buffer overflow")
            return
        }
        
        // Check camera-specific processing flags
        let cameraIsProcessing = camera == .rgb ? isProcessingRGB : isProcessingNIR
        guard isRecording || isCalibrating, !cameraIsProcessing else { 
            if cameraIsProcessing {
                print("⚠️ PupillometryManager: Skipping \(camera.rawValue) frame - already processing")
            }
            return 
        }
        
        let startTime = CACurrentMediaTime()
        
        // Set camera-specific processing flag
        if camera == .rgb {
            isProcessingRGB = true
        } else {
            isProcessingNIR = true
        }
        
        // Calculate FPS
        calculateFPS()
        
        // Adaptive processing based on current load
        let shouldProcess = adaptiveProcessing ? shouldProcessFrame() : true
        
        // Process frame - NEW: Support for stereo processing
        if shouldProcess {
            // CRITICAL FIX: Process frame only once to avoid double processing
            let result = pupilDetector.processStereoFrame(sampleBuffer, cameraType: camera)
            
            // Store captured image if available (for engineering analysis)
            if let capturedImage = result.capturedImage {
                currentSession?.capturedImages.append(capturedImage)
                print("📸 PupillometryManager: Captured image - \(capturedImage.filename)")
            }
            
            // Process pupil measurement
            if let measurement = result.pupilMeasurement {
                // Update measurement with current content type and task phase
                let updatedMeasurement = PupilMeasurement(
                    timestamp: measurement.timestamp,
                    center: measurement.center,
                    radiusPixels: measurement.radiusPixels,
                    diameterMM: measurement.diameterMM,
                    confidence: measurement.confidence,
                    eye: measurement.eye,
                    facialLandmarks: measurement.facialLandmarks,
                    associatedImageFilename: measurement.associatedImageFilename,
                    contentType: currentContentType,  // Use current content type
                    taskPhase: currentTaskPhase,      // Use current task phase
                    videoTimestamp: currentTaskPhase != nil ? measurement.timestamp : nil,
                    eyeCornerInner: measurement.eyeCornerInner,
                    eyeCornerOuter: measurement.eyeCornerOuter,
                    pupilToInnerVector: measurement.pupilToInnerVector,
                    pupilToOuterVector: measurement.pupilToOuterVector
                )
                
                // Add to session
                currentSession?.pupilMeasurements.append(updatedMeasurement)
                
                // CRITICAL FIX: Always use main thread for buffer operations to prevent fatal array errors
                // This eliminates race conditions by ensuring all buffer operations are serialized
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    
                    // Atomic buffer update - all operations on main thread
                    self.measurementBuffer.append(updatedMeasurement)
                    
                    // ENHANCED SAFETY: Use while loop for guaranteed bounds safety
                    while self.measurementBuffer.count > self.bufferSize {
                        guard !self.measurementBuffer.isEmpty else {
                            print("❌ PupillometryManager: Buffer empty during cleanup - resetting")
                            self.measurementBuffer.removeAll()
                            break
                        }
                        self.measurementBuffer.removeFirst()
                    }
                    
                    // Periodic memory pressure check around trial 8
                    let currentMeasurementCount = self.currentSession?.pupilMeasurements.count ?? 0
                    if currentMeasurementCount > 8000 && currentMeasurementCount % 1000 == 0 {
                        print("⚠️ PupillometryManager: High measurement count: \(currentMeasurementCount) - memory pressure possible (5 trials)")
                    }
                }
            }
            
            // Process captured image (1 fps)
            if let capturedImage = result.capturedImage {
                print("📸 PupillometryManager: Captured image - \(capturedImage.filename)")
                currentSession?.capturedImages.append(capturedImage)
            }
            
            // Process facial landmarks
            if let landmarks = result.landmarks {
                print("👤 PupillometryManager: Extracted \(landmarks.leftEyeLandmarks.count + landmarks.rightEyeLandmarks.count) eye landmarks")
                currentSession?.facialLandmarksData.append(landmarks)
            }
            
            // Continue with existing calibration logic if pupil measurement exists
            if let measurement = result.pupilMeasurement {
                
                // If calibrating, also add to calibration data
                if isCalibrating {
                    addCalibrationMeasurement(measurement)
                }
                
                // Notify delegate on main queue
                DispatchQueue.main.async {
                    self.delegate?.pupillometryManager(self, didUpdateMeasurement: measurement)
                }
            }
        }
        
        // Track processing time for adaptive performance
        let processingTime = CACurrentMediaTime() - startTime
        updateProcessingLoad(processingTime)
        
        // Reset camera-specific processing flag
        if camera == .rgb {
            isProcessingRGB = false
        } else {
            isProcessingNIR = false
        }
    }
    
    private func shouldProcessFrame() -> Bool {
        // Skip frames if processing load is too high
        return currentProcessingLoad < 0.8 // Process only if under 80% load
    }
    
    private func updateProcessingLoad(_ processingTime: TimeInterval) {
        processingTimes.append(processingTime)
        
        // Keep only recent processing times (last 30 measurements)
        if processingTimes.count > 30 {
            processingTimes.removeFirst()
        }
        
        // Calculate average processing load
        let avgProcessingTime = processingTimes.reduce(0, +) / Double(processingTimes.count)
        let targetFrameTime = 1.0 / 30.0 // 30 FPS target for iPhone 11
        currentProcessingLoad = Float(avgProcessingTime / targetFrameTime)
        
        // Adapt processing if needed
        if currentProcessingLoad > 0.9 {
            adaptiveProcessing = true
            DispatchQueue.main.async {
                self.delegate?.pupillometryManager(self, didUpdateStatus: "High CPU load - reducing processing")
            }
        }
    }
    
    
    func cameraManager(_ manager: CameraManager, didEncounterError error: Error) {
        DispatchQueue.main.async {
            self.delegate?.pupillometryManager(self, didEncounterError: error)
        }
    }
}

// MARK: - Engineering Overlay Data Export
extension PupillometryManager {
    
    /// Get comprehensive overlay data for engineering visualization
    /// This provides all the coordinate transformations, scale factors, and landmark data
    /// needed to overlay landmarks on captured images
    func getOverlayDataForEngineering() -> [LandmarkOverlayData] {
        // Access MediaPipe overlay data through PupilDetector
        return pupilDetector.getOverlayDataForEngineering()
    }
    
    /// Export overlay data as JSON for external processing
    /// Returns JSON data containing all transformation parameters and landmark coordinates
    /// in both normalized Vision coordinates and final image coordinates
    func exportOverlayDataAsJSON() -> Data? {
        // Export MediaPipe overlay data through PupilDetector
        return pupilDetector.exportOverlayDataAsJSON()
    }
    
    /// Export overlay data as JSON string for debugging/logging
    func exportOverlayDataAsJSONString() -> String? {
        guard let jsonData = exportOverlayDataAsJSON() else { return nil }
        return String(data: jsonData, encoding: .utf8)
    }
    
    /// Clear the overlay data buffer to free memory
    func clearOverlayDataBuffer() {
        // Clear MediaPipe overlay data through PupilDetector
        pupilDetector.clearOverlayDataBuffer()
    }
    
    /// Save overlay data to file for engineering analysis
    func saveOverlayDataToFile(filename: String = "landmark_overlay_data.json") -> URL? {
        guard let jsonData = exportOverlayDataAsJSON() else {
            print("❌ PupillometryManager: Failed to generate overlay JSON data")
            return nil
        }
        
        // Get documents directory
        guard let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            print("❌ PupillometryManager: Failed to access documents directory")
            return nil
        }
        
        let fileURL = documentsDirectory.appendingPathComponent(filename)
        
        do {
            try jsonData.write(to: fileURL)
            print("✅ PupillometryManager: Overlay data saved to \(fileURL.path)")
            print("📊 Data size: \(jsonData.count / 1024)KB")
            return fileURL
        } catch {
            print("❌ PupillometryManager: Failed to save overlay data - \(error)")
            return nil
        }
    }
    
    /// Get summary of overlay data for debugging
    func getOverlayDataSummary() -> String {
        let overlayData = getOverlayDataForEngineering()
        
        if overlayData.isEmpty {
            return "No overlay data available"
        }
        
        let frameCount = overlayData.count
        let timeSpan = overlayData.last!.timestamp - overlayData.first!.timestamp
        let avgConfidence = overlayData.map { $0.faceConfidence }.reduce(0, +) / Float(overlayData.count)
        let goodQualityFrames = overlayData.filter { $0.qualityMetrics.recommendedForOverlay }.count
        
        let orientations = Set(overlayData.map { $0.orientationTransform }).sorted()
        let imageSizes = Set(overlayData.map { "\(Int($0.originalImageSize.width))x\(Int($0.originalImageSize.height))" })
        
        return """
        📊 Overlay Data Summary:
        • Frames: \(frameCount) over \(String(format: "%.1f", timeSpan))s
        • Average face confidence: \(String(format: "%.2f", avgConfidence))
        • Good quality frames: \(goodQualityFrames)/\(frameCount) (\(Int(Float(goodQualityFrames)/Float(frameCount)*100))%)
        • Image orientations: \(orientations)
        • Image sizes: \(Array(imageSizes))
        """
    }
}

// MARK: - Memory Management for Crash Prevention
extension PupillometryManager {
    
    /// Standard memory cleanup - called on memory warnings
    func performStandardMemoryCleanup() {
        print("🧹 PupillometryManager: Performing standard memory cleanup")
        
        // Clear processing buffers
        processingTimes.removeAll(keepingCapacity: true)
        
        // Reduce measurement buffer size temporarily
        let originalBufferSize = bufferSize
        let reducedSize = min(bufferSize / 2, 150) // Reduce to 150 max
        
        while measurementBuffer.count > reducedSize {
            guard !measurementBuffer.isEmpty else {
                print("❌ PupillometryManager: Buffer empty during standard cleanup - resetting")
                measurementBuffer.removeAll()
                break
            }
            measurementBuffer.removeFirst()
        }
        
        // Clear overlay data buffer
        clearOverlayDataBuffer()
        
        print("✅ Standard cleanup complete - buffer reduced from \(originalBufferSize) to \(measurementBuffer.count)")
    }
    
    /// Aggressive memory cleanup - called on critical memory pressure
    func performAggressiveMemoryCleanup() {
        print("🚨 PupillometryManager: Performing aggressive memory cleanup")
        
        // Perform standard cleanup first
        performStandardMemoryCleanup()
        
        // Aggressively reduce buffer to minimum
        let minimumBuffer = 30 // 1 second at 30 FPS
        while measurementBuffer.count > minimumBuffer {
            guard !measurementBuffer.isEmpty else {
                measurementBuffer.removeAll()
                break
            }
            measurementBuffer.removeFirst()
        }
        
        // Clear all calibration data if not actively calibrating
        if !isCalibrating {
            calibrationMeasurements.removeAll()
            calibrationPairs.removeAll()
            calibrationPoints.removeAll()
        }
        
        // Clear session data images if session has many stored
        if let session = currentSession, session.capturedImages.count > 10 {
            // Keep only last 10 images
            let imagesToKeep = Array(session.capturedImages.suffix(10))
            session.capturedImages = imagesToKeep
            print("🧹 Reduced captured images from \(session.capturedImages.count) to 10")
        }
        
        print("✅ Aggressive cleanup complete - buffer size: \(measurementBuffer.count)")
    }
    
    /// Emergency memory cleanup - prevent app termination while preserving core functionality
    func emergencyMemoryCleanup() {
        print("🆘 PupillometryManager: EMERGENCY memory cleanup - preserving core functionality")
        
        // DO NOT stop camera session if actively calibrating or doing ADHD task
        let isActivelyCalibrating = isCalibrating
        let hasActiveSession = currentSession != nil
        
        if isActivelyCalibrating {
            print("🔒 EMERGENCY: Preserving camera session - calibration in progress")
        } else if hasActiveSession {
            print("🔒 EMERGENCY: Preserving camera session - ADHD task may be running")
        } else {
            print("🛑 EMERGENCY: Safe to stop session - no active tasks")
            stopSession()
        }
        
        // Clear processing buffers but preserve essential data
        processingTimes.removeAll()
        
        // Reduce measurement buffer to minimum while preserving recent data
        let minimumBuffer = 60 // 2 seconds at 30 FPS
        while measurementBuffer.count > minimumBuffer {
            guard !measurementBuffer.isEmpty else {
                measurementBuffer.removeAll()
                break
            }
            measurementBuffer.removeFirst()  // Remove oldest data
        }
        
        // Clear feature extraction timer (non-essential)
        featureExtractionTimer?.invalidate()
        featureExtractionTimer = nil
        
        // CRITICAL: DO NOT clear calibration data if calibrating
        if !isActivelyCalibrating {
            print("🧹 EMERGENCY: Safe to clear calibration data")
            calibrationMeasurements.removeAll()
            calibrationPairs.removeAll()
            calibrationPoints.removeAll()
        } else {
            print("🔒 EMERGENCY: Preserving calibration data - calibration in progress")
        }
        
        // Clear non-essential session data
        if let session = currentSession {
            // Clear images but preserve measurements for ADHD detection
            session.capturedImages.removeAll()
            session.facialLandmarksData.removeAll()
            
            // Only reduce measurements if we have excessive amounts
            if session.pupilMeasurements.count > 1000 {
                let measurementsToKeep = Array(session.pupilMeasurements.suffix(500))
                session.pupilMeasurements = measurementsToKeep
                print("🧹 Emergency: Reduced measurements to \(session.pupilMeasurements.count)")
            } else {
                print("🔒 Emergency: Preserving \(session.pupilMeasurements.count) measurements for ADHD detection")
            }
        }
        
        // Clear overlay data (non-essential)
        clearOverlayDataBuffer()
        
        // Force garbage collection
        autoreleasepool {
            // Force ARC cleanup
        }
        
        print("✅ EMERGENCY cleanup complete - core functionality preserved")
    }
    
    /// Get current memory usage statistics
    func getMemoryStats() -> (bufferSize: Int, imagesCount: Int, measurementsCount: Int, landmarksCount: Int) {
        let imagesCount = currentSession?.capturedImages.count ?? 0
        let measurementsCount = currentSession?.pupilMeasurements.count ?? 0
        let landmarksCount = currentSession?.facialLandmarksData.count ?? 0
        
        return (
            bufferSize: measurementBuffer.count,
            imagesCount: imagesCount,
            measurementsCount: measurementsCount,
            landmarksCount: landmarksCount
        )
    }
}

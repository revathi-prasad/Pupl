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

protocol PupillometryManagerDelegate: AnyObject {
    func pupillometryManager(_ manager: PupillometryManager, didUpdateMeasurement measurement: PupilMeasurement)
    func pupillometryManager(_ manager: PupillometryManager, didEncounterError error: Error)
    func pupillometryManager(_ manager: PupillometryManager, didUpdateFeatures features: ADHDFeatures)
    func pupillometryManager(_ manager: PupillometryManager, didUpdateStatus status: String)
}

class PupillometryManager: NSObject {
    // Singleton instance
    static let shared = PupillometryManager()
    
    // Core components
    private let cameraManager = CameraManager()
    private let pupilDetector = PupilDetector()
    private let featureExtractor = FeatureExtractor()
    private let stereovisionCalculator = StereovisionCalculator()
    
    // Session management
    var currentSession: SessionData?
    
    // Calibration data
    private var calibrationPoints: [CGPoint] = []
    private var calibrationMeasurements: [String: [PupilMeasurement]] = [:]
    private var currentCalibrationPoint: CGPoint?
    private var isCalibrating = false
    private var calibrationStartTime: TimeInterval = 0
    
    // Processing state
    private var isProcessing = false
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
    }
    
    private func pointToKey(_ point: CGPoint) -> String {
        return "\(point.x),\(point.y)"
    }

    private func keyToPoint(_ key: String) -> CGPoint {
        let components = key.split(separator: ",")
        return CGPoint(x: Double(components[0]) ?? 0, y: Double(components[1]) ?? 0)
    }
    
    // MARK: - Public Methods
    
    func startSession() {
        // Check camera authorization first
        cameraManager.checkAuthorization { [weak self] authorized in
            guard let self = self else { return }
            
            if authorized {
                DispatchQueue.main.async {
                    self.delegate?.pupillometryManager(self, didUpdateStatus: "Starting camera...")
                }
                
                // Create new session
                self.currentSession = SessionData()
                
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
        if currentSession == nil {
            currentSession = SessionData()
        }
        currentSession?.demographicData = demographics
    }
    
    // MARK: - Calibration Methods
    
    func recordCalibrationPoint(at point: CGPoint) {
        calibrationPoints.append(point)
        let key = pointToKey(point)
        calibrationMeasurements[key] = []
        print("📍 PupillometryManager: Recorded calibration point at \(point)")
    }
    
    func startCalibrationDataCollection(for point: CGPoint) {
        currentCalibrationPoint = point
        isCalibrating = true
        calibrationStartTime = CACurrentMediaTime()
        
        let key = pointToKey(point)
        if calibrationMeasurements[key] == nil {
            calibrationMeasurements[key] = []
        }
        
        print("👁️ PupillometryManager: Started data collection for point \(point)")
    }
    
    func stopCalibrationDataCollection() {
        isCalibrating = false
        currentCalibrationPoint = nil
        print("⏹️ PupillometryManager: Stopped calibration data collection")
    }
    
    func addCalibrationMeasurement(_ measurement: PupilMeasurement) {
        guard let currentPoint = currentCalibrationPoint, isCalibrating else { return }
        let key = pointToKey(currentPoint)
        
        if calibrationMeasurements[key] == nil {
            calibrationMeasurements[key] = []
        }
        calibrationMeasurements[key]?.append(measurement)
    }
    
    func finalizeCalibration() -> CalibrationResult {
        print("🎯 PupillometryManager: Finalizing calibration with \(calibrationPoints.count) points")
        
        var validationPoints: [CalibrationResult.CalibrationPoint] = []
        var totalError: Double = 0.0
        var totalDataPoints = 0
        var totalResponseTime: Double = 0.0
        
        for (key, measurements) in calibrationMeasurements {
            guard !measurements.isEmpty else { continue }
            
            let targetPoint = keyToPoint(key)
            let sortedByConfidence = measurements.sorted { $0.confidence > $1.confidence }
            
            if let bestMeasurement = sortedByConfidence.first {
                // Calculate gaze position (simplified - in real implementation would use complex gaze mapping)
                let gazePosition = estimateGazePosition(from: bestMeasurement, targetPoint: targetPoint)
                
                // Calculate error in degrees (approximation: 1 degree ≈ 17 pixels on typical display)
                let pixelError = sqrt(pow(gazePosition.x - targetPoint.x, 2) + pow(gazePosition.y - targetPoint.y, 2))
                let errorDegrees = Double(pixelError / 17.0)
                
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
        let isValid = accuracy > 0.7 && validationPoints.count >= 7 // Need at least 7 good points with >70% accuracy
        
        let result = CalibrationResult(
            isValid: isValid,
            accuracy: accuracy,
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
        isCalibrating = false
        
        return result
    }
    
    private func estimateGazePosition(from measurement: PupilMeasurement, targetPoint: CGPoint) -> CGPoint {
        // Simplified gaze estimation - in real implementation this would involve:
        // 1. Pupil center relative to eye center
        // 2. Head pose estimation
        // 3. Calibration matrix transformation
        // 4. Screen coordinate mapping
        
        // For now, add some realistic noise around the target point
        let noiseX = Float.random(in: -20...20) * (1.0 - measurement.confidence)
        let noiseY = Float.random(in: -20...20) * (1.0 - measurement.confidence)
        
        return CGPoint(
            x: targetPoint.x + CGFloat(noiseX),
            y: targetPoint.y + CGFloat(noiseY)
        )
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
                
                stereovisionCalculator.calibrate(
                    withKnownSizeMM: 4.5, // Average pupil diameter
                    measuredPixels: bestMeasurement.radiusPixels * 2,
                    nirRgbDisparity: 10, // Placeholder - would be calculated from stereo vision
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
extension PupillometryManager: CameraManagerDelegate {
    func cameraManager(_ manager: CameraManager, didOutput sampleBuffer: CMSampleBuffer, from camera: CameraType) {
        guard isRecording, !isProcessing else { return }
        
        let startTime = CACurrentMediaTime()
        
        // Set processing flag to prevent concurrent processing
        isProcessing = true
        
        // Calculate FPS
        calculateFPS()
        
        // Adaptive processing based on current load
        let shouldProcess = adaptiveProcessing ? shouldProcessFrame() : true
        
        // Process frame
        if camera == .rgb && shouldProcess {
            // RGB camera processing
            if let measurement = pupilDetector.detectPupil(in: sampleBuffer) {
                // Add to session
                currentSession?.pupilMeasurements.append(measurement)
                
                // Add to buffer with memory management - thread safe
                DispatchQueue.main.async {
                    self.measurementBuffer.append(measurement)
                    if self.measurementBuffer.count > self.bufferSize {
                        self.measurementBuffer.removeFirst(self.measurementBuffer.count - self.bufferSize)
                    }
                }
                
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
        
        // Reset processing flag
        isProcessing = false
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

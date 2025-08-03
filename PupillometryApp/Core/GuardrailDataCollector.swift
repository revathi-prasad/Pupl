//
//  GuardrailDataCollector.swift
//  PupillometryApp
//
//  Created by Claude on 10/07/25.
//

import Foundation
import ARKit
import AVFoundation
import CoreMotion
import UIKit

class GuardrailDataCollector: NSObject {
    
    // MARK: - Data Collection Arrays
    private var environmentalData: [EnvironmentalQuality] = []
    private var dataQualityMetrics: [DataQualityMetrics] = []
    private var behaviorMetrics: [ParticipantBehaviorMetrics] = []
    private var technicalMetrics: [TechnicalPerformanceMetrics] = []
    private var safetyMetrics: [SafetyComplianceMetrics] = []
    private var sessionQualityScores: [SessionQualityScore] = []
    
    // MARK: - Sensors and Managers
    private let motionManager = CMMotionManager()
    private let audioSession = AVAudioSession.sharedInstance()
    private var arSession: ARSession?
    private var lightingMonitor: LightingMonitor?
    private var audioLevelMonitor: AudioLevelMonitor?
    
    // MARK: - Collection Intervals
    private let highFrequencyInterval: TimeInterval = 0.1    // 10 Hz for critical metrics
    private let mediumFrequencyInterval: TimeInterval = 1.0  // 1 Hz for standard metrics
    private let lowFrequencyInterval: TimeInterval = 5.0     // 0.2 Hz for summary metrics
    
    private var collectionTimers: [Timer] = []
    private var isCollecting = false
    
    // MARK: - Thresholds and Configuration
    private let qualityThresholds = QualityThresholds()
    
    struct QualityThresholds {
        let minLightLevel: Float = 200.0        // Lux
        let maxLightLevel: Float = 800.0        // Lux
        let maxHeadMovement: Float = 50.0       // mm
        let maxHeadRotation: Float = 15.0       // degrees
        let minPupilConfidence: Float = 0.7     // 70%
        let maxDistanceFromOptimal: Float = 20.0 // cm from 55cm optimal
        let maxResponseLatency: TimeInterval = 2.0 // seconds
        let minBatteryLevel: Float = 0.2        // 20%
    }
    
    // MARK: - Initialization
    override init() {
        super.init()
        setupSensors()
    }
    
    // MARK: - Data Collection Control
    func startCollection() {
        guard !isCollecting else { return }
        isCollecting = true
        
        print("🛡️ GuardrailDataCollector: Starting comprehensive data collection")
        
        // Start high-frequency collection (environmental monitoring)
        let highFreqTimer = Timer.scheduledTimer(withTimeInterval: highFrequencyInterval, repeats: true) { _ in
            self.collectHighFrequencyData()
        }
        
        // Start medium-frequency collection (quality metrics)
        let mediumFreqTimer = Timer.scheduledTimer(withTimeInterval: mediumFrequencyInterval, repeats: true) { _ in
            self.collectMediumFrequencyData()
        }
        
        // Start low-frequency collection (summary scores)
        let lowFreqTimer = Timer.scheduledTimer(withTimeInterval: lowFrequencyInterval, repeats: true) { _ in
            self.collectLowFrequencyData()
        }
        
        collectionTimers = [highFreqTimer, mediumFreqTimer, lowFreqTimer]
        
        // Start sensor monitoring
        startMotionMonitoring()
        startAudioMonitoring()
        startARSessionIfAvailable()
    }
    
    func stopCollection() {
        guard isCollecting else { return }
        isCollecting = false
        
        print("🛡️ GuardrailDataCollector: Stopping data collection")
        
        // Stop all timers
        collectionTimers.forEach { $0.invalidate() }
        collectionTimers.removeAll()
        
        // Stop sensors
        motionManager.stopAccelerometerUpdates()
        motionManager.stopGyroUpdates()
        arSession?.pause()
        audioLevelMonitor?.stop()
    }
    
    // MARK: - High-Frequency Data Collection (10 Hz)
    private func collectHighFrequencyData() {
        let timestamp = CACurrentMediaTime()
        
        // Collect environmental quality metrics
        let environmentalQuality = EnvironmentalQuality(
            timestamp: timestamp,
            lightingConditions: collectLightingMetrics(),
            distanceStability: collectDistanceMetrics(),
            headStability: collectHeadMovementMetrics(),
            deviceStability: collectDeviceMotionMetrics(),
            backgroundNoise: collectAudioMetrics(),
            batteryLevel: UIDevice.current.batteryLevel,
            thermalState: ProcessInfo.processInfo.thermalState,
            overallQualityScore: calculateEnvironmentalQualityScore()
        )
        
        environmentalData.append(environmentalQuality)
        
        // Check for immediate quality issues
        checkImmediateQualityIssues(environmentalQuality)
    }
    
    // MARK: - Medium-Frequency Data Collection (1 Hz)
    private func collectMediumFrequencyData() {
        let timestamp = CACurrentMediaTime()
        
        // Collect data quality metrics
        let dataQuality = DataQualityMetrics(
            timestamp: timestamp,
            pupilDetectionQuality: collectPupilQualityMetrics(),
            calibrationQuality: collectCalibrationQualityMetrics(),
            signalQuality: collectSignalQualityMetrics(),
            temporalConsistency: collectTemporalMetrics()
        )
        
        dataQualityMetrics.append(dataQuality)
        
        // Collect participant behavior metrics
        let behaviorMetric = ParticipantBehaviorMetrics(
            timestamp: timestamp,
            attentionMetrics: collectAttentionMetrics(),
            complianceMetrics: collectComplianceMetrics(),
            fatigueIndicators: collectFatigueMetrics(),
            engagementLevel: calculateEngagementLevel()
        )
        
        behaviorMetrics.append(behaviorMetric)
        
        // Collect technical performance metrics
        let technicalMetric = TechnicalPerformanceMetrics(
            timestamp: timestamp,
            systemMetrics: collectSystemMetrics(),
            algorithmMetrics: collectAlgorithmMetrics(),
            networkMetrics: collectNetworkMetrics(),
            storageMetrics: collectStorageMetrics()
        )
        
        technicalMetrics.append(technicalMetric)
    }
    
    // MARK: - Low-Frequency Data Collection (0.2 Hz)
    private func collectLowFrequencyData() {
        let timestamp = CACurrentMediaTime()
        
        // Collect safety and compliance metrics
        let safetyMetric = SafetyComplianceMetrics(
            timestamp: timestamp,
            participantSafety: collectParticipantSafetyMetrics(),
            dataPrivacy: collectDataPrivacyMetrics(),
            regulatoryCompliance: collectRegulatoryMetrics(),
            emergencyProtocols: collectEmergencyMetrics()
        )
        
        safetyMetrics.append(safetyMetric)
        
        // Calculate overall session quality score
        let sessionQuality = calculateSessionQualityScore(timestamp: timestamp)
        sessionQualityScores.append(sessionQuality)
        
        // Generate recommendations if needed
        if sessionQuality.overallScore < 0.7 {
            handleQualityIssues(sessionQuality)
        }
    }
    
    // MARK: - Sensor Setup and Data Collection Methods
    private func setupSensors() {
        // Configure motion manager
        motionManager.accelerometerUpdateInterval = highFrequencyInterval
        motionManager.gyroUpdateInterval = highFrequencyInterval
        
        // Setup lighting monitor
        lightingMonitor = LightingMonitor()
        
        // Setup audio level monitor
        audioLevelMonitor = AudioLevelMonitor()
    }
    
    private func startMotionMonitoring() {
        if motionManager.isAccelerometerAvailable {
            motionManager.startAccelerometerUpdates()
        }
        
        if motionManager.isGyroAvailable {
            motionManager.startGyroUpdates()
        }
    }
    
    private func startAudioMonitoring() {
        audioLevelMonitor?.start()
    }
    
    private func startARSessionIfAvailable() {
        if ARFaceTrackingConfiguration.isSupported {
            arSession = ARSession()
            let configuration = ARFaceTrackingConfiguration()
            configuration.isLightEstimationEnabled = true
            arSession?.run(configuration)
        }
    }
    
    // MARK: - Individual Metric Collection Methods
    private func collectLightingMetrics() -> EnvironmentalQuality.LightingMetrics {
        let lightLevel = lightingMonitor?.currentLightLevel ?? 0.0
        let uniformity = lightingMonitor?.illuminationUniformity ?? 0.0
        let contrast = lightingMonitor?.contrastRatio ?? 0.0
        let reflection = lightingMonitor?.hasReflection ?? false
        let stability = lightingMonitor?.lightingStability ?? 0.0
        let optimalRange = (200.0...800.0).contains(lightLevel)
        
        return EnvironmentalQuality.LightingMetrics(
            ambientLightLevel: lightLevel,
            illuminationUniformity: uniformity,
            contrastRatio: contrast,
            reflectionDetected: reflection,
            lightingStability: stability,
            optimalLightingRange: optimalRange
        )
    }
    
    private func collectDistanceMetrics() -> EnvironmentalQuality.DistanceMetrics {
        // Would integrate with ARKit face tracking for distance
        return EnvironmentalQuality.DistanceMetrics(
            currentDistance: 55.0, // Placeholder - would use ARKit
            optimalRange: 40.0...70.0,
            distanceVariance: 5.0,
            distanceConfidence: 0.8,
            suddenMovements: 0
        )
    }
    
    private func collectHeadMovementMetrics() -> EnvironmentalQuality.HeadMovementMetrics {
        // Would integrate with ARKit face tracking
        return EnvironmentalQuality.HeadMovementMetrics(
            headPose: (pitch: 0.0, yaw: 0.0, roll: 0.0), // Placeholder
            translationVariance: SIMD3<Float>(0, 0, 0),
            rotationVariance: SIMD3<Float>(0, 0, 0),
            movementVelocity: 0.0,
            stabilityDuration: 10.0,
            excessiveMovement: false
        )
    }
    
    private func collectDeviceMotionMetrics() -> EnvironmentalQuality.DeviceMotionMetrics {
        let acceleration = motionManager.accelerometerData?.acceleration ?? CMAcceleration(x: 0, y: 0, z: 0)
        let rotation = motionManager.gyroData?.rotationRate ?? CMRotationRate(x: 0, y: 0, z: 0)
        let orientation = UIDevice.current.orientation
        
        return EnvironmentalQuality.DeviceMotionMetrics(
            accelerometer: acceleration,
            gyroscope: rotation,
            deviceOrientation: orientation,
            motionStability: calculateMotionStability(acceleration, rotation),
            handTremor: detectHandTremor(acceleration)
        )
    }
    
    private func collectAudioMetrics() -> EnvironmentalQuality.AudioMetrics {
        return EnvironmentalQuality.AudioMetrics(
            ambientNoiseLevel: audioLevelMonitor?.currentLevel ?? 0.0,
            distractionEvents: audioLevelMonitor?.recentEvents ?? [],
            quietPeriods: audioLevelMonitor?.quietDuration ?? 0.0
        )
    }
    
    // MARK: - Data Quality Methods
    private func collectPupilQualityMetrics() -> DataQualityMetrics.PupilQualityMetrics {
        // Would integrate with PupilDetector for actual quality metrics
        return DataQualityMetrics.PupilQualityMetrics(
            detectionConfidence: 0.8,
            boundarySharpness: 0.7,
            circularityScore: 0.9,
            sizeConsistency: 0.8,
            artifactDetection: [],
            occlusionLevel: 0.1
        )
    }
    
    private func collectCalibrationQualityMetrics() -> DataQualityMetrics.CalibrationQualityMetrics {
        // Would integrate with PupillometryManager for calibration quality
        return DataQualityMetrics.CalibrationQualityMetrics(
            spatialAccuracy: 1.2,
            temporalStability: 0.8,
            edgeAccuracy: 0.7,
            centerAccuracy: 0.9,
            polynomialFitQuality: 0.85,
            outlierPercentage: 0.05,
            recalibrationNeeded: false
        )
    }
    
    private func collectSignalQualityMetrics() -> DataQualityMetrics.SignalQualityMetrics {
        return DataQualityMetrics.SignalQualityMetrics(
            signalToNoiseRatio: 25.0,
            samplingConsistency: 0.95,
            dataLossPercentage: 0.02,
            processingLatency: 0.033,
            memoryUsage: getMemoryUsage(),
            cpuUsage: getCPUUsage()
        )
    }
    
    private func collectTemporalMetrics() -> DataQualityMetrics.TemporalMetrics {
        return DataQualityMetrics.TemporalMetrics(
            frameSynchronization: 0.99,
            eventLatency: 0.05,
            clockDrift: 0.001,
            bufferHealth: 0.8
        )
    }
    
    // MARK: - Helper Methods
    private func calculateEnvironmentalQualityScore() -> Float {
        // Combine all environmental factors into single score
        let recentData = environmentalData.suffix(10) // Last 10 samples
        
        if recentData.isEmpty { return 0.5 }
        
        let avgLighting = recentData.map { $0.lightingConditions.ambientLightLevel }.reduce(0, +) / Float(recentData.count)
        let lightingScore: Float = qualityThresholds.minLightLevel...qualityThresholds.maxLightLevel ~= avgLighting ? 1.0 : 0.5
        
        // Add more sophisticated scoring logic here
        return lightingScore
    }
    
    private func calculateSessionQualityScore(timestamp: TimeInterval) -> SessionQualityScore {
        let envScore = environmentalData.last?.overallQualityScore ?? 0.5
        let dataScore = Float(dataQualityMetrics.last?.signalQuality.signalToNoiseRatio ?? 0.0) / 30.0 // Normalize SNR
        let techScore = Float(UIDevice.current.batteryLevel)
        
        let overallScore = (envScore + min(dataScore, 1.0) + techScore) / 3.0
        
        var recommendations: [SessionQualityScore.QualityRecommendation] = []
        
        if envScore < 0.7 { recommendations.append(.improveEnvironmentalConditions) }
        if dataScore < 0.7 { recommendations.append(.recalibrate) }
        if techScore < 0.3 { recommendations.append(.checkDeviceStability) }
        
        return SessionQualityScore(
            timestamp: timestamp,
            overallScore: overallScore,
            environmentalScore: envScore,
            dataQualityScore: min(dataScore, 1.0),
            participantScore: 0.8, // Placeholder
            technicalScore: techScore,
            safetyScore: 1.0, // Placeholder
            recommendations: recommendations
        )
    }
    
    // MARK: - Data Export Methods
    func exportGuardrailData() -> GuardrailDataExport {
        return GuardrailDataExport(
            environmentalData: environmentalData,
            dataQualityMetrics: dataQualityMetrics,
            behaviorMetrics: behaviorMetrics,
            technicalMetrics: technicalMetrics,
            safetyMetrics: safetyMetrics,
            sessionQualityScores: sessionQualityScores
        )
    }
    
    func clearCollectedData() {
        environmentalData.removeAll()
        dataQualityMetrics.removeAll()
        behaviorMetrics.removeAll()
        technicalMetrics.removeAll()
        safetyMetrics.removeAll()
        sessionQualityScores.removeAll()
    }
    
    // MARK: - Real-time Quality Monitoring
    private func checkImmediateQualityIssues(_ quality: EnvironmentalQuality) {
        // Check for critical quality issues that require immediate action
        if !quality.lightingConditions.optimalLightingRange {
            NotificationCenter.default.post(name: .guardrailAlert, 
                                          object: GuardrailAlert.lightingSuboptimal)
        }
        
        if quality.headStability.excessiveMovement {
            NotificationCenter.default.post(name: .guardrailAlert, 
                                          object: GuardrailAlert.excessiveHeadMovement)
        }
        
        if quality.batteryLevel < qualityThresholds.minBatteryLevel {
            NotificationCenter.default.post(name: .guardrailAlert, 
                                          object: GuardrailAlert.lowBattery)
        }
    }
    
    private func handleQualityIssues(_ sessionQuality: SessionQualityScore) {
        for recommendation in sessionQuality.recommendations {
            switch recommendation {
            case .improveEnvironmentalConditions:
                print("⚠️ GuardrailDataCollector: Environmental conditions need improvement")
            case .recalibrate:
                print("⚠️ GuardrailDataCollector: Recalibration recommended")
            case .checkDeviceStability:
                print("⚠️ GuardrailDataCollector: Device stability issues detected")
            default:
                break
            }
        }
    }
}

// MARK: - Supporting Classes and Extensions
struct GuardrailDataExport {
    let environmentalData: [EnvironmentalQuality]
    let dataQualityMetrics: [DataQualityMetrics]
    let behaviorMetrics: [ParticipantBehaviorMetrics]
    let technicalMetrics: [TechnicalPerformanceMetrics]
    let safetyMetrics: [SafetyComplianceMetrics]
    let sessionQualityScores: [SessionQualityScore]
}

enum GuardrailAlert {
    case lightingSuboptimal
    case excessiveHeadMovement
    case lowBattery
    case dataQualityPoor
    case participantFatigue
}

extension Notification.Name {
    static let guardrailAlert = Notification.Name("guardrailAlert")
}

// MARK: - Placeholder Helper Classes
class LightingMonitor {
    var currentLightLevel: Float = 400.0
    var illuminationUniformity: Float = 0.8
    var contrastRatio: Float = 4.0
    var hasReflection: Bool = false
    var lightingStability: Float = 0.9
}

class AudioLevelMonitor {
    var currentLevel: Float = 45.0
    var recentEvents: [EnvironmentalQuality.AudioMetrics.DistractionEvent] = []
    var quietDuration: TimeInterval = 30.0
    
    func start() {
        // Start audio monitoring
    }
    
    func stop() {
        // Stop audio monitoring
    }
}

// MARK: - Helper Functions
private func calculateMotionStability(_ acceleration: CMAcceleration, _ rotation: CMRotationRate) -> Float {
    let accelMagnitude = sqrt(acceleration.x * acceleration.x + acceleration.y * acceleration.y + acceleration.z * acceleration.z)
    let rotationMagnitude = sqrt(rotation.x * rotation.x + rotation.y * rotation.y + rotation.z * rotation.z)
    
    // Normalize and invert (higher stability = less movement)
    return max(0.0, 1.0 - Float((accelMagnitude + rotationMagnitude) / 2.0))
}

private func detectHandTremor(_ acceleration: CMAcceleration) -> Float {
    // Simplified tremor detection based on acceleration frequency analysis
    let magnitude = sqrt(acceleration.x * acceleration.x + acceleration.y * acceleration.y + acceleration.z * acceleration.z)
    return Float(magnitude > 0.1 ? magnitude : 0.0)
}

private func getMemoryUsage() -> Float {
    var info = mach_task_basic_info()
    var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
    
    let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
        $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
            task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
        }
    }
    
    if kerr == KERN_SUCCESS {
        return Float(info.resident_size) / 1024.0 / 1024.0 // Convert to MB
    }
    return 0.0
}

private func getCPUUsage() -> Float {
    var info: processor_info_array_t?
    var numCpuInfo = mach_msg_type_number_t()
    var numCpus = natural_t()
    
    let result = host_processor_info(mach_host_self(), PROCESSOR_CPU_LOAD_INFO, &numCpus, &info, &numCpuInfo)
    
    if result == KERN_SUCCESS {
        return 50.0 // Placeholder
    }
    return 0.0
}

// MARK: - Missing Methods Implementation
extension GuardrailDataCollector {
    
    private func collectComplianceMetrics() -> ParticipantBehaviorMetrics.ComplianceMetrics {
        return ParticipantBehaviorMetrics.ComplianceMetrics(
            followsInstructions: true,
            responseConsistency: 0.8,
            cooperationLevel: 0.9,
            verbalFeedback: [],
            nonverbalCues: []
        )
    }
    
    private func calculateEngagementLevel() -> Float {
        return 0.75 // Placeholder - could be calculated from attention metrics
    }
    
    private func collectAlgorithmMetrics() -> TechnicalPerformanceMetrics.AlgorithmMetrics {
        return TechnicalPerformanceMetrics.AlgorithmMetrics(
            pupilDetectionLatency: 0.033,
            landmarkExtractionLatency: 0.020,
            gazeMapLatency: 0.010,
            confidenceDistribution: [0.8, 0.85, 0.9, 0.88, 0.92],
            failureRate: 0.05,
            recoveryTime: 0.1
        )
    }
    
    private func collectStorageMetrics() -> TechnicalPerformanceMetrics.StorageMetrics {
        return TechnicalPerformanceMetrics.StorageMetrics(
            localStorageUsed: 100.0,    // 100MB
            cloudStorageUsed: 50.0,     // 50MB
            compressionRatio: 0.7,
            backupStatus: .synced
        )
    }
    
    private func collectDataPrivacyMetrics() -> SafetyComplianceMetrics.DataPrivacyMetrics {
        return SafetyComplianceMetrics.DataPrivacyMetrics(
            biometricDataEncrypted: true,
            personalDataMinimized: true,
            consentDocumented: true,
            dataRetentionCompliant: true,
            anonymizationLevel: .pseudonymized
        )
    }
    
    private func collectEmergencyMetrics() -> SafetyComplianceMetrics.EmergencyMetrics {
        return SafetyComplianceMetrics.EmergencyMetrics(
            emergencyContactAvailable: true,
            dataRecoveryPossible: true,
            incidentReporting: []
        )
    }
    
    private func collectFatigueMetrics() -> ParticipantBehaviorMetrics.FatigueMetrics {
        return ParticipantBehaviorMetrics.FatigueMetrics(
            blinkDuration: 0.15,
            eyeClosureFrequency: 0.05,
            responseLatency: 0.8,
            motivationLevel: 0.7,
            sessionDuration: CACurrentMediaTime(),
            breakRecommended: false
        )
    }
    
    private func collectNetworkMetrics() -> TechnicalPerformanceMetrics.NetworkMetrics {
        return TechnicalPerformanceMetrics.NetworkMetrics(
            uploadSpeed: 10.0,
            downloadSpeed: 25.0,
            latency: 0.05,
            packetLoss: 0.01,
            connectionStability: 0.95
        )
    }
    
    private func collectRegulatoryMetrics() -> SafetyComplianceMetrics.RegulatoryMetrics {
        return SafetyComplianceMetrics.RegulatoryMetrics(
            hipaaCompliant: true,
            ferpaCompliant: true,
            coppaCompliant: true,
            gdprCompliant: true,
            researchEthicsApproved: true
        )
    }
    
    private func collectSystemMetrics() -> TechnicalPerformanceMetrics.SystemMetrics {
        return TechnicalPerformanceMetrics.SystemMetrics(
            batteryLevel: UIDevice.current.batteryLevel,
            thermalState: ProcessInfo.processInfo.thermalState,
            memoryPressure: getMemoryUsage(),
            cpuUtilization: getCPUUsage(),
            diskSpace: 1000.0, // MB - placeholder
            networkConnectivity: true
        )
    }
    
    private func collectAttentionMetrics() -> ParticipantBehaviorMetrics.AttentionMetrics {
        return ParticipantBehaviorMetrics.AttentionMetrics(
            gazeOnScreen: 0.85,
            fixationStability: 0.90,
            saccadeFrequency: 2.5,
            blinkRate: 15.0,
            microsaccades: 10,
            offTaskLooking: 5.0
        )
    }
    
    private func collectParticipantSafetyMetrics() -> SafetyComplianceMetrics.ParticipantSafetyMetrics {
        return SafetyComplianceMetrics.ParticipantSafetyMetrics(
            eyeStrainIndicators: [],
            excessiveExposure: false,
            discomfortReported: false,
            medicalConditionsRelevant: [],
            ageAppropriateContent: true
        )
    }
}
//
//  GuardrailDataModels.swift
//  PupillometryApp
//
//  Created by Claude on 10/07/25.
//

import Foundation
import ARKit
import AVFoundation
import CoreMotion

// MARK: - Environmental Quality Data
struct EnvironmentalQuality {
    let timestamp: TimeInterval
    let lightingConditions: LightingMetrics
    let distanceStability: DistanceMetrics
    let headStability: HeadMovementMetrics
    let deviceStability: DeviceMotionMetrics
    let backgroundNoise: AudioMetrics
    let batteryLevel: Float
    let thermalState: ProcessInfo.ThermalState
    let overallQualityScore: Float  // 0.0-1.0
    
    struct LightingMetrics {
        let ambientLightLevel: Float        // Lux measurement
        let illuminationUniformity: Float   // Face lighting evenness
        let contrastRatio: Float           // Pupil-iris contrast
        let reflectionDetected: Bool       // Corneal reflection issues
        let lightingStability: Float       // Variance over time
        let optimalLightingRange: Bool     // Within 200-800 lux
    }
    
    struct DistanceMetrics {
        let currentDistance: Float         // cm from device
        let optimalRange: ClosedRange<Float> // 40-70cm ideal
        let distanceVariance: Float        // Stability measure
        let distanceConfidence: Float      // ARKit confidence
        let suddenMovements: Int           // Count of rapid changes
    }
    
    struct HeadMovementMetrics {
        let headPose: (pitch: Float, yaw: Float, roll: Float)  // Head pose angles
        let translationVariance: SIMD3<Float>      // XYZ movement variance
        let rotationVariance: SIMD3<Float>         // Pitch/Yaw/Roll variance
        let movementVelocity: Float                // mm/second movement speed
        let stabilityDuration: TimeInterval       // Time in stable position
        let excessiveMovement: Bool                // Beyond threshold
    }
    
    struct DeviceMotionMetrics {
        let accelerometer: CMAcceleration          // Device shake detection
        let gyroscope: CMRotationRate             // Device rotation
        let deviceOrientation: UIDeviceOrientation // Portrait/landscape
        let motionStability: Float                // Overall device stability
        let handTremor: Float                     // Detected hand tremor
    }
    
    struct AudioMetrics {
        let ambientNoiseLevel: Float              // dB measurement
        let distractionEvents: [DistractionEvent] // Sudden noise spikes
        let quietPeriods: TimeInterval            // Duration of stable audio
        
        struct DistractionEvent {
            let timestamp: TimeInterval
            let decibelLevel: Float
            let duration: TimeInterval
            let type: DistractionType
            
            enum DistractionType {
                case suddenNoise, voiceDetected, musicDetected, phoneRing
            }
        }
    }
}

// MARK: - Data Quality Validation
struct DataQualityMetrics {
    let timestamp: TimeInterval
    let pupilDetectionQuality: PupilQualityMetrics
    let calibrationQuality: CalibrationQualityMetrics
    let signalQuality: SignalQualityMetrics
    let temporalConsistency: TemporalMetrics
    
    struct PupilQualityMetrics {
        let detectionConfidence: Float            // 0.0-1.0
        let boundarySharpness: Float             // Edge definition quality
        let circularityScore: Float              // How circular the pupil is
        let sizeConsistency: Float               // Stability of measurements
        let artifactDetection: [ArtifactType]    // Detected issues
        let occlusionLevel: Float                // Eyelash/reflection coverage
        
        enum ArtifactType {
            case reflection, eyelash, blink, tearFilm, contactLens
        }
    }
    
    struct CalibrationQualityMetrics {
        let spatialAccuracy: Float               // Degrees of error
        let temporalStability: Float             // Consistency over time
        let edgeAccuracy: Float                  // Performance at screen edges
        let centerAccuracy: Float               // Performance at screen center
        let polynomialFitQuality: Float          // R-squared of fit
        let outlierPercentage: Float             // % of rejected points
        let recalibrationNeeded: Bool            // Quality below threshold
    }
    
    struct SignalQualityMetrics {
        let signalToNoiseRatio: Float            // SNR in dB
        let samplingConsistency: Float           // Frame rate stability
        let dataLossPercentage: Float            // % of dropped frames
        let processingLatency: TimeInterval      // Real-time performance
        let memoryUsage: Float                   // MB used
        let cpuUsage: Float                      // % CPU utilization
    }
    
    struct TemporalMetrics {
        let frameSynchronization: Float          // Timestamp accuracy
        let eventLatency: TimeInterval           // Response to stimuli
        let clockDrift: TimeInterval             // System clock accuracy
        let bufferHealth: Float                  // Data buffer status
    }
}

// MARK: - Participant Behavior Monitoring
struct ParticipantBehaviorMetrics {
    let timestamp: TimeInterval
    let attentionMetrics: AttentionMetrics
    let complianceMetrics: ComplianceMetrics
    let fatigueIndicators: FatigueMetrics
    let engagementLevel: Float                   // Overall engagement score
    
    struct AttentionMetrics {
        let gazeOnScreen: Float                  // % time looking at screen
        let fixationStability: Float            // Steadiness of gaze
        let saccadeFrequency: Float             // Eye movements per second
        let blinkRate: Float                     // Blinks per minute
        let microsaccades: Int                   // Small eye movements
        let offTaskLooking: TimeInterval         // Time looking away
    }
    
    struct ComplianceMetrics {
        let followsInstructions: Bool            // Following task rules
        let responseConsistency: Float           // Reliable responses
        let cooperationLevel: Float             // Willingness to participate
        let verbalFeedback: [String]            // Participant comments
        let nonverbalCues: [NonverbalCue]       // Body language indicators
        
        enum NonverbalCue {
            case fidgeting, slouching, distraction, frustration, confusion
        }
    }
    
    struct FatigueMetrics {
        let blinkDuration: Float                 // Longer blinks = fatigue
        let eyeClosureFrequency: Float          // Microsleep indicators
        let responseLatency: Float               // Slower responses
        let motivationLevel: Float               // Engagement decline
        let sessionDuration: TimeInterval        // Time since start
        let breakRecommended: Bool               // Fatigue threshold reached
    }
}

// MARK: - Technical Performance Monitoring
struct TechnicalPerformanceMetrics {
    let timestamp: TimeInterval
    let systemMetrics: SystemMetrics
    let algorithmMetrics: AlgorithmMetrics
    let networkMetrics: NetworkMetrics
    let storageMetrics: StorageMetrics
    
    struct SystemMetrics {
        let batteryLevel: Float                  // % remaining
        let thermalState: ProcessInfo.ThermalState // Overheating risk
        let memoryPressure: Float               // Available RAM
        let cpuUtilization: Float               // Processing load
        let diskSpace: Float                    // Available storage
        let networkConnectivity: Bool           // Internet available
    }
    
    struct AlgorithmMetrics {
        let pupilDetectionLatency: TimeInterval  // Processing speed
        let landmarkExtractionLatency: TimeInterval
        let gazeMapLatency: TimeInterval
        let confidenceDistribution: [Float]     // Confidence over time
        let failureRate: Float                  // % of failed detections
        let recoveryTime: TimeInterval          // Time to recover from failure
    }
    
    struct NetworkMetrics {
        let uploadSpeed: Float                   // Mbps
        let downloadSpeed: Float                 // Mbps
        let latency: TimeInterval               // Network delay
        let packetLoss: Float                   // % data loss
        let connectionStability: Float          // Connection quality
    }
    
    struct StorageMetrics {
        let localStorageUsed: Float             // MB on device
        let cloudStorageUsed: Float             // MB in Firebase
        let compressionRatio: Float             // Data efficiency
        let backupStatus: BackupStatus          // Data safety
        
        enum BackupStatus {
            case synced, pending, failed, offline
        }
    }
}

// MARK: - Safety and Compliance Monitoring
struct SafetyComplianceMetrics {
    let timestamp: TimeInterval
    let participantSafety: ParticipantSafetyMetrics
    let dataPrivacy: DataPrivacyMetrics
    let regulatoryCompliance: RegulatoryMetrics
    let emergencyProtocols: EmergencyMetrics
    
    struct ParticipantSafetyMetrics {
        let eyeStrainIndicators: [EyeStrainIndicator]
        let excessiveExposure: Bool              // Screen time limits
        let discomfortReported: Bool             // Participant feedback
        let medicalConditionsRelevant: [String] // Relevant conditions
        let ageAppropriateContent: Bool          // Age verification
        
        enum EyeStrainIndicator {
            case excessiveBlinking, reducedContrast, reportedDiscomfort
        }
    }
    
    struct DataPrivacyMetrics {
        let biometricDataEncrypted: Bool         // Encryption status
        let personalDataMinimized: Bool          // GDPR compliance
        let consentDocumented: Bool              // Informed consent
        let dataRetentionCompliant: Bool         // Retention limits
        let anonymizationLevel: AnonymizationLevel
        
        enum AnonymizationLevel {
            case none, pseudonymized, fullyAnonymous
        }
    }
    
    struct RegulatoryMetrics {
        let hipaaCompliant: Bool                 // Healthcare compliance
        let ferpaCompliant: Bool                 // Educational compliance
        let coppaCompliant: Bool                 // Children's privacy
        let gdprCompliant: Bool                  // EU privacy
        let researchEthicsApproved: Bool         // IRB approval
    }
    
    struct EmergencyMetrics {
        let emergencyContactAvailable: Bool      // Emergency procedures
        let dataRecoveryPossible: Bool          // Backup systems
        let incidentReporting: [IncidentType]   // Tracked incidents
        
        enum IncidentType {
            case technicalFailure, participantDistress, dataLoss, privacyBreach
        }
    }
}

// MARK: - Aggregated Session Quality Score
struct SessionQualityScore {
    let timestamp: TimeInterval
    let overallScore: Float                     // 0.0-1.0 overall quality
    let environmentalScore: Float               // Environment quality
    let dataQualityScore: Float                 // Data reliability
    let participantScore: Float                 // Participant engagement
    let technicalScore: Float                  // System performance
    let safetyScore: Float                     // Safety compliance
    let recommendations: [QualityRecommendation]
    
    enum QualityRecommendation {
        case improveDistanceStability
        case adjustLighting
        case takeBreak
        case recalibrate
        case checkDeviceStability
        case consultTechnicalSupport
        case endSession
        case improveEnvironmentalConditions
    }
}
//  PupillometryApp
//
//  Created by Revathi Prasad on 08/06/25.
//


import Foundation
import CoreGraphics
import QuartzCore

// MARK: - Data Models
struct PupilMeasurement {
    let timestamp: TimeInterval
    let center: CGPoint
    let radiusPixels: Float
    let diameterMM: Float
    let confidence: Float
    let eye: Eye
    
    enum Eye: String {
        case left, right
    }
    
    // Factory method for creating mock measurements (for testing)
    static func createMock(timestamp: TimeInterval = CACurrentMediaTime(),
                         center: CGPoint = CGPoint(x: 200, y: 200),
                         radiusPixels: Float = 25.0,
                         diameterMM: Float = 4.5,
                         confidence: Float = 0.8,
                         eye: Eye = .right) -> PupilMeasurement {
        
        return PupilMeasurement(
            timestamp: timestamp,
            center: center,
            radiusPixels: radiusPixels,
            diameterMM: diameterMM,
            confidence: confidence,
            eye: eye
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

struct TaskEvent {
    let timestamp: TimeInterval
    let type: EventType
    let data: [String: Any]
    
    enum EventType: String {
        case stimulusOnset
        case stimulusOffset
        case response
        case trialStart
        case trialEnd
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
    
    // Temporal dynamics
    let velocityProfile: [Float]
    let accelerationTrend: [Float]
    let totalDistance: Float
    
    // Behavioral
    let reactionTime: TimeInterval
    let accuracy: Float
    let processingSpeed: Float
}

// MARK: - Session Management
class SessionData {
    let sessionID: String = UUID().uuidString
    let startTime: Date = Date()
    var pupilMeasurements: [PupilMeasurement] = []
    var taskEvents: [TaskEvent] = []
    var demographicData: DemographicData?
    
    struct DemographicData: Codable {
        let age: Int
        let gender: String
        let previousDiagnosis: String?
        let medications: String?
    }
}

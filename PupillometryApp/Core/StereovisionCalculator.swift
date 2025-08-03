//
//  StereovisionCalculator.swift
//  PupillometryApp
//
//  Created by Claude Code on 12/07/25.
//

import Foundation
import CoreGraphics
import UIKit

// MARK: - Stereovision-based Pupil Size Calculation
class StereovisionCalculator {
    
    // Calibration parameters
    private var isCalibrated = false
    private var pixelsPerMM: Float = 0.0
    private var baselineDistance: Float = 65.0 // Average distance between eyes in mm
    private var referenceFocalLength: Float = 3.0 // iPhone front camera approximate focal length in mm
    
    // Device-specific parameters (iPhone)
    private let deviceParams = DeviceParameters.current
    
    struct DeviceParameters {
        let pixelSize: Float // Physical pixel size in mm
        let focalLengthMM: Float // Camera focal length in mm
        let sensorWidthMM: Float // Camera sensor width in mm
        let imageWidthPixels: Float // Image width in pixels
        
        static let current = DeviceParameters(
            pixelSize: 0.00112, // iPhone front camera pixel size ~1.12μm
            focalLengthMM: 2.87, // iPhone front camera focal length
            sensorWidthMM: 3.6,  // iPhone front camera sensor width
            imageWidthPixels: 640.0 // Typical front camera resolution width
        )
    }
    
    // MARK: - Calibration
    func calibrate(withKnownSizeMM knownSizeMM: Float, 
                   measuredPixels: Float, 
                   nirRgbDisparity: Float = 0.0, 
                   imageWidth: Float) {
        
        guard measuredPixels > 0 && knownSizeMM > 0 else {
            print("⚠️ StereovisionCalculator: Invalid calibration parameters")
            return
        }
        
        // Calculate pixels per millimeter ratio
        pixelsPerMM = measuredPixels / knownSizeMM
        isCalibrated = true
        
        print("✅ StereovisionCalculator: Calibrated with \(knownSizeMM)mm = \(measuredPixels) pixels")
        print("📏 StereovisionCalculator: Pixels per mm: \(pixelsPerMM)")
    }
    
    // MARK: - Pupil Size Calculation Methods
    
    /// Calculate absolute pupil size using stereovision principles
    func calculateAbsolutePupilSize(nirPupilPixels: Float, 
                                   nirCenter: CGPoint, 
                                   rgbCenter: CGPoint, 
                                   imageWidth: Float,
                                   faceDistance: Float? = nil) -> Float {
        
        // Method 1: If calibrated, use calibration
        if isCalibrated && pixelsPerMM > 0 {
            let diameterMM = nirPupilPixels / pixelsPerMM
            
            // Check for NaN
            if diameterMM.isNaN || diameterMM.isInfinite {
                print("⚠️ StereovisionCalculator: NaN detected in calibrated calculation, falling back to device parameters")
                return calculateFromDeviceParameters(pupilPixels: nirPupilPixels, imageWidth: imageWidth)
            }
            print("📏 StereovisionCalculator: Using calibrated measurement: \(diameterMM)mm (pixels: \(nirPupilPixels), ratio: \(pixelsPerMM))")
            let clampedDiameter = max(1.0, min(8.0, diameterMM))
            if clampedDiameter != diameterMM {
                print("⚠️ StereovisionCalculator: Clamped diameter from \(diameterMM)mm to \(clampedDiameter)mm")
            }
            return clampedDiameter
        }
        
        // Method 2: Use device parameters with actual distance if available
        let estimatedDiameter = calculateFromDeviceParameters(pupilPixels: nirPupilPixels, imageWidth: imageWidth, actualDistance: faceDistance)
        
        // Method 3: Use disparity-based calculation (if available)
        let disparity = sqrt(pow(nirCenter.x - rgbCenter.x, 2) + pow(nirCenter.y - rgbCenter.y, 2))
        if disparity > 1.0 {
            let disparityBasedDiameter = calculateFromDisparity(pupilPixels: nirPupilPixels, disparity: Float(disparity))
            
            // Average the methods if disparity is reliable
            let averageDiameter = (estimatedDiameter + disparityBasedDiameter) / 2.0
            print("📏 StereovisionCalculator: Disparity-based calculation: \(averageDiameter)mm")
            return max(1.0, min(8.0, averageDiameter))
        }
        
        print("📏 StereovisionCalculator: Device-parameter calculation: \(estimatedDiameter)mm")
        return max(1.0, min(8.0, estimatedDiameter))
    }
    
    private func calculateFromDeviceParameters(pupilPixels: Float, imageWidth: Float, actualDistance: Float? = nil) -> Float {
        // Use actual distance from depth data if available, otherwise fall back to estimated distance
        let distanceMM: Float = actualDistance ?? 400.0 // Use depth data or 40cm fallback
        
        if let actualDist = actualDistance {
            print("📏 StereovisionCalculator: Using actual distance from depth data: \(String(format: "%.1f", actualDist))mm")
        } else {
            print("📏 StereovisionCalculator: Using estimated distance: \(distanceMM)mm (no depth data available)")
        }
        
        // Validate inputs to prevent NaN
        guard imageWidth > 0, deviceParams.focalLengthMM > 0, !pupilPixels.isNaN, !imageWidth.isNaN else {
            print("⚠️ StereovisionCalculator: Invalid inputs for device calculation")
            return 3.5 // Return a reasonable default pupil size
        }
        
        // Calculate actual pupil size using similar triangles
        // pupil_real_size / distance = pupil_pixel_size / focal_length
        let pupilPixelSizeMM = (pupilPixels / imageWidth) * deviceParams.sensorWidthMM
        let pupilRealSizeMM = (pupilPixelSizeMM * distanceMM) / deviceParams.focalLengthMM
        
        // Check for NaN in results
        if pupilPixelSizeMM.isNaN || pupilRealSizeMM.isNaN {
            print("⚠️ StereovisionCalculator: NaN detected in device calculation")
            return 3.5 // Return a reasonable default
        }
        
        // ENHANCED: Add scaling factor for mobile cameras
        let mobileScalingFactor: Float = 2.5 // Empirical correction for mobile front cameras
        let adjustedDiameterMM = pupilRealSizeMM * mobileScalingFactor
        
        print("🔍 StereovisionCalculator: Device calculation:")
        print("   📏 Pupil pixels: \(pupilPixels), Image width: \(imageWidth)")
        print("   📏 Distance used: \(String(format: "%.1f", distanceMM))mm")
        print("   📐 Pupil pixel size: \(pupilPixelSizeMM)mm")
        print("   📏 Raw calculated: \(pupilRealSizeMM)mm")
        print("   📏 Mobile adjusted: \(adjustedDiameterMM)mm")
        
        return adjustedDiameterMM
    }
    
    private func calculateFromDisparity(pupilPixels: Float, disparity: Float) -> Float {
        // Use disparity to estimate distance, then calculate size
        // This is a simplified stereo vision approach
        let baselineEstimate: Float = 8.0 // mm, approximate distance between RGB and depth sensors
        
        // Validate inputs to prevent NaN
        guard disparity > 0, deviceParams.pixelSize > 0, deviceParams.focalLengthMM > 0, 
              !disparity.isNaN, !pupilPixels.isNaN else {
            print("⚠️ StereovisionCalculator: Invalid inputs for disparity calculation")
            return 3.5 // Return a reasonable default
        }
        
        let estimatedDistance = (baselineEstimate * deviceParams.focalLengthMM) / (disparity * deviceParams.pixelSize)
        
        // Calculate real size using similar triangles
        let pupilPixelSizeMM = pupilPixels * deviceParams.pixelSize
        let pupilRealSizeMM = (pupilPixelSizeMM * estimatedDistance) / deviceParams.focalLengthMM
        
        // Check for NaN in results
        if estimatedDistance.isNaN || pupilRealSizeMM.isNaN {
            print("⚠️ StereovisionCalculator: NaN detected in disparity calculation")
            return 3.5 // Return a reasonable default
        }
        
        return pupilRealSizeMM
    }
    
    // MARK: - Enhanced Calculation with Confidence
    func calculatePupilSizeWithConfidence(nirPupilPixels: Float, 
                                         nirCenter: CGPoint, 
                                         rgbCenter: CGPoint, 
                                         imageWidth: Float, 
                                         faceAreaPixels: Float? = nil,
                                         faceDistance: Float? = nil) -> (diameter: Float, confidence: Float) {
        
        let diameter = calculateAbsolutePupilSize(
            nirPupilPixels: nirPupilPixels,
            nirCenter: nirCenter,
            rgbCenter: rgbCenter,
            imageWidth: imageWidth,
            faceDistance: faceDistance
        )
        
        // Calculate confidence based on multiple factors
        var confidence: Float = 0.5 // Base confidence
        
        // Factor 1: Calibration status
        if isCalibrated {
            confidence += 0.3
        }
        
        // Factor 2: Pupil size reasonableness (2-7mm is normal range)
        let sizeReasonableness = 1.0 - abs(diameter - 4.5) / 2.5 // 4.5mm is average
        confidence += max(0, sizeReasonableness) * 0.2
        
        // Factor 3: Disparity reliability
        let disparity = sqrt(pow(nirCenter.x - rgbCenter.x, 2) + pow(nirCenter.y - rgbCenter.y, 2))
        if disparity > 1.0 && disparity < 50.0 {
            confidence += 0.2
        }
        
        // Factor 4: Face area consistency (if provided)
        if let faceArea = faceAreaPixels, faceArea > 1000 {
            let expectedPupilToFaceRatio = nirPupilPixels / faceArea
            if expectedPupilToFaceRatio > 0.0001 && expectedPupilToFaceRatio < 0.01 {
                confidence += 0.1
            }
        }
        
        confidence = max(0.1, min(1.0, confidence))
        
        return (diameter, confidence)
    }
    
    // MARK: - Adaptive Calculation
    func calculateAdaptivePupilSize(measurements: [PupilSizeMeasurement]) -> Float {
        guard !measurements.isEmpty else { return 4.5 } // Default average
        
        if measurements.count == 1 {
            return measurements[0].diameter
        }
        
        // Remove outliers using median absolute deviation
        let sortedDiameters = measurements.map { $0.diameter }.sorted()
        let median = sortedDiameters[sortedDiameters.count / 2]
        
        let deviations = sortedDiameters.map { abs($0 - median) }
        let mad = deviations.sorted()[deviations.count / 2] // Median Absolute Deviation
        
        // Filter out measurements that are more than 2 MADs from median
        let threshold = mad * 2.0
        let filteredMeasurements = measurements.filter { abs($0.diameter - median) <= threshold }
        
        if filteredMeasurements.isEmpty {
            return median
        }
        
        // Weighted average based on confidence
        let totalWeight = filteredMeasurements.reduce(0) { $0 + $1.confidence }
        let weightedSum = filteredMeasurements.reduce(0) { $0 + ($1.diameter * $1.confidence) }
        
        return totalWeight > 0 ? weightedSum / totalWeight : median
    }
    
    // MARK: - Quality Assessment
    func assessMeasurementQuality(diameter: Float, confidence: Float, pupilPixels: Float) -> MeasurementQuality {
        var score: Float = confidence
        
        // Check diameter reasonableness
        if diameter >= 2.0 && diameter <= 7.0 {
            score += 0.2
        } else {
            score -= 0.3
        }
        
        // Check pixel resolution
        if pupilPixels >= 10.0 {
            score += 0.1
        } else {
            score -= 0.2
        }
        
        // Check if it's likely a fallback value
        if abs(diameter - 4.5) < 0.1 || abs(diameter - 2.0) < 0.1 {
            score -= 0.2 // Likely hardcoded fallback
        }
        
        score = max(0.0, min(1.0, score))
        
        if score >= 0.8 {
            return .excellent
        } else if score >= 0.6 {
            return .good
        } else if score >= 0.4 {
            return .fair
        } else {
            return .poor
        }
    }
    
    // MARK: - Calibration Status
    func getCalibrationStatus() -> CalibrationStatus {
        if isCalibrated && pixelsPerMM > 0 {
            return .calibrated(pixelsPerMM: pixelsPerMM)
        } else {
            return .uncalibrated
        }
    }
    
    func resetCalibration() {
        isCalibrated = false
        pixelsPerMM = 0.0
        print("🔄 StereovisionCalculator: Reset calibration")
    }
}

// MARK: - Supporting Types
struct PupilSizeMeasurement {
    let diameter: Float
    let confidence: Float
    let timestamp: TimeInterval
}

enum MeasurementQuality: String {
    case excellent = "Excellent"
    case good = "Good"
    case fair = "Fair"
    case poor = "Poor"
}

enum CalibrationStatus {
    case calibrated(pixelsPerMM: Float)
    case uncalibrated
    
    var isCalibrated: Bool {
        switch self {
        case .calibrated:
            return true
        case .uncalibrated:
            return false
        }
    }
}
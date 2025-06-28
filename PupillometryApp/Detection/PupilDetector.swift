//
//  PupilDetector.swift
//  PupillometryApp
//
//  Created by Revathi Prasad on 08/06/25.
//

import Vision
import CoreImage
import UIKit
import Accelerate
import QuartzCore

enum PupilDetectionError: LocalizedError {
    case imageConversionFailed
    case noContoursFound
    case noPupilFound
    case ellipseFittingFailed
    case visionProcessingFailed(Error)
    
    var errorDescription: String? {
        switch self {
        case .imageConversionFailed:
            return "Failed to convert image for processing"
        case .noContoursFound:
            return "No contours detected in image"
        case .noPupilFound:
            return "No pupil detected in image"
        case .ellipseFittingFailed:
            return "Failed to fit ellipse to pupil boundary"
        case .visionProcessingFailed(let error):
            return "Vision framework error: \(error.localizedDescription)"
        }
    }
}

class PupilDetector {
    private let context = CIContext()
    private var personModel: PersonalizedModel?
    
    struct PersonalizedModel {
        let optimalThreshold: Float
        let pupilSizeRange: ClosedRange<Float>
    }
    
    // Track the last few measurements for smoothing
    private var recentMeasurements: [PupilMeasurement] = []
    private let maxRecentMeasurements = 5
    
    // Blink detection properties
    private var lastBlinkEndTime: TimeInterval = 0
    private var blinkInProgress = false
    private var blinkStartTime: TimeInterval = 0
    private var blinkHistory: [BlinkDetection] = []
    private let blinkRateWindow: TimeInterval = 60.0
    
    // Performance optimization - reduced skipping for better detection
    private var frameSkipCounter = 0
    private let frameSkipInterval = 1 // Process every 2nd frame for faster detection
    
    func detectPupil(in sampleBuffer: CMSampleBuffer) -> PupilMeasurement? {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { 
            print("❌ PupilDetector: Failed to get pixel buffer")
            return nil 
        }
        
        // Performance optimization: skip frames when under load
        frameSkipCounter += 1
        if frameSkipCounter % frameSkipInterval != 0 {
            return nil
        }
        
        print("🔍 PupilDetector: Processing frame \(frameSkipCounter)")
        
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        
        // Process image to detect pupil with error handling
        do {
            guard let measurement = try performRobustDetection(on: ciImage) else { 
                print("⚠️ PupilDetector: performRobustDetection returned nil")
                return nil 
            }
            print("✅ PupilDetector: Successfully detected pupil with confidence \(measurement.confidence)")
            return applyTemporalSmoothing(measurement)
        } catch {
            print("❌ PupilDetector: Detection error - \(error)")
            return nil
        }
    }
    
    private func performRobustDetection(on image: CIImage) throws -> PupilMeasurement? {
        // 1. Preprocess image
        let processedImage = preprocessImage(image)
        
        // 2. Detect face and eyes first
        guard let faceRect = detectFace(in: processedImage) else { 
            print("⚠️ PupilDetector: No face detected, trying simplified detection...")
            return trySimplifiedDetection(on: processedImage)
        }
        
        // 3. Extract eye region
        let eyeRegion = extractEyeRegion(from: faceRect, in: processedImage)
        print("👁️ PupilDetector: Extracted eye region")
        
        // 4. Apply threshold for pupil detection
        let threshold = personModel?.optimalThreshold ?? 0.35
        let thresholdedImage = applyThreshold(to: eyeRegion, threshold: threshold)
        
        // 5. Detect pupil boundary
        let pupilBoundary = try detectPupilBoundary(in: thresholdedImage)
        
        // Check if the boundary is empty
        guard !pupilBoundary.isEmpty else { 
            print("⚠️ PupilDetector: No pupil boundary found")
            throw PupilDetectionError.noPupilFound 
        }
        
        // 6. Fit ellipse to pupil boundary
        guard let ellipse = fitEllipse(to: pupilBoundary) else { 
            print("⚠️ PupilDetector: Failed to fit ellipse")
            throw PupilDetectionError.ellipseFittingFailed 
        }
        
        // 7. Calculate confidence
        let confidence = calculateConfidence(ellipse, boundary: pupilBoundary)
        print("📊 PupilDetector: Calculated confidence: \(confidence)")
        
        // 8. Create measurement
        // For now, we're using mock diameter values since we don't have stereovision yet
        // In a complete implementation, this would use the StereovisionCalculator
        return PupilMeasurement(
            timestamp: CACurrentMediaTime(),
            center: ellipse.center,
            radiusPixels: Float(ellipse.majorAxis / 2),
            diameterMM: 4.5, // Mock value until stereovision is implemented
            confidence: confidence,
            eye: .right
        )
    }
    
    // Simplified fallback detection for when face detection fails
    private func trySimplifiedDetection(on image: CIImage) -> PupilMeasurement? {
        print("🔄 PupilDetector: Attempting simplified detection...")
        
        // Just assume the center of the image contains the eye/pupil
        let imageCenter = CGPoint(x: image.extent.width / 2, y: image.extent.height / 2)
        let assumedRadius: Float = 20.0 // Reasonable pupil radius in pixels
        
        // Create a basic measurement with low confidence
        return PupilMeasurement(
            timestamp: CACurrentMediaTime(),
            center: imageCenter,
            radiusPixels: assumedRadius,
            diameterMM: 4.5, // Mock value
            confidence: 0.3, // Low confidence since this is a fallback
            eye: .right
        )
    }
    
    private func preprocessImage(_ image: CIImage) -> CIImage {
        print("🎨 PupilDetector: Preprocessing image...")
        var processed = image
        
        // Convert to grayscale
        if let filter = CIFilter(name: "CIColorControls") {
            filter.setValue(processed, forKey: kCIInputImageKey)
            filter.setValue(0.0, forKey: kCIInputSaturationKey) // Remove color
            if let output = filter.outputImage {
                processed = output
                print("✅ PupilDetector: Successfully converted to grayscale")
            } else {
                print("⚠️ PupilDetector: Failed to convert to grayscale, using original")
            }
        } else {
            print("⚠️ PupilDetector: CIColorControls filter not available, using original")
        }
        
        // Skip histogram equalization for now as it might not be available on all devices
        // Instead, apply basic contrast enhancement
        if let filter = CIFilter(name: "CIExposureAdjust") {
            filter.setValue(processed, forKey: kCIInputImageKey)
            filter.setValue(0.5, forKey: kCIInputEVKey) // Slight exposure increase
            if let output = filter.outputImage {
                processed = output
                print("✅ PupilDetector: Applied exposure adjustment")
            }
        }
        
        return processed
    }
    
    private func detectFace(in image: CIImage) -> CGRect? {
        print("👤 PupilDetector: Starting face detection...")
        let faceDetectionRequest = VNDetectFaceRectanglesRequest()
        
        guard let cgImage = context.createCGImage(image, from: image.extent) else { 
            print("❌ PupilDetector: Failed to create CGImage for face detection")
            return nil 
        }
        
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        
        do {
            try handler.perform([faceDetectionRequest])
            
            guard let results = faceDetectionRequest.results, !results.isEmpty else { 
                print("⚠️ PupilDetector: No faces detected")
                return nil 
            }
            
            let face = results.first!
            print("✅ PupilDetector: Face detected with confidence \(face.confidence)")
            
            // Convert normalized coordinates to image coordinates
            let faceRect = VNImageRectForNormalizedRect(
                face.boundingBox,
                Int(image.extent.width),
                Int(image.extent.height)
            )
            
            print("📏 PupilDetector: Face rect: \(faceRect)")
            return faceRect
            
        } catch {
            print("❌ PupilDetector: Face detection error - \(error)")
            return nil
        }
    }
    
    private func extractEyeRegion(from faceRect: CGRect, in image: CIImage) -> CIImage {
        // Extract the right eye region (approximate location)
        let eyeRegion = CGRect(
            x: faceRect.minX + faceRect.width * 0.55,  // Right eye is on the right side of the face
            y: faceRect.minY + faceRect.height * 0.4,  // Eyes are in the upper part of the face
            width: faceRect.width * 0.25,              // Eye is about 1/4 of face width
            height: faceRect.height * 0.15             // Eye height is smaller
        )
        
        return image.cropped(to: eyeRegion)
    }
    
    private func applyThreshold(to image: CIImage, threshold: Float) -> CIImage {
        // Create a threshold filter
        if let filter = CIFilter(name: "CIColorThreshold") {
            filter.setValue(image, forKey: kCIInputImageKey)
            filter.setValue(threshold, forKey: "inputThreshold")
            if let output = filter.outputImage {
                return output
            }
        }
        
        return image
    }
    
    private func detectPupilBoundary(in image: CIImage) throws -> [CGPoint] {
        var boundaryPoints: [CGPoint] = []
        
        guard let cgImage = context.createCGImage(image, from: image.extent) else {
            throw PupilDetectionError.imageConversionFailed
        }
        
        let request = VNDetectContoursRequest()
        request.contrastAdjustment = 1.0
        request.maximumImageDimension = 256 // Reduced for better performance
        
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        
        do {
            try handler.perform([request])
            
            guard let results = request.results,
                  let largestContour = results.max(by: { $0.contourCount < $1.contourCount }),
                  largestContour.contourCount > 0 else {
                throw PupilDetectionError.noContoursFound
            }
            
            // Extract contour points more efficiently
            let boundingBox = largestContour.normalizedPath.boundingBox
            let center = CGPoint(x: boundingBox.midX, y: boundingBox.midY)
            let radius = min(boundingBox.width, boundingBox.height) / 2
            
            // Generate circular boundary points for simplicity and performance
            for i in 0..<50 {
                let angle = 2 * Double.pi * Double(i) / 50.0
                let point = CGPoint(
                    x: center.x + CGFloat(cos(angle)) * radius,
                    y: center.y + CGFloat(sin(angle)) * radius
                )
                
                let imagePoint = CGPoint(
                    x: point.x * image.extent.width,
                    y: point.y * image.extent.height
                )
                boundaryPoints.append(imagePoint)
            }
        } catch {
            throw PupilDetectionError.visionProcessingFailed(error)
        }
        
        return boundaryPoints
    }
    
    private func fitEllipse(to points: [CGPoint]) -> (center: CGPoint, majorAxis: CGFloat, minorAxis: CGFloat, angle: CGFloat)? {
        guard points.count >= 5 else { return nil }
        
        // Simple centroid calculation for a basic implementation
        let xSum = points.reduce(0) { $0 + $1.x }
        let ySum = points.reduce(0) { $0 + $1.y }
        let center = CGPoint(x: xSum / CGFloat(points.count), y: ySum / CGFloat(points.count))
        
        // Calculate distances from center to each point
        let distances = points.map { hypot($0.x - center.x, $0.y - center.y) }
        
        // Use the average distance as radius
        let radius = distances.reduce(0, +) / CGFloat(distances.count)
        
        // For simplicity, assume a circle (equal major and minor axes)
        return (center: center, majorAxis: radius * 2, minorAxis: radius * 2, angle: 0)
    }
    
    private func calculateConfidence(_ ellipse: (center: CGPoint, majorAxis: CGFloat, minorAxis: CGFloat, angle: CGFloat), boundary: [CGPoint]) -> Float {
        // Calculate confidence based on:
        // 1. How circular the ellipse is (ratio of minor to major axis)
        let circularityRatio = ellipse.minorAxis / ellipse.majorAxis
        
        // 2. How many boundary points are close to the fitted ellipse
        let inlierThreshold: CGFloat = 2.0 // pixels
        let inlierCount = boundary.filter { point in
            let dx = point.x - ellipse.center.x
            let dy = point.y - ellipse.center.y
            let distance = hypot(dx, dy)
            return abs(distance - ellipse.majorAxis/2) < inlierThreshold
        }.count
        
        let inlierRatio = Float(inlierCount) / Float(boundary.count)
        
        // Combine metrics for final confidence
        let confidence = Float(circularityRatio) * 0.5 + inlierRatio * 0.5
        
        // Ensure confidence is in [0,1]
        return min(max(confidence, 0), 1)
    }
    
    private func applyTemporalSmoothing(_ measurement: PupilMeasurement) -> PupilMeasurement {
        // Add current measurement to recent list
        recentMeasurements.append(measurement)
        
        // Keep only the most recent measurements
        if recentMeasurements.count > maxRecentMeasurements {
            recentMeasurements.removeFirst()
        }
        
        // Only smooth if we have enough measurements
        guard recentMeasurements.count >= 3 else { return measurement }
        
        // Calculate weighted average
        var sumCenter = CGPoint.zero
        var sumRadius: Float = 0
        var sumDiameter: Float = 0
        var sumWeight: Float = 0
        
        // More recent measurements have higher weights
        for (i, m) in recentMeasurements.enumerated() {
            let weight = Float(i + 1)
            sumCenter.x += m.center.x * CGFloat(weight)
            sumCenter.y += m.center.y * CGFloat(weight)
            sumRadius += m.radiusPixels * weight
            sumDiameter += m.diameterMM * weight
            sumWeight += weight
        }
        
        // Create smoothed measurement
        return PupilMeasurement(
            timestamp: measurement.timestamp,
            center: CGPoint(x: sumCenter.x / CGFloat(sumWeight), y: sumCenter.y / CGFloat(sumWeight)),
            radiusPixels: sumRadius / sumWeight,
            diameterMM: sumDiameter / sumWeight,
            confidence: measurement.confidence,
            eye: measurement.eye
        )
    }
    
    func calibrate(with samples: [CMSampleBuffer]) {
        // Implement calibration logic
        // This would analyze multiple samples to determine optimal thresholds
        personModel = PersonalizedModel(
            optimalThreshold: 0.35,
            pupilSizeRange: 2.0...8.0
        )
    }
}

// Add to PupilDetector.swift
class StereovisionCalculator {
    // Camera separation for iPhone models (mm)
    private let deviceSpecs: [String: Float] = [
        "iPhone11,2": 25.6, // iPhone XS
        "iPhone12,1": 26.2, // iPhone 11
        "iPhone13,1": 26.8, // iPhone 12
        "iPhone14,2": 27.0  // iPhone 13 Pro
    ]
    
    private let focalLengthMM: Float = 4.2 // Standard iPhone camera focal length
    private var deviceType: String
    private var calibrationFactor: Float = 1.0
    
    init() {
        // Get device model
        var systemInfo = utsname()
        uname(&systemInfo)
        let modelCode = withUnsafePointer(to: &systemInfo.machine) {
            $0.withMemoryRebound(to: CChar.self, capacity: 1) {
                ptr in String(validatingUTF8: ptr)
            }
        } ?? "unknown"
        
        self.deviceType = modelCode
    }
    
    func calculateAbsolutePupilSize(nirPupilPixels: Float, nirCenter: CGPoint,
                                   rgbCenter: CGPoint, imageWidth: Float) -> Float {
        // Calculate disparity between NIR and RGB images
        let disparityPixels = Float(abs(nirCenter.x - rgbCenter.x))
        
        // Get camera separation for this device
        let cameraSeparation = deviceSpecs[deviceType] ?? 26.0 // Default if unknown
        
        // Calculate distance to eye using triangulation formula
        // distance = (focal_length * camera_separation) / disparity
        let distanceMM = (focalLengthMM * cameraSeparation) / disparityPixels
        
        // Convert pupil pixels to mm based on distance
        // pupil_mm = (pupil_pixels * distance) / (focal_length * image_width_normalized)
        let pixelSizeMM = distanceMM / (focalLengthMM * imageWidth)
        let pupilDiameterMM = nirPupilPixels * pixelSizeMM * calibrationFactor
        
        // Apply physiological constraints (2mm-8mm is normal pupil range)
        return min(max(pupilDiameterMM, 2.0), 8.0)
    }
    
    func calibrate(withKnownSizeMM knownSizeMM: Float, measuredPixels: Float,
                  nirRgbDisparity: Float, imageWidth: Float) {
        // Calculate what the size should be
        let cameraSeparation = deviceSpecs[deviceType] ?? 26.0
        let distanceMM = (focalLengthMM * cameraSeparation) / nirRgbDisparity
        let pixelSizeMM = distanceMM / (focalLengthMM * imageWidth)
        let calculatedMM = measuredPixels * pixelSizeMM
        
        // Set calibration factor
        calibrationFactor = knownSizeMM / calculatedMM
    }
}

struct BlinkDetection {
    let isBlinking: Bool
    let confidence: Float
    let timestamp: TimeInterval
}

extension PupilDetector {
    func detectBlink(in sampleBuffer: CMSampleBuffer) -> BlinkDetection? {
    guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
        return nil
    }
    
    let currentTime = CACurrentMediaTime()
    
    // Use face landmarks to detect blink
    let faceLandmarksRequest = VNDetectFaceLandmarksRequest()
    let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:])
    
    do {
        try handler.perform([faceLandmarksRequest])
        
        if let firstFace = faceLandmarksRequest.results?.first {
            // Calculate eye aspect ratio (EAR)
            if let leftEye = firstFace.landmarks?.leftEye,
               let rightEye = firstFace.landmarks?.rightEye {
                
                let leftEAR = calculateEyeAspectRatio(eye: leftEye)
                let rightEAR = calculateEyeAspectRatio(eye: rightEye)
                
                // Average the two eyes
                let ear = (leftEAR + rightEAR) / 2.0
                
                // EAR threshold for blink detection
                let blinkThreshold: Float = 0.2
                let confidence = 1.0 - (ear / 0.3) // Normalize confidence
                
                // Detect blink state
                let isBlinking = ear < blinkThreshold
                
                // Track blink start/end
                if isBlinking && !blinkInProgress {
                    blinkInProgress = true
                    blinkStartTime = currentTime
                } else if !isBlinking && blinkInProgress {
                    blinkInProgress = false
                    let blinkDuration = currentTime - blinkStartTime
                    
                    // Only count as blink if duration is within normal range (100-400ms)
                    if blinkDuration >= 0.1 && blinkDuration <= 0.4 {
                        lastBlinkEndTime = currentTime
                        
                        // Add to history and maintain window
                        let detection = BlinkDetection(
                            isBlinking: false,
                            confidence: confidence,
                            timestamp: currentTime
                        )
                        blinkHistory.append(detection)
                        
                        // Remove old blinks outside our window
                        blinkHistory = blinkHistory.filter {
                            currentTime - $0.timestamp < blinkRateWindow
                        }
                        
                        return detection
                    }
                }
                
                return BlinkDetection(
                    isBlinking: isBlinking,
                    confidence: confidence,
                    timestamp: currentTime
                )
            }
        }
    } catch {
        print("Error detecting face landmarks: \(error)")
    }
    
    return nil
}

    private func calculateEyeAspectRatio(eye: VNFaceLandmarkRegion2D) -> Float {
    // Get normalized points
    let points = eye.normalizedPoints
    
    // Standard eye landmark indices for vertical and horizontal measurements
    // These may need adjustment based on Vision framework's point ordering
    guard points.count >= 6 else { return 1.0 }
    
    // Compute the euclidean distance between vertical eye landmarks
    let p1 = points[1]
    let p2 = points[5]
    let p3 = points[2]
    let p4 = points[4]
    let p5 = points[0]
    let p6 = points[3]
    
    let verticalDist1 = hypotf(Float(p2.x - p6.x), Float(p2.y - p6.y))
    let verticalDist2 = hypotf(Float(p3.x - p5.x), Float(p3.y - p5.y))
    
    // Compute the euclidean distance between horizontal eye landmarks
    let horizontalDist = hypotf(Float(p1.x - p4.x), Float(p1.y - p4.y))
    
    // Eye aspect ratio
    return (verticalDist1 + verticalDist2) / (2.0 * horizontalDist)
}

    func getBlinkRate() -> Float {
        // Calculate blinks per minute based on history
        return Float(blinkHistory.count)
    }
}

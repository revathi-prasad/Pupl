//
//  LandmarkExtractor.swift
//  PupillometryApp
//
//  Created by Claude on 10/07/25.
//

import Foundation
import Vision
import CoreImage
import UIKit
import AVFoundation
import ImageIO


// MARK: - Engineering Overlay Data Structures

// Helper for encoding CGAffineTransform
struct CodableAffineTransform: Codable {
    let a, b, c, d, tx, ty: CGFloat
    
    init(_ transform: CGAffineTransform) {
        self.a = transform.a
        self.b = transform.b
        self.c = transform.c
        self.d = transform.d
        self.tx = transform.tx
        self.ty = transform.ty
    }
    
    var cgAffineTransform: CGAffineTransform {
        return CGAffineTransform(a: a, b: b, c: c, d: d, tx: tx, ty: ty)
    }
}

// Helper for encoding CGPoint
struct CodablePoint: Codable {
    let x, y: CGFloat
    
    init(_ point: CGPoint) {
        self.x = point.x
        self.y = point.y
    }
    
    var cgPoint: CGPoint {
        return CGPoint(x: x, y: y)
    }
}

// Helper for encoding CGSize
struct CodableSize: Codable {
    let width, height: CGFloat
    
    init(_ size: CGSize) {
        self.width = size.width
        self.height = size.height
    }
    
    var cgSize: CGSize {
        return CGSize(width: width, height: height)
    }
}

// Helper for encoding CGRect
struct CodableRect: Codable {
    let x, y, width, height: CGFloat
    
    init(_ rect: CGRect) {
        self.x = rect.origin.x
        self.y = rect.origin.y
        self.width = rect.size.width
        self.height = rect.size.height
    }
    
    var cgRect: CGRect {
        return CGRect(x: x, y: y, width: width, height: height)
    }
}

struct LandmarkOverlayData: Codable {
    let timestamp: TimeInterval
    let frameNumber: Int
    
    // Image information
    let originalImageSize: CodableSize
    let capturedImageSize: CodableSize
    let imageFilename: String
    
    // Coordinate transformation data
    let visionToImageScale: CodablePoint
    let coordinateOriginTransform: CodableAffineTransform
    let orientationTransform: UInt32  // CGImagePropertyOrientation.rawValue
    let mirrorTransform: Bool
    
    // Face detection data
    let faceRect: CodableRect  // In final image coordinates
    let faceConfidence: Float
    let faceBoundingBoxNormalized: CodableRect  // Original Vision coordinates (0-1)
    
    // Eye region data
    let eyeRegionRect: CodableRect  // In final image coordinates
    let eyeRegionScale: CGFloat
    let preferredEye: String  // EyePreference as string
    
    // Landmark points (in final image coordinates)
    let leftEyeLandmarks: [CodablePoint]
    let rightEyeLandmarks: [CodablePoint]
    let leftIrisLandmarks: [CodablePoint]
    let rightIrisLandmarks: [CodablePoint]
    let noseLandmarks: [CodablePoint]
    let mouthLandmarks: [CodablePoint]
    let jawlineLandmarks: [CodablePoint]
    let eyebrowLandmarks: [CodablePoint]
    
    // Landmark points (in original Vision normalized coordinates)
    let leftEyeLandmarksNormalized: [CodablePoint]
    let rightEyeLandmarksNormalized: [CodablePoint]
    let leftIrisLandmarksNormalized: [CodablePoint]
    let rightIrisLandmarksNormalized: [CodablePoint]
    let noseLandmarksNormalized: [CodablePoint]
    let mouthLandmarksNormalized: [CodablePoint]
    let jawlineLandmarksNormalized: [CodablePoint]
    let eyebrowLandmarksNormalized: [CodablePoint]
    
    // Engineering metadata
    let processingNotes: [String]
    let qualityMetrics: LandmarkQualityMetrics
}

struct LandmarkQualityMetrics: Codable {
    let landmarkDetectionConfidence: Float
    let imageSharpness: Float
    let illuminationQuality: Float
    let faceAngleStability: Float
    let eyeOpenness: Float
    let recommendedForOverlay: Bool
    let warningFlags: [String]
}

class LandmarkExtractor {
    private let faceDetectionRequest: VNDetectFaceLandmarksRequest
    private var lastImageCaptureTime: TimeInterval = 0
    private let imageCaptureInterval: TimeInterval = 1.0  // 1 second intervals
    private var frameCounter: Int = 0
    
    // Engineering overlay data collection
    private var overlayDataBuffer: [LandmarkOverlayData] = []
    private let maxOverlayDataBuffer = 50  // Keep last 50 frames of overlay data
    
    init() {
        self.faceDetectionRequest = VNDetectFaceLandmarksRequest()
        self.faceDetectionRequest.revision = VNDetectFaceLandmarksRequestRevision3
    }
    
    func extractLandmarksAndCaptureImage(from sampleBuffer: CMSampleBuffer) -> (landmarks: FacialLandmarks?, capturedImage: SessionData.CapturedImage?) {
        // RGB version - includes both landmarks and image capture
        return extractLandmarksAndCaptureImage(from: sampleBuffer, cameraType: .rgb)
    }
    
    // MARK: - Engineering Overlay Data Export
    func getOverlayDataForEngineering() -> [LandmarkOverlayData] {
        return overlayDataBuffer
    }
    
    func exportOverlayDataAsJSON() -> Data? {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            encoder.dateEncodingStrategy = .secondsSince1970
            return try encoder.encode(overlayDataBuffer)
        } catch {
            print("❌ LandmarkExtractor: Failed to encode overlay data - \(error)")
            return nil
        }
    }
    
    func clearOverlayDataBuffer() {
        overlayDataBuffer.removeAll()
    }
    
    func extractLandmarksAndCaptureImage(from sampleBuffer: CMSampleBuffer, cameraType: CameraType) -> (landmarks: FacialLandmarks?, capturedImage: SessionData.CapturedImage?) {
        
        frameCounter += 1
        let currentTime = CACurrentMediaTime()
        
        // Check if we should capture an image (1 fps) - only for RGB
        let shouldCaptureImage = cameraType == .rgb && (currentTime - lastImageCaptureTime) >= imageCaptureInterval
        
        // Convert sample buffer to CIImage
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return (nil, nil)
        }
        
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        let context = CIContext()
        
        // Extract facial landmarks (only from RGB for better accuracy)
        let landmarks = cameraType == .rgb ? extractFacialLandmarks(from: ciImage) : nil
        
        // Capture image if it's time
        var capturedImage: SessionData.CapturedImage? = nil
        if shouldCaptureImage {
            capturedImage = captureImage(from: ciImage, context: context, timestamp: currentTime, cameraType: cameraType)
            lastImageCaptureTime = currentTime
            
            // NEW: Generate comprehensive overlay data for engineering team
            if let overlayData = generateOverlayData(from: ciImage, landmarks: landmarks, capturedImage: capturedImage, timestamp: currentTime) {
                addOverlayDataToBuffer(overlayData)
            }
        }
        
        return (landmarks, capturedImage)
    }
    
    private func extractFacialLandmarks(from image: CIImage) -> FacialLandmarks? {
        // PROPER DEBUGGING: Check RAW Vision coordinates first (no orientation)
        print("🔍 DEBUGGING: Image size = \(image.extent.size)")
        
        let requestHandler = VNImageRequestHandler(ciImage: image, options: [:])  // NO orientation parameter
        
        do {
            try requestHandler.perform([faceDetectionRequest])
            
            guard let results = faceDetectionRequest.results,
                  let face = results.first else {
                print("❌ No face detected in image")
                return nil
            }
            
            let landmarks = face.landmarks
            let boundingBox = face.boundingBox
            
            print("✅ RAW VISION DETECTION:")
            print("   Face bounding box (normalized): \(boundingBox)")
            print("   Face confidence: \(face.confidence)")
            
            // Convert to image coordinates WITHOUT any transformation
            let rawFaceRect = CGRect(
                x: boundingBox.origin.x * image.extent.size.width,
                y: boundingBox.origin.y * image.extent.size.height,
                width: boundingBox.size.width * image.extent.size.width,
                height: boundingBox.size.height * image.extent.size.height
            )
            print("   Face rect (raw image coords): \(rawFaceRect)")
            
            // Check if we have eye landmarks and print their RAW coordinates
            if let leftEye = landmarks?.leftEye, let rightEye = landmarks?.rightEye {
                print("👁️ RAW EYE LANDMARKS:")
                print("   Left eye points: \(leftEye.pointCount)")
                print("   Right eye points: \(rightEye.pointCount)")
                
                if leftEye.pointCount > 0 {
                    let leftPoints = leftEye.normalizedPoints
                    print("   Left eye center (normalized): \(leftPoints[0])")
                    let leftImagePoint = CGPoint(
                        x: CGFloat(leftPoints[0].x) * image.extent.size.width,
                        y: CGFloat(leftPoints[0].y) * image.extent.size.height
                    )
                    print("   Left eye center (image coords): \(leftImagePoint)")
                }
                if rightEye.pointCount > 0 {
                    let rightPoints = rightEye.normalizedPoints
                    print("   Right eye center (normalized): \(rightPoints[0])")
                    let rightImagePoint = CGPoint(
                        x: CGFloat(rightPoints[0].x) * image.extent.size.width,
                        y: CGFloat(rightPoints[0].y) * image.extent.size.height
                    )
                    print("   Right eye center (image coords): \(rightImagePoint)")
                }
            }
            
            // Calculate simple eye region using RAW coordinates
            let simpleEyeRegion = calculateSimpleEyeRegion(
                face: face,
                imageSize: image.extent.size,
                preferredEye: .both
            )
            print("👁️ SIMPLE EYE REGION: \(simpleEyeRegion)")
            
            // Now test with different orientations to see coordinate transformation
            print("🔄 TESTING COORDINATE TRANSFORMATIONS:")
            testCoordinateTransformations(face: face, imageSize: image.extent.size)
            
            return processLandmarks(face: face, imageSize: image.extent.size, orientation: .up)
            
        } catch {
            print("❌ Error detecting face: \(error)")
            return nil
        }
    }
    
    private func testCoordinateTransformations(face: VNFaceObservation, imageSize: CGSize) {
        let boundingBox = face.boundingBox
        let orientations: [CGImagePropertyOrientation] = [.up, .right, .down, .left]
        
        for orientation in orientations {
            let transformedRect = transformVisionToImageCoordinates(
                CGRect(
                    x: boundingBox.origin.x * imageSize.width,
                    y: boundingBox.origin.y * imageSize.height,
                    width: boundingBox.size.width * imageSize.width,
                    height: boundingBox.size.height * imageSize.height
                ),
                imageSize: imageSize,
                orientation: orientation
            )
            print("   \(orientation): \(transformedRect)")
        }
    }
    
    private func processLandmarks(face: VNFaceObservation, imageSize: CGSize, orientation: CGImagePropertyOrientation) -> FacialLandmarks? {
        
        let boundingBox = face.boundingBox
        let faceRect = CGRect(
            x: boundingBox.origin.x * imageSize.width,
            y: boundingBox.origin.y * imageSize.height,
            width: boundingBox.size.width * imageSize.width,
            height: boundingBox.size.height * imageSize.height
        )
        
        // Extract detailed landmarks
        let landmarks = face.landmarks
        
        // CRITICAL FIX: Transform coordinates to match saved image coordinate system
        let transformedFaceRect = transformVisionToImageCoordinates(faceRect, imageSize: imageSize, orientation: orientation)
        
        return FacialLandmarks(
            timestamp: CACurrentMediaTime(),
            faceRect: transformedFaceRect,
            faceConfidence: face.confidence,
            leftEyeLandmarks: extractEyeLandmarks(landmarks?.leftEye, imageSize: imageSize, orientation: orientation),
            rightEyeLandmarks: extractEyeLandmarks(landmarks?.rightEye, imageSize: imageSize, orientation: orientation),
            leftIrisLandmarks: extractEyeLandmarks(landmarks?.leftPupil, imageSize: imageSize, orientation: orientation),
            rightIrisLandmarks: extractEyeLandmarks(landmarks?.rightPupil, imageSize: imageSize, orientation: orientation),
            noseLandmarks: extractLandmarkPoints(landmarks?.nose, imageSize: imageSize, orientation: orientation),
            mouthLandmarks: extractLandmarkPoints(landmarks?.outerLips, imageSize: imageSize, orientation: orientation),
            jawlineLandmarks: extractLandmarkPoints(landmarks?.faceContour, imageSize: imageSize, orientation: orientation),
            eyebrowLandmarks: extractEyebrowLandmarks(landmarks, imageSize: imageSize, orientation: orientation),
            headPose: estimateHeadPose(from: landmarks)
        )
    }
    
    private func extractEyeLandmarks(_ landmark: VNFaceLandmarkRegion2D?, imageSize: CGSize, orientation: CGImagePropertyOrientation = .up) -> [CGPoint] {
        guard let landmark = landmark else { return [] }
        
        return landmark.normalizedPoints.map { point in
            let visionPoint = CGPoint(
                x: CGFloat(point.x) * imageSize.width,
                y: CGFloat(point.y) * imageSize.height
            )
            return transformVisionToImageCoordinates(CGRect(origin: visionPoint, size: CGSize(width: 1, height: 1)), imageSize: imageSize, orientation: orientation).origin
        }
    }
    
    private func extractLandmarkPoints(_ landmark: VNFaceLandmarkRegion2D?, imageSize: CGSize, orientation: CGImagePropertyOrientation = .up) -> [CGPoint] {
        guard let landmark = landmark else { return [] }
        
        return landmark.normalizedPoints.map { point in
            let visionPoint = CGPoint(
                x: CGFloat(point.x) * imageSize.width,
                y: CGFloat(point.y) * imageSize.height
            )
            return transformVisionToImageCoordinates(CGRect(origin: visionPoint, size: CGSize(width: 1, height: 1)), imageSize: imageSize, orientation: orientation).origin
        }
    }
    
    private func extractEyebrowLandmarks(_ landmarks: VNFaceLandmarks2D?, imageSize: CGSize, orientation: CGImagePropertyOrientation = .up) -> [CGPoint] {
        guard let landmarks = landmarks else { return [] }
        
        var eyebrowPoints: [CGPoint] = []
        
        // Left eyebrow
        if let leftEyebrow = landmarks.leftEyebrow {
            eyebrowPoints.append(contentsOf: extractLandmarkPoints(leftEyebrow, imageSize: imageSize, orientation: orientation))
        }
        
        // Right eyebrow
        if let rightEyebrow = landmarks.rightEyebrow {
            eyebrowPoints.append(contentsOf: extractLandmarkPoints(rightEyebrow, imageSize: imageSize, orientation: orientation))
        }
        
        return eyebrowPoints
    }
    
    // ENHANCED: Calculate eye region based on actual detected landmarks
    // FIXED: Use RAW Vision coordinates without ANY transformation
    private func calculateSimpleEyeRegion(face: VNFaceObservation, imageSize: CGSize, preferredEye: EyePreference) -> CGRect {
        print("🔍 USING RAW VISION COORDINATES - NO TRANSFORMATIONS")
        print("📐 Image size: \(imageSize)")
        
        // Get face bounding box in normalized Vision coordinates (0-1)
        let faceBounds = face.boundingBox
        print("📐 Face bounds (normalized): \(faceBounds)")
        
        // Vision framework uses bottom-left origin, but we need to flip Y for UIKit top-left origin
        // BUT since the image itself might be rotated, let's use RAW coordinates first
        let faceRect = CGRect(
            x: faceBounds.origin.x * imageSize.width,
            y: faceBounds.origin.y * imageSize.height,
            width: faceBounds.size.width * imageSize.width,
            height: faceBounds.size.height * imageSize.height
        )
        print("📐 Face rect (RAW image coords): \(faceRect)")
        
        // Get actual eye landmark positions to validate our calculation
        if let leftEye = face.landmarks?.leftEye, let rightEye = face.landmarks?.rightEye {
            if leftEye.pointCount > 0 && rightEye.pointCount > 0 {
                let leftPoint = leftEye.normalizedPoints[0]
                let rightPoint = rightEye.normalizedPoints[0]
                
                let leftImagePoint = CGPoint(
                    x: CGFloat(leftPoint.x) * imageSize.width,
                    y: CGFloat(leftPoint.y) * imageSize.height
                )
                let rightImagePoint = CGPoint(
                    x: CGFloat(rightPoint.x) * imageSize.width,
                    y: CGFloat(rightPoint.y) * imageSize.height
                )
                
                print("👁️ RAW Left eye: \(leftImagePoint)")
                print("👁️ RAW Right eye: \(rightImagePoint)")
                
                // Calculate eye region based on actual eye positions
                let eyeMinX = min(leftImagePoint.x, rightImagePoint.x) - 50  // 50px padding
                let eyeMaxX = max(leftImagePoint.x, rightImagePoint.x) + 50  // 50px padding
                let eyeMinY = min(leftImagePoint.y, rightImagePoint.y) - 30  // 30px padding
                let eyeMaxY = max(leftImagePoint.y, rightImagePoint.y) + 30  // 30px padding
                
                let actualEyeRegion = CGRect(
                    x: max(0, eyeMinX),
                    y: max(0, eyeMinY),
                    width: min(imageSize.width - max(0, eyeMinX), eyeMaxX - eyeMinX),
                    height: min(imageSize.height - max(0, eyeMinY), eyeMaxY - eyeMinY)
                )
                
                print("👁️ Eye region from actual landmarks: \(actualEyeRegion)")
                return actualEyeRegion
            }
        }
        
        // Fallback to proportional calculation if no eye landmarks
        let eyeRegionHeight = faceRect.height * 0.3
        let eyeRegionWidth = faceRect.width * 0.8
        let eyeRegionY = faceRect.origin.y + (faceRect.height * 0.2)
        let eyeRegionX = faceRect.origin.x + (faceRect.width * 0.1)
        
        let fallbackEyeRegion = CGRect(
            x: eyeRegionX,
            y: eyeRegionY,
            width: eyeRegionWidth,
            height: eyeRegionHeight
        )
        
        print("👁️ Fallback eye region: \(fallbackEyeRegion)")
        return fallbackEyeRegion
    }
    
    private func calculateEyeRegionFromLandmarks(face: VNFaceObservation, imageSize: CGSize, preferredEye: EyePreference) -> CGRect {
        guard let landmarks = face.landmarks else {
            // Fallback to face bounding box calculation if no landmarks
            let faceRect = CGRect(
                x: face.boundingBox.origin.x * imageSize.width,
                y: face.boundingBox.origin.y * imageSize.height,
                width: face.boundingBox.size.width * imageSize.width,
                height: face.boundingBox.size.height * imageSize.height
            )
            return ImageOrientationManager.calculateEyeRegion(
                faceRect: faceRect,
                orientation: .portrait,
                preferredEye: preferredEye
            )
        }
        
        var eyeLandmarks: VNFaceLandmarkRegion2D?
        
        // Select the appropriate eye landmarks
        switch preferredEye {
        case .left:
            eyeLandmarks = landmarks.leftEye
        case .right:
            eyeLandmarks = landmarks.rightEye
        case .both:
            // For both eyes, we'll create a bounding box that encompasses both
            if let leftEye = landmarks.leftEye, let rightEye = landmarks.rightEye {
                let leftPoints = leftEye.normalizedPoints.map { CGPoint(x: CGFloat($0.x), y: CGFloat($0.y)) }
                let rightPoints = rightEye.normalizedPoints.map { CGPoint(x: CGFloat($0.x), y: CGFloat($0.y)) }
                let allEyePoints = leftPoints + rightPoints
                return calculateBoundingBoxFromCGPoints(from: allEyePoints, imageSize: imageSize, padding: 0.15)
            } else {
                eyeLandmarks = landmarks.rightEye ?? landmarks.leftEye
            }
        }
        
        guard let selectedEyeLandmarks = eyeLandmarks else {
            // Final fallback to face rect calculation
            let faceRect = CGRect(
                x: face.boundingBox.origin.x * imageSize.width,
                y: face.boundingBox.origin.y * imageSize.height,
                width: face.boundingBox.size.width * imageSize.width,
                height: face.boundingBox.size.height * imageSize.height
            )
            return ImageOrientationManager.calculateEyeRegion(
                faceRect: faceRect,
                orientation: .portrait,
                preferredEye: preferredEye
            )
        }
        
        // Calculate precise bounding box from landmarks with padding
        let eyePoints = selectedEyeLandmarks.normalizedPoints.map { CGPoint(x: CGFloat($0.x), y: CGFloat($0.y)) }
        return calculateBoundingBoxFromCGPoints(from: eyePoints, imageSize: imageSize, padding: 0.2)
    }
    
    // Helper function to calculate bounding box from CGPoint coordinates
    private func calculateBoundingBoxFromCGPoints(from points: [CGPoint], imageSize: CGSize, padding: CGFloat) -> CGRect {
        guard !points.isEmpty else {
            return CGRect(x: 0, y: 0, width: 100, height: 100) // Default fallback
        }
        
        // Find min/max coordinates in normalized space
        let xCoords = points.map { $0.x }
        let yCoords = points.map { $0.y }
        
        let minX = xCoords.min()!
        let maxX = xCoords.max()!
        let minY = yCoords.min()!
        let maxY = yCoords.max()!
        
        // Add padding around the landmarks
        let width = maxX - minX
        let height = maxY - minY
        let paddedMinX = max(0, minX - width * padding)
        let paddedMaxX = min(1, maxX + width * padding)
        let paddedMinY = max(0, minY - height * padding)
        let paddedMaxY = min(1, maxY + height * padding)
        
        // Convert to image coordinates with Y-coordinate flip (Vision uses bottom-left, UIKit uses top-left)
        let imageRect = CGRect(
            x: paddedMinX * imageSize.width,
            y: (1.0 - paddedMaxY) * imageSize.height,  // CRITICAL FIX: Flip Y coordinate
            width: (paddedMaxX - paddedMinX) * imageSize.width,
            height: (paddedMaxY - paddedMinY) * imageSize.height
        )
        
        print("👁️ LandmarkExtractor: Calculated precise eye region from landmarks: \(imageRect)")
        print("   📍 Original landmarks bounds: x:\(minX)-\(maxX), y:\(minY)-\(maxY)")
        print("   📍 With padding (\(padding*100)%): x:\(paddedMinX)-\(paddedMaxX), y:\(paddedMinY)-\(paddedMaxY)")
        print("   🖼️ Image size: \(imageSize)")
        print("   🔍 DEBUGGING: Individual landmark points:")
        for (index, point) in points.enumerated() {
            print("      Point \(index): (\(point.x), \(point.y)) normalized")
            let imagePoint = CGPoint(x: CGFloat(point.x) * imageSize.width, y: CGFloat(point.y) * imageSize.height)
            print("      Point \(index): (\(imagePoint.x), \(imagePoint.y)) in image coords (before Y-flip)")
        }
        
        return imageRect
    }
    
    // ALTERNATIVE: Simple face-rectangle-based eye region (avoiding coordinate transformation issues)
    private func calculateAlternativeEyeRegion(faceRect: CGRect, imageSize: CGSize) -> CGRect {
        // Use the detected face rectangle and apply simple proportional eye region
        // This avoids all the coordinate transformation complexity
        
        // Right eye is typically at 75% across face width, 30% down from top
        let eyeRegion = CGRect(
            x: faceRect.minX + faceRect.width * 0.6,   // Right eye position
            y: faceRect.minY + faceRect.height * 0.25, // Eye level (25% from top)
            width: faceRect.width * 0.35,              // Eye region width
            height: faceRect.height * 0.3              // Eye region height
        )
        
        // Ensure region stays within image bounds
        let boundedRegion = CGRect(
            x: max(0, min(eyeRegion.origin.x, imageSize.width - eyeRegion.width)),
            y: max(0, min(eyeRegion.origin.y, imageSize.height - eyeRegion.height)),
            width: min(eyeRegion.width, imageSize.width),
            height: min(eyeRegion.height, imageSize.height)
        )
        
        print("🎯 ALTERNATIVE: Face rect: \(faceRect)")
        print("🎯 ALTERNATIVE: Eye region: \(boundedRegion)")
        print("🎯 ALTERNATIVE: Image size: \(imageSize)")
        
        return boundedRegion
    }
    
    // Legacy helper function to calculate bounding box from landmark points
    private func calculateBoundingBox(from points: [vector_float2], imageSize: CGSize, padding: CGFloat) -> CGRect {
        guard !points.isEmpty else {
            return CGRect(x: 0, y: 0, width: 100, height: 100) // Default fallback
        }
        
        // Find min/max coordinates in normalized space
        let xCoords = points.map { CGFloat($0.x) }
        let yCoords = points.map { CGFloat($0.y) }
        
        let minX = xCoords.min()!
        let maxX = xCoords.max()!
        let minY = yCoords.min()!
        let maxY = yCoords.max()!
        
        // Add padding around the landmarks
        let width = maxX - minX
        let height = maxY - minY
        let paddedMinX = max(0, minX - width * padding)
        let paddedMaxX = min(1, maxX + width * padding)
        let paddedMinY = max(0, minY - height * padding)
        let paddedMaxY = min(1, maxY + height * padding)
        
        // Convert to image coordinates with Y-coordinate flip (Vision uses bottom-left, UIKit uses top-left)
        let imageRect = CGRect(
            x: paddedMinX * imageSize.width,
            y: (1.0 - paddedMaxY) * imageSize.height,  // CRITICAL FIX: Flip Y coordinate
            width: (paddedMaxX - paddedMinX) * imageSize.width,
            height: (paddedMaxY - paddedMinY) * imageSize.height
        )
        
        print("👁️ LandmarkExtractor: Calculated precise eye region from landmarks: \(imageRect)")
        print("   📍 Original landmarks bounds: x:\(minX)-\(maxX), y:\(minY)-\(maxY)")
        print("   📍 With padding (\(padding*100)%): x:\(paddedMinX)-\(paddedMaxX), y:\(paddedMinY)-\(paddedMaxY)")
        print("   🖼️ Image size: \(imageSize)")
        print("   🔍 DEBUGGING: Individual landmark points:")
        for (index, point) in points.enumerated() {
            print("      Point \(index): (\(point.x), \(point.y)) normalized")
            let imagePoint = CGPoint(x: CGFloat(point.x) * imageSize.width, y: CGFloat(point.y) * imageSize.height)
            print("      Point \(index): (\(imagePoint.x), \(imagePoint.y)) in image coords (before Y-flip)")
        }
        
        return imageRect
    }
    
    private func estimateHeadPose(from landmarks: VNFaceLandmarks2D?) -> FacialLandmarks.HeadPose {
        // Simplified head pose estimation
        // In a production system, you'd use more sophisticated 3D pose estimation
        
        guard let landmarks = landmarks,
              let nose = landmarks.nose,
              let leftEye = landmarks.leftEye,
              let rightEye = landmarks.rightEye else {
            return FacialLandmarks.HeadPose(pitch: 0, yaw: 0, roll: 0)
        }
        
        // Calculate approximate head pose based on facial feature positions
        let nosePoints = nose.normalizedPoints
        let leftEyePoints = leftEye.normalizedPoints
        let rightEyePoints = rightEye.normalizedPoints
        
        // Calculate eye center positions
        let leftEyeCenter = leftEyePoints.reduce(CGPoint.zero) { result, point in
            CGPoint(x: result.x + CGFloat(point.x), y: result.y + CGFloat(point.y))
        }
        let rightEyeCenter = rightEyePoints.reduce(CGPoint.zero) { result, point in
            CGPoint(x: result.x + CGFloat(point.x), y: result.y + CGFloat(point.y))
        }
        
        let leftCenter = CGPoint(x: leftEyeCenter.x / CGFloat(leftEyePoints.count),
                                y: leftEyeCenter.y / CGFloat(leftEyePoints.count))
        let rightCenter = CGPoint(x: rightEyeCenter.x / CGFloat(rightEyePoints.count),
                                 y: rightEyeCenter.y / CGFloat(rightEyePoints.count))
        
        // Calculate roll (head tilt) from eye line angle
        let eyeVector = CGPoint(x: rightCenter.x - leftCenter.x, y: rightCenter.y - leftCenter.y)
        let roll = Float(atan2(eyeVector.y, eyeVector.x)) * 180.0 / Float.pi
        
        // Estimate yaw and pitch (simplified)
        let faceCenter = CGPoint(x: (leftCenter.x + rightCenter.x) / 2, y: (leftCenter.y + rightCenter.y) / 2)
        let noseCenter = nosePoints.isEmpty ? faceCenter : CGPoint(x: CGFloat(nosePoints[0].x), y: CGFloat(nosePoints[0].y))
        
        let yaw = Float(noseCenter.x - faceCenter.x) * 60.0  // Approximate scaling
        let pitch = Float(faceCenter.y - noseCenter.y) * 60.0  // Approximate scaling
        
        return FacialLandmarks.HeadPose(pitch: pitch, yaw: yaw, roll: roll)
    }
    
    private func captureImage(from ciImage: CIImage, context: CIContext, timestamp: TimeInterval, cameraType: CameraType = .rgb) -> SessionData.CapturedImage? {
        // DEBUGGING: Add bounding box overlays to saved images
        let imageWithBoundingBoxes = drawBoundingBoxesOnImage(image: ciImage, context: context)
        
        // Convert CIImage to JPEG data
        guard let cgImage = context.createCGImage(imageWithBoundingBoxes, from: imageWithBoundingBoxes.extent) else {
            print("❌ LandmarkExtractor: Failed to create CGImage")
            return nil
        }
        
        let uiImage = UIImage(cgImage: cgImage)
        guard let jpegData = uiImage.jpegData(compressionQuality: 0.8) else {
            print("❌ LandmarkExtractor: Failed to create JPEG data")
            return nil
        }
        
        let filename = String(format: "%@_%.3f-DEBUG.jpg", cameraType.rawValue.lowercased(), timestamp)
        
        // NEW: Also capture eye region if face is detected
        let (eyeRegionData, eyeRegionRect, faceRect) = captureEyeRegion(from: ciImage, context: context)
        
        print("📸 LandmarkExtractor: Captured \(cameraType.rawValue) image - \(filename) (\(jpegData.count / 1024)KB)")
        if eyeRegionData != nil {
            print("👁️ LandmarkExtractor: Also captured eye region (\((eyeRegionData?.count ?? 0) / 1024)KB)")
        }
        
        return SessionData.CapturedImage(
            timestamp: timestamp,
            filename: filename,
            imageData: jpegData,
            frameNumber: frameCounter,
            cameraPosition: cameraType == .rgb ? "front" : "front_nir",
            imageSize: ciImage.extent.size,
            eyeRegionData: eyeRegionData,
            eyeRegionRect: eyeRegionRect,
            faceRect: faceRect
        )
    }
    
    // NEW: Extract and save eye region separately
    private func captureEyeRegion(from image: CIImage, context: CIContext) -> (eyeRegionData: Data?, eyeRegionRect: CGRect, faceRect: CGRect) {
        let requestHandler = VNImageRequestHandler(ciImage: image, options: [:])
        
        do {
            // Use landmark detection instead of just face rectangles for better accuracy
            let faceRequest = VNDetectFaceLandmarksRequest()
            try requestHandler.perform([faceRequest])
            
            guard let results = faceRequest.results,
                  let face = results.first else {
                print("⚠️ LandmarkExtractor: No face detected for eye region extraction")
                return (nil, CGRect.zero, CGRect.zero)
            }
            
            // Calculate face rectangle in image coordinates
            let boundingBox = face.boundingBox
            let faceRect = CGRect(
                x: boundingBox.origin.x * image.extent.width,
                y: boundingBox.origin.y * image.extent.height,
                width: boundingBox.size.width * image.extent.width,
                height: boundingBox.size.height * image.extent.height
            )
            
            // ENHANCED: Use simple eye region calculation to avoid coordinate transformation issues
            let eyeRegionRect = calculateSimpleEyeRegion(
                face: face, 
                imageSize: image.extent.size,
                preferredEye: .right
            )
            
            // ALTERNATIVE APPROACH: Try using face bounding box with fixed eye region calculation
            let alternativeEyeRegion = calculateAlternativeEyeRegion(
                faceRect: faceRect,
                imageSize: image.extent.size
            )
            
            print("🔄 COMPARISON: Landmark-based region: \(eyeRegionRect)")
            print("🔄 COMPARISON: Alternative region: \(alternativeEyeRegion)")
            
            // Use alternative approach for now to test
            let finalEyeRegion = alternativeEyeRegion
            
            // Keep orientation analysis for debugging (but use landmark-based eye region)
            let orientationAnalysis = ImageOrientationManager.analyzeOrientation(from: image)
            print("🔄 LandmarkExtractor: Detected orientation: \(orientationAnalysis.recommendedOrientation), confidence: \(orientationAnalysis.confidence)")
            print("👤 LandmarkExtractor: Face rect: \(faceRect)")
            print("👁️ LandmarkExtractor: Eye region rect: \(eyeRegionRect)")
            print("📏 LandmarkExtractor: Image size: \(image.extent.size)")
            
            // DEBUGGING: Check if eye region is within face bounds
            let eyeInFace = faceRect.contains(eyeRegionRect)
            print("✅ LandmarkExtractor: Eye region within face bounds: \(eyeInFace)")
            if !eyeInFace {
                print("⚠️ LandmarkExtractor: WARNING - Eye region extends outside face bounds!")
            }
            
            // DEBUGGING: Validate eye region using actual landmarks if available
            if let landmarks = face.landmarks,
               let rightEye = landmarks.rightEye,
               let firstPoint = rightEye.normalizedPoints.first {
                let actualEyeY = CGFloat(firstPoint.y) * image.extent.size.height
                let calculatedEyeY = eyeRegionRect.midY
                let yDifference = abs(actualEyeY - calculatedEyeY)
                
                print("🎯 LandmarkExtractor: Actual right eye Y: \(actualEyeY), Calculated Y: \(calculatedEyeY), Difference: \(yDifference)")
                
                if yDifference > faceRect.height * 0.1 {  // More than 10% of face height difference
                    print("⚠️ LandmarkExtractor: MAJOR MISMATCH - Eye region calculation may be wrong!")
                }
            }
            
            // Extract eye region from image using the alternative approach
            let eyeRegionImage = image.cropped(to: finalEyeRegion)
            
            // Convert to JPEG data
            guard let eyeRegionCGImage = context.createCGImage(eyeRegionImage, from: eyeRegionImage.extent) else {
                print("⚠️ LandmarkExtractor: Failed to create eye region CGImage")
                return (nil, eyeRegionRect, faceRect)
            }
            
            let eyeRegionUIImage = UIImage(cgImage: eyeRegionCGImage)
            guard let eyeRegionJPEG = eyeRegionUIImage.jpegData(compressionQuality: 0.9) else {
                print("⚠️ LandmarkExtractor: Failed to create eye region JPEG")
                return (nil, eyeRegionRect, faceRect)
            }
            
            print("👁️ LandmarkExtractor: Extracted eye region: \(finalEyeRegion)")
            return (eyeRegionJPEG, finalEyeRegion, faceRect)
            
        } catch {
            print("❌ LandmarkExtractor: Face detection failed - \(error)")
            return (nil, CGRect.zero, CGRect.zero)
        }
    }
    
    // MARK: - CRITICAL COORDINATE TRANSFORMATION FIXES
    
    /// Determines the correct orientation for Vision framework processing
    private func getCorrectOrientation(for image: CIImage) -> CGImagePropertyOrientation {
        // Get device orientation
        let deviceOrientation = UIDevice.current.orientation
        
        // CRITICAL FIX: For video frames from AVCaptureVideoDataOutput, we need different orientation
        // than for static images. Research shows video frames need .right for portrait mode.
        // The camera sensor is mounted in landscape, so video frames are delivered in landscape
        // orientation and need to be rotated 90° clockwise (.right) to be upright in portrait.
        switch deviceOrientation {
        case .portrait:
            return .right  // ✅ FIXED: Video frames need .right for portrait orientation
        case .portraitUpsideDown:
            return .left   // ✅ FIXED: 180° rotation from portrait
        case .landscapeLeft:
            return .up     // ✅ FIXED: No rotation needed when device matches sensor
        case .landscapeRight:
            return .down   // ✅ FIXED: 180° rotation in landscape
        default:
            // Fallback for unknown orientation - assume portrait
            print("⚠️ LandmarkExtractor: Unknown device orientation, using .right for video")
            return .right
        }
    }
    
    /// Transforms Vision framework coordinates to match saved image coordinates
    private func transformVisionToImageCoordinates(_ rect: CGRect, imageSize: CGSize, orientation: CGImagePropertyOrientation) -> CGRect {
        
        // Vision framework uses normalized coordinates (0-1) with bottom-left origin
        // We need to transform to image coordinates with top-left origin
        
        var transformedRect = rect
        
        // Apply coordinate system transformation based on orientation
        switch orientation {
        case .up:
            // Standard case - just flip Y axis (bottom-left to top-left)
            transformedRect.origin.y = imageSize.height - rect.origin.y - rect.height
            
        case .left:
            // 90° rotation counterclockwise
            let newX = rect.origin.y
            let newY = imageSize.width - rect.origin.x - rect.width
            transformedRect = CGRect(x: newX, y: newY, width: rect.height, height: rect.width)
            
        case .right:
            // 90° rotation clockwise  
            let newX = imageSize.height - rect.origin.y - rect.height
            let newY = rect.origin.x
            transformedRect = CGRect(x: newX, y: newY, width: rect.height, height: rect.width)
            
        case .down:
            // 180° rotation
            let newX = imageSize.width - rect.origin.x - rect.width
            let newY = rect.origin.y
            transformedRect = CGRect(x: newX, y: newY, width: rect.width, height: rect.height)
            
        case .leftMirrored:
            // CRITICAL: This is what we use for front camera
            // Horizontal flip + coordinate system flip
            let newX = imageSize.width - rect.origin.x - rect.width
            let newY = imageSize.height - rect.origin.y - rect.height
            transformedRect = CGRect(x: newX, y: newY, width: rect.width, height: rect.height)
            
        case .rightMirrored:
            // Horizontal flip + 180° rotation
            let newX = rect.origin.x
            let newY = rect.origin.y  
            transformedRect = CGRect(x: newX, y: newY, width: rect.width, height: rect.height)
            
        case .upMirrored:
            // Horizontal flip only
            let newX = imageSize.width - rect.origin.x - rect.width
            let newY = imageSize.height - rect.origin.y - rect.height
            transformedRect = CGRect(x: newX, y: newY, width: rect.width, height: rect.height)
            
        case .downMirrored:
            // Horizontal flip + 180°
            let newX = rect.origin.x
            let newY = imageSize.height - rect.origin.y - rect.height
            transformedRect = CGRect(x: newX, y: newY, width: rect.width, height: rect.height)
            
        @unknown default:
            print("⚠️ LandmarkExtractor: Unknown orientation \(orientation)")
            transformedRect.origin.y = imageSize.height - rect.origin.y - rect.height
        }
        
        print("🔄 LandmarkExtractor: Transformed coordinates - Original: \(rect) -> Transformed: \(transformedRect)")
        return transformedRect
    }
    
    // MARK: - Engineering Overlay Data Generation
    private func generateOverlayData(from ciImage: CIImage, landmarks: FacialLandmarks?, capturedImage: SessionData.CapturedImage?, timestamp: TimeInterval) -> LandmarkOverlayData? {
        
        guard let capturedImage = capturedImage else {
            print("⚠️ LandmarkExtractor: Cannot generate overlay data without captured image")
            return nil
        }
        
        // Determine orientation and calculate transformations
        let orientation = getCorrectOrientation(for: ciImage)
        let originalSize = ciImage.extent.size
        let capturedSize = capturedImage.imageSize
        
        // Calculate scaling factors
        let visionToImageScale = CGPoint(
            x: capturedSize.width,
            y: capturedSize.height
        )
        
        // Create coordinate origin transform (Vision uses bottom-left, we use top-left)
        let coordinateOriginTransform = CGAffineTransform(scaleX: 1.0, y: -1.0).translatedBy(x: 0, y: -capturedSize.height)
        
        // Determine if this is a mirrored transform (front camera always mirrors)
        let mirrorTransform = true  // Front camera always mirrors, regardless of orientation
        
        var processingNotes: [String] = []
        processingNotes.append("Frame #\(frameCounter) processed at \(timestamp)")
        processingNotes.append("Orientation: \(orientation)")
        processingNotes.append("Mirror transform: \(mirrorTransform)")
        processingNotes.append("Vision to image scale: \(visionToImageScale)")
        
        // Extract face detection data with both coordinate systems
        var faceRect = CGRect.zero
        var faceConfidence: Float = 0.0
        var faceBoundingBoxNormalized = CGRect.zero
        
        // Re-run face detection to get raw Vision coordinates
        let requestHandler = VNImageRequestHandler(ciImage: ciImage, orientation: orientation, options: [:])
        do {
            let faceRequest = VNDetectFaceLandmarksRequest()
            try requestHandler.perform([faceRequest])
            
            if let face = faceRequest.results?.first {
                faceConfidence = face.confidence
                faceBoundingBoxNormalized = face.boundingBox
                
                // Convert to image coordinates
                let visionRect = CGRect(
                    x: faceBoundingBoxNormalized.origin.x * originalSize.width,
                    y: faceBoundingBoxNormalized.origin.y * originalSize.height,
                    width: faceBoundingBoxNormalized.size.width * originalSize.width,
                    height: faceBoundingBoxNormalized.size.height * originalSize.height
                )
                faceRect = transformVisionToImageCoordinates(visionRect, imageSize: originalSize, orientation: orientation)
                
                processingNotes.append("Face detected with confidence: \(faceConfidence)")
            }
        } catch {
            processingNotes.append("Face detection failed: \(error.localizedDescription)")
        }
        
        // Extract landmark data in both coordinate systems
        let landmarkData = extractNormalizedLandmarkData(from: ciImage, orientation: orientation)
        
        // Calculate eye region data using landmark-based method
        let orientationAnalysis = ImageOrientationManager.analyzeOrientation(from: ciImage)
        
        // Use landmark-based eye region calculation by detecting face again
        var eyeRegionRect: CGRect = CGRect.zero
        
        // Re-run face detection to get VNFaceObservation for landmark-based eye region
        let eyeRequestHandler = VNImageRequestHandler(ciImage: ciImage, orientation: orientation, options: [:])
        let eyeFaceRequest = VNDetectFaceLandmarksRequest()
        
        do {
            try eyeRequestHandler.perform([eyeFaceRequest])
            
            if let results = eyeFaceRequest.results, let face = results.first {
                // Use the new landmark-based method
                eyeRegionRect = calculateSimpleEyeRegion(
                    face: face,
                    imageSize: ciImage.extent.size,
                    preferredEye: .right
                )
                print("👁️ LandmarkExtractor: Using landmark-based eye region: \(eyeRegionRect)")
            } else {
                throw NSError(domain: "LandmarkExtractor", code: 1, userInfo: [NSLocalizedDescriptionKey: "No face detected"])
            }
        } catch {
            // Fallback to orientation-based calculation
            eyeRegionRect = ImageOrientationManager.calculateEyeRegion(
                faceRect: faceRect,
                orientation: orientationAnalysis.recommendedOrientation,
                preferredEye: .right
            )
            print("⚠️ LandmarkExtractor: Face detection failed, using fallback orientation-based eye region: \(eyeRegionRect)")
        }
        let eyeRegionScale = min(eyeRegionRect.width / faceRect.width, eyeRegionRect.height / faceRect.height)
        
        // Calculate quality metrics
        let qualityMetrics = calculateQualityMetrics(
            landmarks: landmarks,
            faceConfidence: faceConfidence,
            imageSize: originalSize,
            processingNotes: &processingNotes
        )
        
        let overlayData = LandmarkOverlayData(
            timestamp: timestamp,
            frameNumber: frameCounter,
            originalImageSize: CodableSize(originalSize),
            capturedImageSize: CodableSize(capturedSize),
            imageFilename: capturedImage.filename,
            visionToImageScale: CodablePoint(visionToImageScale),
            coordinateOriginTransform: CodableAffineTransform(coordinateOriginTransform),
            orientationTransform: orientation.rawValue,
            mirrorTransform: mirrorTransform,
            faceRect: CodableRect(faceRect),
            faceConfidence: faceConfidence,
            faceBoundingBoxNormalized: CodableRect(faceBoundingBoxNormalized),
            eyeRegionRect: CodableRect(eyeRegionRect),
            eyeRegionScale: eyeRegionScale,
            preferredEye: "right",
            leftEyeLandmarks: (landmarks?.leftEyeLandmarks ?? []).map { CodablePoint($0) },
            rightEyeLandmarks: (landmarks?.rightEyeLandmarks ?? []).map { CodablePoint($0) },
            leftIrisLandmarks: (landmarks?.leftIrisLandmarks ?? []).map { CodablePoint($0) },
            rightIrisLandmarks: (landmarks?.rightIrisLandmarks ?? []).map { CodablePoint($0) },
            noseLandmarks: (landmarks?.noseLandmarks ?? []).map { CodablePoint($0) },
            mouthLandmarks: (landmarks?.mouthLandmarks ?? []).map { CodablePoint($0) },
            jawlineLandmarks: (landmarks?.jawlineLandmarks ?? []).map { CodablePoint($0) },
            eyebrowLandmarks: (landmarks?.eyebrowLandmarks ?? []).map { CodablePoint($0) },
            leftEyeLandmarksNormalized: landmarkData.leftEyeNormalized.map { CodablePoint($0) },
            rightEyeLandmarksNormalized: landmarkData.rightEyeNormalized.map { CodablePoint($0) },
            leftIrisLandmarksNormalized: landmarkData.leftIrisNormalized.map { CodablePoint($0) },
            rightIrisLandmarksNormalized: landmarkData.rightIrisNormalized.map { CodablePoint($0) },
            noseLandmarksNormalized: landmarkData.noseNormalized.map { CodablePoint($0) },
            mouthLandmarksNormalized: landmarkData.mouthNormalized.map { CodablePoint($0) },
            jawlineLandmarksNormalized: landmarkData.jawlineNormalized.map { CodablePoint($0) },
            eyebrowLandmarksNormalized: landmarkData.eyebrowNormalized.map { CodablePoint($0) },
            processingNotes: processingNotes,
            qualityMetrics: qualityMetrics
        )
        
        print("📊 LandmarkExtractor: Generated comprehensive overlay data for frame \(frameCounter)")
        return overlayData
    }
    
    private func addOverlayDataToBuffer(_ overlayData: LandmarkOverlayData) {
        overlayDataBuffer.append(overlayData)
        
        // Keep buffer size manageable
        if overlayDataBuffer.count > maxOverlayDataBuffer {
            overlayDataBuffer.removeFirst()
        }
        
        print("📈 LandmarkExtractor: Overlay data buffer size: \(overlayDataBuffer.count)/\(maxOverlayDataBuffer)")
    }
    
    private func extractNormalizedLandmarkData(from image: CIImage, orientation: CGImagePropertyOrientation) -> (leftEyeNormalized: [CGPoint], rightEyeNormalized: [CGPoint], leftIrisNormalized: [CGPoint], rightIrisNormalized: [CGPoint], noseNormalized: [CGPoint], mouthNormalized: [CGPoint], jawlineNormalized: [CGPoint], eyebrowNormalized: [CGPoint]) {
        
        let requestHandler = VNImageRequestHandler(ciImage: image, orientation: orientation, options: [:])
        
        do {
            try requestHandler.perform([faceDetectionRequest])
            
            guard let face = faceDetectionRequest.results?.first,
                  let landmarks = face.landmarks else {
                return ([], [], [], [], [], [], [], [])
            }
            
            // Extract raw normalized coordinates (0-1 range)
            let leftEyeNormalized = landmarks.leftEye?.normalizedPoints.map { CGPoint(x: CGFloat($0.x), y: CGFloat($0.y)) } ?? []
            let rightEyeNormalized = landmarks.rightEye?.normalizedPoints.map { CGPoint(x: CGFloat($0.x), y: CGFloat($0.y)) } ?? []
            let leftIrisNormalized = landmarks.leftPupil?.normalizedPoints.map { CGPoint(x: CGFloat($0.x), y: CGFloat($0.y)) } ?? []
            let rightIrisNormalized = landmarks.rightPupil?.normalizedPoints.map { CGPoint(x: CGFloat($0.x), y: CGFloat($0.y)) } ?? []
            let noseNormalized = landmarks.nose?.normalizedPoints.map { CGPoint(x: CGFloat($0.x), y: CGFloat($0.y)) } ?? []
            let mouthNormalized = landmarks.outerLips?.normalizedPoints.map { CGPoint(x: CGFloat($0.x), y: CGFloat($0.y)) } ?? []
            let jawlineNormalized = landmarks.faceContour?.normalizedPoints.map { CGPoint(x: CGFloat($0.x), y: CGFloat($0.y)) } ?? []
            
            var eyebrowNormalized: [CGPoint] = []
            if let leftEyebrow = landmarks.leftEyebrow {
                eyebrowNormalized.append(contentsOf: leftEyebrow.normalizedPoints.map { CGPoint(x: CGFloat($0.x), y: CGFloat($0.y)) })
            }
            if let rightEyebrow = landmarks.rightEyebrow {
                eyebrowNormalized.append(contentsOf: rightEyebrow.normalizedPoints.map { CGPoint(x: CGFloat($0.x), y: CGFloat($0.y)) })
            }
            
            return (leftEyeNormalized, rightEyeNormalized, leftIrisNormalized, rightIrisNormalized, noseNormalized, mouthNormalized, jawlineNormalized, eyebrowNormalized)
            
        } catch {
            print("❌ LandmarkExtractor: Failed to extract normalized landmark data - \(error)")
            return ([], [], [], [], [], [], [], [])
        }
    }
    
    private func calculateQualityMetrics(landmarks: FacialLandmarks?, faceConfidence: Float, imageSize: CGSize, processingNotes: inout [String]) -> LandmarkQualityMetrics {
        
        var warningFlags: [String] = []
        
        // Basic confidence check
        let landmarkDetectionConfidence = faceConfidence
        if landmarkDetectionConfidence < 0.7 {
            warningFlags.append("Low face detection confidence: \(landmarkDetectionConfidence)")
        }
        
        // Image size check
        let minDimension = min(imageSize.width, imageSize.height)
        let imageSharpness: Float = minDimension > 400 ? 1.0 : Float(minDimension / 400.0)
        if imageSharpness < 0.8 {
            warningFlags.append("Low image resolution: \(imageSize)")
        }
        
        // Illumination quality (simplified - could be enhanced with actual analysis)
        let illuminationQuality: Float = 0.8  // Placeholder - would need actual image analysis
        
        // Face angle stability (based on head pose if available)
        let faceAngleStability: Float
        if let headPose = landmarks?.headPose {
            let maxAngle = max(abs(headPose.pitch), abs(headPose.yaw), abs(headPose.roll))
            faceAngleStability = maxAngle < 15.0 ? 1.0 : max(0.3, 1.0 - maxAngle / 45.0)
            if faceAngleStability < 0.7 {
                warningFlags.append("Significant head rotation detected: pitch=\(headPose.pitch), yaw=\(headPose.yaw), roll=\(headPose.roll)")
            }
        } else {
            faceAngleStability = 0.5
            warningFlags.append("Head pose data not available")
        }
        
        // Eye openness (simplified check based on eye landmark availability)
        let eyeOpenness: Float
        if let landmarks = landmarks, !landmarks.leftEyeLandmarks.isEmpty && !landmarks.rightEyeLandmarks.isEmpty {
            eyeOpenness = 1.0
        } else {
            eyeOpenness = 0.3
            warningFlags.append("Eye landmarks not detected or insufficient")
        }
        
        // Overall recommendation
        let overallScore = (landmarkDetectionConfidence + imageSharpness + illuminationQuality + faceAngleStability + eyeOpenness) / 5.0
        let recommendedForOverlay = overallScore > 0.7 && warningFlags.count < 3
        
        if !recommendedForOverlay {
            warningFlags.append("Overall quality score too low: \(overallScore)")
        }
        
        processingNotes.append("Quality metrics - Overall: \(overallScore), Recommended: \(recommendedForOverlay)")
        processingNotes.append("Warning flags: \(warningFlags.count)")
        
        return LandmarkQualityMetrics(
            landmarkDetectionConfidence: landmarkDetectionConfidence,
            imageSharpness: imageSharpness,
            illuminationQuality: illuminationQuality,
            faceAngleStability: faceAngleStability,
            eyeOpenness: eyeOpenness,
            recommendedForOverlay: recommendedForOverlay,
            warningFlags: warningFlags
        )
    }
    
    // MARK: - DEBUGGING: Visual Bounding Box Drawing
    
    private func drawBoundingBoxesOnImage(image: CIImage, context: CIContext) -> CIImage {
        let imageSize = image.extent.size
        
        // Create UIImage for drawing
        guard let cgImage = context.createCGImage(image, from: image.extent) else {
            return image
        }
        
        let uiImage = UIImage(cgImage: cgImage)
        
        // Create graphics context for drawing
        UIGraphicsBeginImageContextWithOptions(imageSize, false, 1.0)
        guard let drawingContext = UIGraphicsGetCurrentContext() else {
            UIGraphicsEndImageContext()
            return image
        }
        
        // Draw original image
        uiImage.draw(in: CGRect(origin: .zero, size: imageSize))
        
        // Perform face detection
        let requestHandler = VNImageRequestHandler(ciImage: image, options: [:])
        let faceRequest = VNDetectFaceLandmarksRequest()
        
        do {
            try requestHandler.perform([faceRequest])
            
            if let results = faceRequest.results, let face = results.first {
                drawDebugOverlays(on: drawingContext, face: face, imageSize: imageSize)
            }
        } catch {
            print("❌ Failed to detect face for bounding box overlay: \(error)")
        }
        
        // Get the image with overlays
        guard let imageWithOverlays = UIGraphicsGetImageFromCurrentImageContext() else {
            UIGraphicsEndImageContext()
            return image
        }
        
        UIGraphicsEndImageContext()
        
        // Convert back to CIImage
        guard let cgImageWithOverlays = imageWithOverlays.cgImage else {
            return image
        }
        
        return CIImage(cgImage: cgImageWithOverlays)
    }
    
    private func drawDebugOverlays(on context: CGContext, face: VNFaceObservation, imageSize: CGSize) {
        let boundingBox = face.boundingBox
        
        // 1. Draw RAW Vision face bounding box (RED) - NO TRANSFORMATIONS
        let rawFaceRect = CGRect(
            x: boundingBox.origin.x * imageSize.width,
            y: boundingBox.origin.y * imageSize.height,
            width: boundingBox.size.width * imageSize.width,
            height: boundingBox.size.height * imageSize.height
        )
        
        context.setStrokeColor(UIColor.red.cgColor)
        context.setLineWidth(6.0)
        context.stroke(rawFaceRect)
        
        // 2. Draw RAW eye landmarks (GREEN circles) - NO TRANSFORMATIONS
        if let leftEye = face.landmarks?.leftEye, let rightEye = face.landmarks?.rightEye {
            context.setFillColor(UIColor.green.cgColor)
            
            if leftEye.pointCount > 0 {
                let leftPoint = leftEye.normalizedPoints[0]
                let leftImagePoint = CGPoint(
                    x: CGFloat(leftPoint.x) * imageSize.width,
                    y: CGFloat(leftPoint.y) * imageSize.height
                )
                context.fillEllipse(in: CGRect(x: leftImagePoint.x - 15, y: leftImagePoint.y - 15, width: 30, height: 30))
            }
            
            if rightEye.pointCount > 0 {
                let rightPoint = rightEye.normalizedPoints[0]
                let rightImagePoint = CGPoint(
                    x: CGFloat(rightPoint.x) * imageSize.width,
                    y: CGFloat(rightPoint.y) * imageSize.height
                )
                context.fillEllipse(in: CGRect(x: rightImagePoint.x - 15, y: rightImagePoint.y - 15, width: 30, height: 30))
            }
        }
        
        // 3. Draw FIXED eye region (BLUE) - using actual eye landmark positions
        let fixedEyeRegion = calculateSimpleEyeRegion(face: face, imageSize: imageSize, preferredEye: .both)
        context.setStrokeColor(UIColor.blue.cgColor)
        context.setLineWidth(8.0)  // Make it thicker to stand out
        context.stroke(fixedEyeRegion)
        
        // 4. REMOVED transformed eye regions since they're clearly wrong
        // Instead, draw Y-flipped coordinates to test if that's the issue
        
        // Test Y-flipped face rect (YELLOW)
        let yFlippedFaceRect = CGRect(
            x: rawFaceRect.origin.x,
            y: imageSize.height - rawFaceRect.origin.y - rawFaceRect.height,
            width: rawFaceRect.width,
            height: rawFaceRect.height
        )
        context.setStrokeColor(UIColor.yellow.cgColor)
        context.setLineWidth(4.0)
        context.stroke(yFlippedFaceRect)
        
        // Test Y-flipped eye landmarks (ORANGE circles)
        if let leftEye = face.landmarks?.leftEye, let rightEye = face.landmarks?.rightEye {
            context.setFillColor(UIColor.orange.cgColor)
            
            if leftEye.pointCount > 0 {
                let leftPoint = leftEye.normalizedPoints[0]
                let leftFlippedPoint = CGPoint(
                    x: CGFloat(leftPoint.x) * imageSize.width,
                    y: imageSize.height - (CGFloat(leftPoint.y) * imageSize.height)
                )
                context.fillEllipse(in: CGRect(x: leftFlippedPoint.x - 10, y: leftFlippedPoint.y - 10, width: 20, height: 20))
            }
            
            if rightEye.pointCount > 0 {
                let rightPoint = rightEye.normalizedPoints[0]
                let rightFlippedPoint = CGPoint(
                    x: CGFloat(rightPoint.x) * imageSize.width,
                    y: imageSize.height - (CGFloat(rightPoint.y) * imageSize.height)
                )
                context.fillEllipse(in: CGRect(x: rightFlippedPoint.x - 10, y: rightFlippedPoint.y - 10, width: 20, height: 20))
            }
        }
    }
}
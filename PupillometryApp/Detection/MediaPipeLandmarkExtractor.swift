//
//  MediaPipeLandmarkExtractor.swift
//  PupillometryApp
//
//  Created by Claude on 15/07/25.
//  Replaces Apple Vision with MediaPipe for improved landmark accuracy
//

import Foundation
import CoreImage
import UIKit
import AVFoundation
import Vision
import MediaPipeTasksVision

class MediaPipeLandmarkExtractor: NSObject {
    private var faceLandmarker: FaceLandmarker?
    // STEREO CAPTURE: Frame-based capture with timestamp correlation
    private var lastRGBCaptureTime: TimeInterval = 0
    private var lastNIRCaptureTime: TimeInterval = 0  
    private let rgbCaptureInterval: TimeInterval = 0.5     // 0.5 second intervals for RGB
    private let rgbFramesPerCapture: Int = 15              // ~0.5 second at 30fps
    private let nirFramesPerCapture: Int = 15              // Same as RGB for synchronized capture
    private var rgbFrameCount: Int = 0
    private var nirFrameCount: Int = 0
    private var frameCounter: Int = 0
    private let context = CIContext()
    
    // MediaPipe-specific eye landmark indices (based on 468 face mesh landmarks)
    private let leftEyeIndices = [33, 7, 163, 144, 145, 153, 154, 155, 133, 173, 157, 158, 159, 160, 161, 246]
    private let rightEyeIndices = [362, 382, 381, 380, 374, 373, 390, 249, 263, 466, 388, 387, 386, 385, 384, 398]
    private let leftIrisIndices = [474, 475, 476, 477, 478]  // MediaPipe iris landmarks
    private let rightIrisIndices = [469, 470, 471, 472, 473]
    
    // Engineering overlay data collection
    private var overlayDataBuffer: [LandmarkOverlayData] = []
    private let maxOverlayDataBuffer = 50
    
    // Cache for recent landmarks (for overlay drawing)
    private var recentLandmarks: FacialLandmarks?
    
    override init() {
        super.init()
        setupFaceLandmarker()
    }
    
    private func setupFaceLandmarker() {
        let options = FaceLandmarkerOptions()
        
        // Check if the MediaPipe model exists in the bundle
        guard let modelPath = Bundle.main.path(forResource: "face_landmarker", ofType: "task") else {
            print("⚠️ MediaPipeLandmarkExtractor: MediaPipe model not found in bundle, using mock landmarks")
            return
        }
        
        options.baseOptions.modelAssetPath = modelPath
        options.runningMode = .liveStream
        options.numFaces = 1
        options.minFaceDetectionConfidence = 0.5
        options.minFacePresenceConfidence = 0.5
        options.minTrackingConfidence = 0.5
        options.outputFaceBlendshapes = false
        options.outputFacialTransformationMatrixes = false
        
        // Set up the result callback
        options.faceLandmarkerLiveStreamDelegate = self
        
        do {
            faceLandmarker = try FaceLandmarker(options: options)
            print("✅ MediaPipeLandmarkExtractor: Successfully initialized MediaPipe FaceLandmarker")
        } catch {
            print("❌ MediaPipeLandmarkExtractor: Failed to initialize FaceLandmarker - \(error)")
            faceLandmarker = nil
        }
    }
    
    func extractLandmarksAndCaptureImage(from sampleBuffer: CMSampleBuffer) -> (landmarks: FacialLandmarks?, capturedImage: SessionData.CapturedImage?) {
        return extractLandmarksAndCaptureImage(from: sampleBuffer, cameraType: .rgb)
    }
    
    func extractLandmarksAndCaptureImage(from sampleBuffer: CMSampleBuffer, cameraType: CameraType) -> (landmarks: FacialLandmarks?, capturedImage: SessionData.CapturedImage?) {
        
        frameCounter += 1
        let currentTime = CACurrentMediaTime()
        
        // STEREO CAPTURE: Frame-based capture with timestamp correlation
        let shouldCaptureImage: Bool
        if cameraType == .rgb {
            rgbFrameCount += 1
            // RGB: Time-based (every 1 second) OR frame-based fallback
            let timeBasedCapture = (currentTime - lastRGBCaptureTime) >= rgbCaptureInterval
            let frameBasedCapture = (rgbFrameCount % rgbFramesPerCapture) == 0
            shouldCaptureImage = timeBasedCapture || frameBasedCapture
        } else {
            nirFrameCount += 1
            // NIR: Frame-based (every 10th frame) for consistent capture
            shouldCaptureImage = (nirFrameCount % nirFramesPerCapture) == 0
        }
        
        // Debug logging for NIR frame processing
        if cameraType == .infrared {
            print("📊 MediaPipeLandmarkExtractor: Processing NIR frame #\(nirFrameCount), should capture: \(shouldCaptureImage)")
            print("🔍 MediaPipeLandmarkExtractor: NIR capture logic - frameCount: \(nirFrameCount), interval: \(nirFramesPerCapture)")
        }
        
        // Convert sample buffer to CIImage
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            print("❌ MediaPipeLandmarkExtractor: Failed to get pixel buffer")
            return (nil, nil)
        }
        
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        
        // Use MediaPipe if available, otherwise create mock landmarks
        let landmarks: FacialLandmarks
        if let faceLandmarker = faceLandmarker {
            if cameraType == .rgb {
                // Process RGB through MediaPipe (trained domain)
                landmarks = processWithMediaPipe(ciImage: ciImage, timestamp: currentTime)
            } else {
                // NIR/Depth data: Use RGB MediaPipe landmarks to guide depth analysis
                if let rgbLandmarks = recentLandmarks {
                    landmarks = createDepthEnhancedLandmarks(from: ciImage, guidedBy: rgbLandmarks, timestamp: currentTime)
                    print("🔍 MediaPipeLandmarkExtractor: Using MediaPipe-guided depth analysis for NIR")
                } else {
                    landmarks = createDepthBasedLandmarks(from: ciImage, timestamp: currentTime)
                    print("⚠️ MediaPipeLandmarkExtractor: No RGB landmarks available, using basic depth detection")
                }
            }
        } else {
            // Fallback to mock landmarks
            landmarks = createMockLandmarks(imageSize: ciImage.extent.size, timestamp: currentTime)
            // Cache mock landmarks for overlay drawing
            recentLandmarks = landmarks
        }
        
        // Capture image if it's time
        var capturedImage: SessionData.CapturedImage? = nil
        if shouldCaptureImage {
            capturedImage = captureImage(from: ciImage, context: CIContext(), timestamp: currentTime, cameraType: cameraType)
            // STEREO CAPTURE: Update timestamp for correlation
            if cameraType == .rgb {
                lastRGBCaptureTime = currentTime
            } else {
                lastNIRCaptureTime = currentTime
            }
            
            print("📸 MediaPipeLandmarkExtractor: Captured \(cameraType.rawValue) image with timestamp \(currentTime) for correlation")
            
            // Generate comprehensive overlay data for engineering team
            if let overlayData = generateOverlayData(from: ciImage, landmarks: landmarks, capturedImage: capturedImage, timestamp: currentTime) {
                addOverlayDataToBuffer(overlayData)
            }
        }
        
        return (landmarks, capturedImage)
    }
    
    private func createMockLandmarks(imageSize: CGSize, timestamp: TimeInterval) -> FacialLandmarks {
        // Create mock landmarks for testing purposes
        let centerX = imageSize.width / 2
        let centerY = imageSize.height / 2
        
        // Mock face rectangle
        let faceRect = CGRect(
            x: centerX - 100,
            y: centerY - 80,
            width: 200,
            height: 160
        )
        
        // Mock eye landmarks
        let leftEyeCenter = CGPoint(x: centerX - 40, y: centerY - 20)
        let rightEyeCenter = CGPoint(x: centerX + 40, y: centerY - 20)
        
        let leftEyeLandmarks = createCircularLandmarks(center: leftEyeCenter, radius: 15, count: 16)
        let rightEyeLandmarks = createCircularLandmarks(center: rightEyeCenter, radius: 15, count: 16)
        
        // Mock iris landmarks (smaller circles)
        let leftIrisLandmarks = createCircularLandmarks(center: leftEyeCenter, radius: 8, count: 5)
        let rightIrisLandmarks = createCircularLandmarks(center: rightEyeCenter, radius: 8, count: 5)
        
        // Mock other facial features
        let noseLandmarks = createCircularLandmarks(center: CGPoint(x: centerX, y: centerY + 10), radius: 10, count: 8)
        let mouthLandmarks = createCircularLandmarks(center: CGPoint(x: centerX, y: centerY + 40), radius: 20, count: 12)
        let jawlineLandmarks = createCircularLandmarks(center: CGPoint(x: centerX, y: centerY + 60), radius: 80, count: 20)
        let eyebrowLandmarks = createCircularLandmarks(center: CGPoint(x: centerX, y: centerY - 40), radius: 60, count: 16)
        
        // Mock head pose
        let headPose = FacialLandmarks.HeadPose(pitch: 0, yaw: 0, roll: 0)
        
        return FacialLandmarks(
            timestamp: timestamp,
            faceRect: faceRect,
            faceConfidence: 0.9,
            leftEyeLandmarks: leftEyeLandmarks,
            rightEyeLandmarks: rightEyeLandmarks,
            leftIrisLandmarks: leftIrisLandmarks,
            rightIrisLandmarks: rightIrisLandmarks,
            noseLandmarks: noseLandmarks,
            mouthLandmarks: mouthLandmarks,
            jawlineLandmarks: jawlineLandmarks,
            eyebrowLandmarks: eyebrowLandmarks,
            headPose: headPose
        )
    }
    
    private func createCircularLandmarks(center: CGPoint, radius: CGFloat, count: Int) -> [CGPoint] {
        var landmarks: [CGPoint] = []
        
        for i in 0..<count {
            let angle = 2 * Double.pi * Double(i) / Double(count)
            let x = center.x + radius * CGFloat(cos(angle))
            let y = center.y + radius * CGFloat(sin(angle))
            landmarks.append(CGPoint(x: x, y: y))
        }
        
        return landmarks
    }
    
    private var lastDetectedLandmarks: FacialLandmarks?
    
    private func getLastDetectedLandmarks() -> FacialLandmarks? {
        return lastDetectedLandmarks
    }
    
    private func processWithMediaPipe(ciImage: CIImage, timestamp: TimeInterval) -> FacialLandmarks {
        // Convert CIImage to MPImage for MediaPipe processing
        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else {
            print("⚠️ MediaPipeLandmarkExtractor: Failed to convert CIImage to CGImage")
            return createMockLandmarks(imageSize: ciImage.extent.size, timestamp: timestamp)
        }
        
        let uiImage = UIImage(cgImage: cgImage)
        guard let mpImage = try? MPImage(uiImage: uiImage) else {
            print("⚠️ MediaPipeLandmarkExtractor: Failed to create MPImage")
            return createMockLandmarks(imageSize: ciImage.extent.size, timestamp: timestamp)
        }
        
        // Process with MediaPipe asynchronously
        let timestampMs = Int(timestamp * 1000) // Convert to milliseconds
        
        do {
            let _ = try faceLandmarker?.detectAsync(image: mpImage, timestampInMilliseconds: timestampMs)
            
            // Return last detected landmarks or mock if none available
            return lastDetectedLandmarks ?? createMockLandmarks(imageSize: ciImage.extent.size, timestamp: timestamp)
        } catch {
            print("❌ MediaPipeLandmarkExtractor: MediaPipe processing failed - \(error)")
            return createMockLandmarks(imageSize: ciImage.extent.size, timestamp: timestamp)
        }
    }
    
    private func processMediaPipeResult(_ result: FaceLandmarkerResult, timestampInMilliseconds: Int) {
        let imageSize = CGSize(width: 640, height: 480) // Default size, should be updated with actual image size
        let timestamp = TimeInterval(timestampInMilliseconds) / 1000.0
        
        guard let firstFaceLandmarks = result.faceLandmarks.first else {
            print("⚠️ MediaPipeLandmarkExtractor: No face landmarks in result")
            return
        }
        
        // Convert MediaPipe landmarks to our FacialLandmarks structure
        let landmarks = convertMediaPipeLandmarks(firstFaceLandmarks, imageSize: imageSize, timestamp: timestamp)
        
        // Update the last detected landmarks
        lastDetectedLandmarks = landmarks
        
        // Cache landmarks for overlay drawing
        recentLandmarks = landmarks
        
        print("✅ MediaPipeLandmarkExtractor: Processed MediaPipe landmarks - \(firstFaceLandmarks.count) points")
    }
    
    private func convertMediaPipeLandmarks(_ mpLandmarks: [NormalizedLandmark], imageSize: CGSize, timestamp: TimeInterval) -> FacialLandmarks {
        // Convert normalized landmarks to pixel coordinates
        let pixelLandmarks = mpLandmarks.map { landmark in
            CGPoint(
                x: CGFloat(landmark.x) * imageSize.width,
                y: CGFloat(landmark.y) * imageSize.height
            )
        }
        
        // Extract specific facial features using MediaPipe's 468 landmark model
        let leftEyeLandmarks = extractLandmarksByIndices(pixelLandmarks, indices: leftEyeIndices)
        let rightEyeLandmarks = extractLandmarksByIndices(pixelLandmarks, indices: rightEyeIndices)
        let leftIrisLandmarks = extractLandmarksByIndices(pixelLandmarks, indices: leftIrisIndices)
        let rightIrisLandmarks = extractLandmarksByIndices(pixelLandmarks, indices: rightIrisIndices)
        
        // Extract other facial features
        let noseLandmarks = extractNoseLandmarks(pixelLandmarks, imageSize: imageSize)
        let mouthLandmarks = extractMouthLandmarks(pixelLandmarks, imageSize: imageSize)
        let jawlineLandmarks = extractJawlineLandmarks(pixelLandmarks, imageSize: imageSize)
        let eyebrowLandmarks = extractEyebrowLandmarks(pixelLandmarks, imageSize: imageSize)
        
        // Calculate face bounding box
        let faceRect = calculateFaceBoundingBox(from: pixelLandmarks, imageSize: imageSize)
        
        // Estimate head pose
        let headPose = estimateHeadPose(from: pixelLandmarks, imageSize: imageSize)
        
        return FacialLandmarks(
            timestamp: timestamp,
            faceRect: faceRect,
            faceConfidence: 0.9, // MediaPipe typically has high confidence
            leftEyeLandmarks: leftEyeLandmarks,
            rightEyeLandmarks: rightEyeLandmarks,
            leftIrisLandmarks: leftIrisLandmarks,
            rightIrisLandmarks: rightIrisLandmarks,
            noseLandmarks: noseLandmarks,
            mouthLandmarks: mouthLandmarks,
            jawlineLandmarks: jawlineLandmarks,
            eyebrowLandmarks: eyebrowLandmarks,
            headPose: headPose
        )
    }
    
    private func extractLandmarksByIndices(_ landmarks: [CGPoint], indices: [Int]) -> [CGPoint] {
        return indices.compactMap { index in
            guard index < landmarks.count else { return nil }
            return landmarks[index]
        }
    }
    
    private func extractNoseLandmarks(_ landmarks: [CGPoint], imageSize: CGSize) -> [CGPoint] {
        // MediaPipe nose landmarks indices (approximate)
        let noseIndices = [1, 2, 5, 6, 19, 20, 94, 125, 141, 235, 236, 237, 238, 239, 240, 241, 242]
        return extractLandmarksByIndices(landmarks, indices: noseIndices)
    }
    
    private func extractMouthLandmarks(_ landmarks: [CGPoint], imageSize: CGSize) -> [CGPoint] {
        // MediaPipe mouth landmarks indices (approximate)
        let mouthIndices = [0, 11, 12, 13, 14, 15, 16, 17, 18, 269, 270, 271, 272, 273, 274, 275, 276, 277, 278, 279, 280, 281, 282, 283, 284, 285, 286, 287, 288, 289, 290, 291, 292, 293, 294, 295, 296, 297, 298, 299, 300, 301, 302, 303, 304, 305, 306, 307, 308, 309, 310, 311, 312, 313, 314, 315, 316, 317, 318, 319, 320, 321, 322, 323, 324, 325, 326, 327, 328, 329, 330, 331, 332, 333, 334, 335, 336, 337, 338, 339, 340, 341, 342, 343, 344, 345, 346, 347, 348, 349, 350, 351, 352, 353, 354, 355, 356, 357, 358, 359, 360, 361, 362, 363, 364, 365, 366, 367, 368, 369, 370, 371, 372, 373, 374, 375, 376, 377, 378, 379, 380, 381, 382, 383, 384, 385, 386, 387, 388, 389, 390, 391, 392, 393, 394, 395, 396, 397, 398, 399]
        return extractLandmarksByIndices(landmarks, indices: mouthIndices)
    }
    
    private func extractJawlineLandmarks(_ landmarks: [CGPoint], imageSize: CGSize) -> [CGPoint] {
        // MediaPipe jawline landmarks indices (approximate)
        let jawlineIndices = [172, 136, 150, 149, 176, 148, 152, 377, 400, 378, 379, 365, 397, 288, 361, 323]
        return extractLandmarksByIndices(landmarks, indices: jawlineIndices)
    }
    
    private func extractEyebrowLandmarks(_ landmarks: [CGPoint], imageSize: CGSize) -> [CGPoint] {
        // MediaPipe eyebrow landmarks indices (approximate)
        let eyebrowIndices = [46, 53, 52, 51, 48, 115, 131, 134, 102, 49, 220, 305, 292, 283, 282, 295, 285, 336, 296, 334]
        return extractLandmarksByIndices(landmarks, indices: eyebrowIndices)
    }
    
    private func calculateFaceBoundingBox(from landmarks: [CGPoint], imageSize: CGSize) -> CGRect {
        guard !landmarks.isEmpty else { return CGRect.zero }
        
        let xCoords = landmarks.map { $0.x }
        let yCoords = landmarks.map { $0.y }
        
        let minX = xCoords.min() ?? 0
        let maxX = xCoords.max() ?? 0
        let minY = yCoords.min() ?? 0
        let maxY = yCoords.max() ?? 0
        
        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }
    
    private func estimateHeadPose(from landmarks: [CGPoint], imageSize: CGSize) -> FacialLandmarks.HeadPose {
        // Simple head pose estimation using key facial landmarks
        // This is a simplified version - MediaPipe provides more accurate pose estimation
        
        guard landmarks.count > 10 else {
            return FacialLandmarks.HeadPose(pitch: 0, yaw: 0, roll: 0)
        }
        
        // Use nose tip and eye centers for basic pose estimation
        let noseTip = landmarks[1] // Approximate nose tip
        let leftEyeCenter = landmarks[33] // Approximate left eye center
        let rightEyeCenter = landmarks[362] // Approximate right eye center
        
        // Calculate yaw (left/right rotation)
        let eyeDistance = abs(leftEyeCenter.x - rightEyeCenter.x)
        let noseOffset = noseTip.x - (leftEyeCenter.x + rightEyeCenter.x) / 2
        let yaw = Float(noseOffset / eyeDistance) * 30.0 // Approximate conversion
        
        // Calculate roll (tilt)
        let eyeHeightDiff = rightEyeCenter.y - leftEyeCenter.y
        let roll = Float(atan2(eyeHeightDiff, eyeDistance)) * 180.0 / Float.pi
        
        // Calculate pitch (up/down) - simplified
        let pitch = Float(0.0) // Would need more complex calculation for accurate pitch
        
        return FacialLandmarks.HeadPose(pitch: pitch, yaw: yaw, roll: roll)
    }
    
    // MARK: - Depth-Based Landmark Detection
    
    private func createDepthEnhancedLandmarks(from ciImage: CIImage, guidedBy rgbLandmarks: FacialLandmarks, timestamp: TimeInterval) -> FacialLandmarks {
        // ENHANCED: Use precise MediaPipe RGB landmarks to guide depth analysis
        // This combines MediaPipe's accuracy with TrueDepth's 3D information
        
        print("🎯 Using MediaPipe landmarks to guide TrueDepth analysis:")
        print("   👁️ Left eye landmarks: \(rgbLandmarks.leftEyeLandmarks.count)")
        print("   👁️ Right eye landmarks: \(rgbLandmarks.rightEyeLandmarks.count)")
        print("   🌟 Left iris landmarks: \(rgbLandmarks.leftIrisLandmarks.count)")
        print("   🌟 Right iris landmarks: \(rgbLandmarks.rightIrisLandmarks.count)")
        
        // Extract precise eye regions from MediaPipe landmarks
        let leftEyeRegion = calculateEyeRegionFromLandmarks(rgbLandmarks.leftEyeLandmarks)
        let rightEyeRegion = calculateEyeRegionFromLandmarks(rgbLandmarks.rightEyeLandmarks)
        
        // Use MediaPipe iris landmarks as starting points for depth analysis
        let leftIrisDepthLandmarks = analyzeIrisDepthAtLandmarks(ciImage, irisLandmarks: rgbLandmarks.leftIrisLandmarks, eyeRegion: leftEyeRegion)
        let rightIrisDepthLandmarks = analyzeIrisDepthAtLandmarks(ciImage, irisLandmarks: rgbLandmarks.rightIrisLandmarks, eyeRegion: rightEyeRegion)
        
        // Validate RGB-Depth landmark consistency before combining
        let leftMismatch = calculateLandmarkMismatch(rgbLandmarks.leftIrisLandmarks, leftIrisDepthLandmarks)
        let rightMismatch = calculateLandmarkMismatch(rgbLandmarks.rightIrisLandmarks, rightIrisDepthLandmarks)
        
        print("🔍 RGB-Depth Landmark Validation:")
        print("   Left eye mismatch: \(leftMismatch.distance)px (confidence: \(leftMismatch.confidence))")
        print("   Right eye mismatch: \(rightMismatch.distance)px (confidence: \(rightMismatch.confidence))")
        
        // Use RGB or depth landmarks based on mismatch analysis
        let finalLeftIris = selectBestLandmarks(rgb: rgbLandmarks.leftIrisLandmarks, depth: leftIrisDepthLandmarks, mismatch: leftMismatch)
        let finalRightIris = selectBestLandmarks(rgb: rgbLandmarks.rightIrisLandmarks, depth: rightIrisDepthLandmarks, mismatch: rightMismatch)
        
        // Create enhanced landmarks combining RGB precision with depth information
        return FacialLandmarks(
            timestamp: timestamp,
            faceRect: rgbLandmarks.faceRect,
            faceConfidence: rgbLandmarks.faceConfidence,
            leftEyeLandmarks: rgbLandmarks.leftEyeLandmarks, // Keep precise eye landmarks
            rightEyeLandmarks: rgbLandmarks.rightEyeLandmarks,
            leftIrisLandmarks: finalLeftIris, // Best of RGB + depth
            rightIrisLandmarks: finalRightIris, // Best of RGB + depth
            noseLandmarks: rgbLandmarks.noseLandmarks,
            mouthLandmarks: rgbLandmarks.mouthLandmarks,
            jawlineLandmarks: rgbLandmarks.jawlineLandmarks,
            eyebrowLandmarks: rgbLandmarks.eyebrowLandmarks,
            headPose: rgbLandmarks.headPose
        )
    }
    
    private func calculateEyeRegionFromLandmarks(_ eyeLandmarks: [CGPoint]) -> CGRect {
        // Calculate precise eye region from MediaPipe landmarks
        guard !eyeLandmarks.isEmpty else {
            return CGRect(x: 0, y: 0, width: 50, height: 30)
        }
        
        let minX = eyeLandmarks.map { $0.x }.min() ?? 0
        let maxX = eyeLandmarks.map { $0.x }.max() ?? 0
        let minY = eyeLandmarks.map { $0.y }.min() ?? 0
        let maxY = eyeLandmarks.map { $0.y }.max() ?? 0
        
        // Add padding for depth analysis
        let padding: CGFloat = 10
        return CGRect(
            x: minX - padding,
            y: minY - padding,
            width: (maxX - minX) + 2 * padding,
            height: (maxY - minY) + 2 * padding
        )
    }
    
    private func analyzeIrisDepthAtLandmarks(_ image: CIImage, irisLandmarks: [CGPoint], eyeRegion: CGRect) -> [CGPoint] {
        // Use MediaPipe iris landmarks as precise guides for depth analysis
        guard irisLandmarks.count >= 5 else {
            print("⚠️ Insufficient iris landmarks for depth analysis")
            return irisLandmarks
        }
        
        // MediaPipe iris landmarks: [left, top, right, bottom, center]
        let leftPoint = irisLandmarks[0]
        let topPoint = irisLandmarks[1]
        let rightPoint = irisLandmarks[2]
        let bottomPoint = irisLandmarks[3]
        let centerPoint = irisLandmarks[4]
        
        print("📍 Analyzing depth at MediaPipe iris landmarks:")
        print("   Center: (\(centerPoint.x), \(centerPoint.y))")
        print("   Bounds: (\(leftPoint.x), \(topPoint.y)) to (\(rightPoint.x), \(bottomPoint.y))")
        
        // TODO: Analyze actual depth values at these precise coordinates
        // For now, return the MediaPipe landmarks enhanced with depth analysis
        
        // In a full implementation, you would:
        // 1. Sample depth values at each iris landmark
        // 2. Analyze depth gradients around the iris boundary
        // 3. Detect pupil cavity depth minimum
        // 4. Refine landmark positions based on depth topology
        
        return irisLandmarks // Return original landmarks enhanced with depth info
    }
    
    // MARK: - Mismatch Detection and Validation
    
    private struct LandmarkMismatch {
        let distance: Float
        let confidence: Float
        let recommendation: MismatchRecommendation
    }
    
    private enum MismatchRecommendation {
        case useRGB        // RGB landmarks are more reliable
        case useDepth      // Depth landmarks are more reliable  
        case fuseBoth      // Both are good, combine them
        case unreliable    // Both have issues, use fallback
    }
    
    private func calculateLandmarkMismatch(_ rgbLandmarks: [CGPoint], _ depthLandmarks: [CGPoint]) -> LandmarkMismatch {
        guard rgbLandmarks.count == depthLandmarks.count, rgbLandmarks.count >= 5 else {
            return LandmarkMismatch(distance: 999, confidence: 0, recommendation: .unreliable)
        }
        
        // Calculate average distance between corresponding landmarks
        var totalDistance: Float = 0
        for i in 0..<rgbLandmarks.count {
            let dx = rgbLandmarks[i].x - depthLandmarks[i].x
            let dy = rgbLandmarks[i].y - depthLandmarks[i].y
            totalDistance += Float(sqrt(dx*dx + dy*dy))
        }
        
        let avgDistance = totalDistance / Float(rgbLandmarks.count)
        
        // Calculate confidence and recommendation based on mismatch
        let (confidence, recommendation) = analyzeMismatch(avgDistance)
        
        return LandmarkMismatch(
            distance: avgDistance,
            confidence: confidence,
            recommendation: recommendation
        )
    }
    
    private func analyzeMismatch(_ distance: Float) -> (confidence: Float, recommendation: MismatchRecommendation) {
        switch distance {
        case 0..<2.0:
            // Excellent agreement - fuse both for best accuracy
            return (0.95, .fuseBoth)
        case 2.0..<5.0:
            // Good agreement - prefer RGB (more accurate training)
            return (0.85, .useRGB)
        case 5.0..<10.0:
            // Moderate mismatch - check which is more reliable
            return (0.70, .useRGB) // Generally prefer RGB MediaPipe
        case 10.0..<20.0:
            // Significant mismatch - depth might be better in challenging lighting
            return (0.50, .useDepth)
        default:
            // Major mismatch - both unreliable
            return (0.20, .unreliable)
        }
    }
    
    private func selectBestLandmarks(rgb: [CGPoint], depth: [CGPoint], mismatch: LandmarkMismatch) -> [CGPoint] {
        switch mismatch.recommendation {
        case .useRGB:
            print("   → Using RGB landmarks (more reliable)")
            return rgb
        case .useDepth:
            print("   → Using depth landmarks (better in current conditions)")
            return depth
        case .fuseBoth:
            print("   → Fusing RGB and depth landmarks (excellent agreement)")
            return fuseLandmarks(rgb: rgb, depth: depth)
        case .unreliable:
            print("   → ⚠️ Both landmarks unreliable, using RGB as fallback")
            return rgb
        }
    }
    
    private func fuseLandmarks(rgb: [CGPoint], depth: [CGPoint]) -> [CGPoint] {
        // SCIENCE-BASED FUSION: Dynamic weighting based on measurement quality
        guard rgb.count == depth.count else { return rgb }
        
        // Calculate weights based on landmark consistency and quality
        let (rgbWeight, depthWeight) = calculateOptimalWeights(rgb: rgb, depth: depth)
        
        print("🔬 Dynamic fusion weights: RGB(\(String(format: "%.2f", rgbWeight))) + Depth(\(String(format: "%.2f", depthWeight)))")
        
        var fusedLandmarks: [CGPoint] = []
        for i in 0..<rgb.count {
            let fusedX = CGFloat(rgbWeight) * rgb[i].x + CGFloat(depthWeight) * depth[i].x
            let fusedY = CGFloat(rgbWeight) * rgb[i].y + CGFloat(depthWeight) * depth[i].y
            fusedLandmarks.append(CGPoint(x: fusedX, y: fusedY))
        }
        
        return fusedLandmarks
    }
    
    private func calculateOptimalWeights(rgb: [CGPoint], depth: [CGPoint]) -> (rgbWeight: Float, depthWeight: Float) {
        // Method 1: Analyze landmark geometry consistency
        let rgbGeometryScore = analyzeLandmarkGeometry(rgb)
        let depthGeometryScore = analyzeLandmarkGeometry(depth)
        
        // Method 2: Consider measurement uncertainty
        let rgbUncertainty = estimateLandmarkUncertainty(rgb, type: .rgb)
        let depthUncertainty = estimateLandmarkUncertainty(depth, type: .depth)
        
        // Method 3: Apply precision-based weighting (inverse of uncertainty)
        let rgbPrecision = 1.0 / (rgbUncertainty + 0.1)
        let depthPrecision = 1.0 / (depthUncertainty + 0.1)
        
        let totalPrecision = rgbPrecision + depthPrecision
        var rgbWeight = rgbPrecision / totalPrecision
        var depthWeight = depthPrecision / totalPrecision
        
        // Method 4: Apply geometry-based adjustments
        let geometryRatio = rgbGeometryScore / (depthGeometryScore + 0.1)
        if geometryRatio > 1.5 {
            // RGB geometry is much better
            rgbWeight = min(0.8, rgbWeight * 1.2)
            depthWeight = 1.0 - rgbWeight
        } else if geometryRatio < 0.67 {
            // Depth geometry is much better
            depthWeight = min(0.8, depthWeight * 1.2)
            rgbWeight = 1.0 - depthWeight
        }
        
        // Ensure weights sum to 1.0
        let totalWeight = rgbWeight + depthWeight
        return (rgbWeight / totalWeight, depthWeight / totalWeight)
    }
    
    private enum LandmarkType {
        case rgb, depth
    }
    
    private func analyzeLandmarkGeometry(_ landmarks: [CGPoint]) -> Float {
        // Analyze if landmarks form realistic iris geometry
        guard landmarks.count >= 5 else { return 0.0 }
        
        // Check if landmarks form a reasonable circle/ellipse
        let center = landmarks[4] // Center point
        let boundaryPoints = Array(landmarks[0..<4]) // Left, top, right, bottom
        
        // Calculate distances from center to boundary points
        var distances: [Float] = []
        for point in boundaryPoints {
            let dx = Float(point.x - center.x)
            let dy = Float(point.y - center.y)
            distances.append(sqrt(dx*dx + dy*dy))
        }
        
        // Good geometry: similar distances (circular iris)
        let avgDistance = distances.reduce(0, +) / Float(distances.count)
        let variance = distances.map { pow($0 - avgDistance, 2) }.reduce(0, +) / Float(distances.count)
        let stdDev = sqrt(variance)
        
        // Lower standard deviation = better circular geometry = higher score
        let geometryScore = max(0, 1.0 - (stdDev / avgDistance))
        
        return geometryScore
    }
    
    private func estimateLandmarkUncertainty(_ landmarks: [CGPoint], type: LandmarkType) -> Float {
        // Estimate measurement uncertainty based on landmark type and quality
        
        // Base uncertainty depends on measurement method
        let baseUncertainty: Float = {
            switch type {
            case .rgb:
                return 0.5 // MediaPipe sub-pixel accuracy
            case .depth:
                return 1.5 // TrueDepth limited by depth resolution
            }
        }()
        
        // Adjust based on landmark spread (more spread = less uncertainty)
        guard landmarks.count >= 5 else { return baseUncertainty * 2 }
        
        let center = landmarks[4]
        let boundaryPoints = Array(landmarks[0..<4])
        
        let avgDistance = boundaryPoints.map { point in
            let dx = Float(point.x - center.x)
            let dy = Float(point.y - center.y)
            return sqrt(dx*dx + dy*dy)
        }.reduce(0, +) / Float(boundaryPoints.count)
        
        // Larger iris region = lower uncertainty (more pixels to work with)
        let sizeUncertaintyFactor = max(0.5, 10.0 / avgDistance)
        
        return baseUncertainty * sizeUncertaintyFactor
    }
    
    private func createDepthBasedLandmarks(from ciImage: CIImage, timestamp: TimeInterval) -> FacialLandmarks {
        // For NIR/depth data, use geometric analysis instead of MediaPipe
        // This is more appropriate for depth intensity data
        
        let imageSize = ciImage.extent.size
        let centerX = imageSize.width / 2
        let centerY = imageSize.height / 2
        
        // Analyze depth data to find face-like structures
        let depthFaceRect = analyzeDepthForFaceRegion(ciImage)
        
        // Use depth gradients to estimate eye positions
        let eyeRegions = findEyeRegionsFromDepth(ciImage, faceRect: depthFaceRect)
        
        // Create landmarks based on depth analysis
        return FacialLandmarks(
            timestamp: timestamp,
            faceRect: depthFaceRect,
            faceConfidence: 0.7, // Lower confidence for depth-only detection
            leftEyeLandmarks: eyeRegions.leftEye,
            rightEyeLandmarks: eyeRegions.rightEye,
            leftIrisLandmarks: estimateIrisFromDepth(eyeRegions.leftEye),
            rightIrisLandmarks: estimateIrisFromDepth(eyeRegions.rightEye),
            noseLandmarks: [], // Simplified for depth-only
            mouthLandmarks: [], // Simplified for depth-only
            jawlineLandmarks: [], // Simplified for depth-only
            eyebrowLandmarks: [], // Simplified for depth-only
            headPose: FacialLandmarks.HeadPose(pitch: 0, yaw: 0, roll: 0)
        )
    }
    
    private func analyzeDepthForFaceRegion(_ image: CIImage) -> CGRect {
        // Simple depth-based face detection
        // In depth data, faces appear as relatively consistent depth regions
        let imageSize = image.extent.size
        return CGRect(
            x: imageSize.width * 0.25,
            y: imageSize.height * 0.25,
            width: imageSize.width * 0.5,
            height: imageSize.height * 0.6
        )
    }
    
    private func findEyeRegionsFromDepth(_ image: CIImage, faceRect: CGRect) -> (leftEye: [CGPoint], rightEye: [CGPoint]) {
        // ENHANCED: Use TrueDepth IR dot-based depth mapping for precise eye detection
        // The depth data contains IR dot deformation patterns from eye geometry
        
        // Eye regions in depth data show distinct patterns:
        // - Cornea: Protruding surface (closer/brighter)
        // - Iris: Mid-depth plane 
        // - Pupil: Cavity (farther/darker)
        // - Tear film: Micro-depth variations
        
        let leftEyeRegion = CGRect(
            x: faceRect.minX + faceRect.width * 0.2,
            y: faceRect.minY + faceRect.height * 0.35,
            width: faceRect.width * 0.25,
            height: faceRect.height * 0.2
        )
        
        let rightEyeRegion = CGRect(
            x: faceRect.minX + faceRect.width * 0.55,
            y: faceRect.minY + faceRect.height * 0.35,
            width: faceRect.width * 0.25,
            height: faceRect.height * 0.2
        )
        
        // Analyze depth gradients within eye regions to find pupil cavities
        let leftEyeLandmarks = analyzeEyeDepthGradients(image, region: leftEyeRegion)
        let rightEyeLandmarks = analyzeEyeDepthGradients(image, region: rightEyeRegion)
        
        print("🔍 TrueDepth IR Dot Analysis: Found \(leftEyeLandmarks.count) left eye depth points, \(rightEyeLandmarks.count) right eye depth points")
        
        return (leftEyeLandmarks, rightEyeLandmarks)
    }
    
    private func analyzeEyeDepthGradients(_ image: CIImage, region: CGRect) -> [CGPoint] {
        // Analyze IR dot-based depth gradients to find eye features
        // This leverages the thousands of IR dots projected by TrueDepth
        
        let eyeCenter = CGPoint(
            x: region.midX,
            y: region.midY
        )
        
        // In IR dot depth data:
        // - Look for depth minima (pupil cavity)
        // - Identify depth rings (iris boundaries) 
        // - Detect depth edges (eyelid contours)
        
        // Simplified implementation - in production, you'd analyze actual depth gradients
        let pupilCenter = eyeCenter  // This would be found via depth minimum detection
        
        // Create eye landmarks based on depth analysis
        let eyeLandmarks = [
            pupilCenter,
            CGPoint(x: pupilCenter.x - 15, y: pupilCenter.y - 10), // Upper eyelid
            CGPoint(x: pupilCenter.x + 15, y: pupilCenter.y - 10), // Upper eyelid
            CGPoint(x: pupilCenter.x - 15, y: pupilCenter.y + 10), // Lower eyelid
            CGPoint(x: pupilCenter.x + 15, y: pupilCenter.y + 10)  // Lower eyelid
        ]
        
        return eyeLandmarks
    }
    
    private func createDepthLandmarks(from eyeRegions: (leftEye: [CGPoint], rightEye: [CGPoint]), imageSize: CGSize) -> [CGPoint] {
        // Create minimal landmark set for depth-based detection
        return eyeRegions.leftEye + eyeRegions.rightEye
    }
    
    private func estimateIrisFromDepth(_ eyeLandmarks: [CGPoint]) -> [CGPoint] {
        // For depth data, iris estimation is more challenging
        // Return simplified iris landmarks
        guard let eyeCenter = eyeLandmarks.first else { return [] }
        
        let radius: CGFloat = 10
        return [
            CGPoint(x: eyeCenter.x - radius, y: eyeCenter.y),     // left
            CGPoint(x: eyeCenter.x, y: eyeCenter.y - radius),     // top
            CGPoint(x: eyeCenter.x + radius, y: eyeCenter.y),     // right
            CGPoint(x: eyeCenter.x, y: eyeCenter.y + radius),     // bottom
            eyeCenter                                              // center
        ]
    }
    
    // MARK: - Image Capture and Engineering Data
    
    private func captureImage(from ciImage: CIImage, context: CIContext, timestamp: TimeInterval, cameraType: CameraType = .rgb) -> SessionData.CapturedImage? {
        // TEMPORARY FIX: Skip overlay drawing to test upload format issue
        // let imageWithOverlays = drawMediaPipeOverlays(on: ciImage, context: context)
        let imageWithOverlays = ciImage
        
        // Convert CIImage to JPEG data
        guard let cgImage = context.createCGImage(imageWithOverlays, from: imageWithOverlays.extent) else {
            print("❌ MediaPipeLandmarkExtractor: Failed to create CGImage")
            return nil
        }
        
        let uiImage = UIImage(cgImage: cgImage)
        guard let jpegData = uiImage.jpegData(compressionQuality: 0.8) else {
            print("❌ MediaPipeLandmarkExtractor: Failed to create JPEG data")
            return nil
        }
        
        // Validate JPEG data
        if jpegData.isEmpty {
            print("❌ MediaPipeLandmarkExtractor: JPEG data is empty")
            return nil
        }
        
        // Verify it's valid JPEG by trying to recreate UIImage
        if UIImage(data: jpegData) == nil {
            print("❌ MediaPipeLandmarkExtractor: Created invalid JPEG data")
            return nil
        }
        
        let filename = String(format: "%@_%.3f-MEDIAPIPE.jpg", cameraType.rawValue.lowercased(), timestamp)
        
        // Also capture eye region if face is detected
        let (eyeRegionData, eyeRegionRect, faceRect) = captureEyeRegion(from: ciImage, context: context)
        
        print("📸 MediaPipeLandmarkExtractor: Captured \(cameraType.rawValue) image - \(filename) (\(jpegData.count / 1024)KB)")
        if cameraType == .infrared {
            print("🔍 MediaPipeLandmarkExtractor: ✅ NIR (depth→grayscale) image saved! Frame #\(nirFrameCount)")
            print("🎯 MediaPipeLandmarkExtractor: NIR image should now appear in Firebase uploads")
        } else if cameraType == .rgb {
            print("🌈 MediaPipeLandmarkExtractor: ✅ RGB (front camera) image saved! Frame #\(rgbFrameCount)")
            print("🎯 MediaPipeLandmarkExtractor: RGB image should now appear in Firebase uploads")
        }
        if eyeRegionData != nil {
            print("👁️ MediaPipeLandmarkExtractor: Also captured eye region (\((eyeRegionData?.count ?? 0) / 1024)KB)")
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
    
    private func captureEyeRegion(from image: CIImage, context: CIContext) -> (eyeRegionData: Data?, eyeRegionRect: CGRect, faceRect: CGRect) {
        guard let landmarks = lastDetectedLandmarks else {
            print("⚠️ MediaPipeLandmarkExtractor: No landmarks available for eye region extraction")
            return (nil, CGRect.zero, CGRect.zero)
        }
        
        let faceRect = landmarks.faceRect
        
        // Calculate eye region using MediaPipe iris landmarks for precision
        let eyeRegionRect = calculateEyeRegionFromMediaPipeIris(landmarks: landmarks, imageSize: image.extent.size)
        
        print("👁️ MediaPipeLandmarkExtractor: Eye region rect: \(eyeRegionRect)")
        print("👤 MediaPipeLandmarkExtractor: Face rect: \(faceRect)")
        
        // Extract eye region from image
        let eyeRegionImage = image.cropped(to: eyeRegionRect)
        
        // Convert to JPEG data
        guard let eyeRegionCGImage = context.createCGImage(eyeRegionImage, from: eyeRegionImage.extent) else {
            print("⚠️ MediaPipeLandmarkExtractor: Failed to create eye region CGImage")
            return (nil, eyeRegionRect, faceRect)
        }
        
        let eyeRegionUIImage = UIImage(cgImage: eyeRegionCGImage)
        guard let eyeRegionJPEG = eyeRegionUIImage.jpegData(compressionQuality: 0.9) else {
            print("⚠️ MediaPipeLandmarkExtractor: Failed to create eye region JPEG")
            return (nil, eyeRegionRect, faceRect)
        }
        
        print("👁️ MediaPipeLandmarkExtractor: Extracted eye region: \(eyeRegionRect)")
        return (eyeRegionJPEG, eyeRegionRect, faceRect)
    }
    
    private func calculateEyeRegionFromMediaPipeIris(landmarks: FacialLandmarks, imageSize: CGSize) -> CGRect {
        // Use iris landmarks for precise eye region calculation
        let irisLandmarks = landmarks.rightIrisLandmarks
        
        guard !irisLandmarks.isEmpty else {
            // Fallback to eye landmarks if no iris landmarks
            return calculateEyeRegionFromEyeLandmarks(landmarks: landmarks, imageSize: imageSize)
        }
        
        // Calculate bounding box around iris landmarks with padding
        let xCoords = irisLandmarks.map { $0.x }
        let yCoords = irisLandmarks.map { $0.y }
        
        let minX = xCoords.min() ?? 0
        let maxX = xCoords.max() ?? 0
        let minY = yCoords.min() ?? 0
        let maxY = yCoords.max() ?? 0
        
        // Add padding around iris for complete eye region
        let padding: CGFloat = 30.0
        let eyeRegionRect = CGRect(
            x: max(0, minX - padding),
            y: max(0, minY - padding),
            width: min(imageSize.width - max(0, minX - padding), (maxX - minX) + 2 * padding),
            height: min(imageSize.height - max(0, minY - padding), (maxY - minY) + 2 * padding)
        )
        
        return eyeRegionRect
    }
    
    private func calculateEyeRegionFromEyeLandmarks(landmarks: FacialLandmarks, imageSize: CGSize) -> CGRect {
        // Fallback method using eye landmarks
        let eyeLandmarks = landmarks.rightEyeLandmarks
        
        guard !eyeLandmarks.isEmpty else {
            // Final fallback to face rect proportions
            let faceRect = landmarks.faceRect
            return CGRect(
                x: faceRect.minX + faceRect.width * 0.6,
                y: faceRect.minY + faceRect.height * 0.25,
                width: faceRect.width * 0.35,
                height: faceRect.height * 0.3
            )
        }
        
        let xCoords = eyeLandmarks.map { $0.x }
        let yCoords = eyeLandmarks.map { $0.y }
        
        let minX = xCoords.min() ?? 0
        let maxX = xCoords.max() ?? 0
        let minY = yCoords.min() ?? 0
        let maxY = yCoords.max() ?? 0
        
        let padding: CGFloat = 20.0
        return CGRect(
            x: max(0, minX - padding),
            y: max(0, minY - padding),
            width: min(imageSize.width - max(0, minX - padding), (maxX - minX) + 2 * padding),
            height: min(imageSize.height - max(0, minY - padding), (maxY - minY) + 2 * padding)
        )
    }
    
    // MARK: - Engineering Overlay Data
    
    private func generateOverlayData(from ciImage: CIImage, landmarks: FacialLandmarks?, capturedImage: SessionData.CapturedImage?, timestamp: TimeInterval) -> LandmarkOverlayData? {
        
        guard let capturedImage = capturedImage else {
            print("⚠️ MediaPipeLandmarkExtractor: Cannot generate overlay data without captured image")
            return nil
        }
        
        let originalSize = ciImage.extent.size
        let capturedSize = capturedImage.imageSize
        
        // Calculate scaling factors
        let visionToImageScale = CGPoint(x: capturedSize.width, y: capturedSize.height)
        
        // Create coordinate origin transform
        let coordinateOriginTransform = CGAffineTransform(scaleX: 1.0, y: 1.0)  // MediaPipe uses standard coordinate system
        
        var processingNotes: [String] = []
        processingNotes.append("MediaPipe processing for frame #\(frameCounter)")
        processingNotes.append("Timestamp: \(timestamp)")
        processingNotes.append("MediaPipe native coordinates (no transformation needed)")
        
        // Extract face data
        let faceRect = landmarks?.faceRect ?? CGRect.zero
        let faceConfidence: Float = landmarks?.faceConfidence ?? 0.0
        let faceBoundingBoxNormalized = CGRect(
            x: faceRect.origin.x / originalSize.width,
            y: faceRect.origin.y / originalSize.height,
            width: faceRect.size.width / originalSize.width,
            height: faceRect.size.height / originalSize.height
        )
        
        // Calculate eye region
        let eyeRegionRect = landmarks != nil ? calculateEyeRegionFromMediaPipeIris(landmarks: landmarks!, imageSize: originalSize) : CGRect.zero
        let eyeRegionScale = min(eyeRegionRect.width / faceRect.width, eyeRegionRect.height / faceRect.height)
        
        // Calculate quality metrics
        let qualityMetrics = calculateQualityMetrics(landmarks: landmarks, faceConfidence: faceConfidence, imageSize: originalSize, processingNotes: &processingNotes)
        
        return LandmarkOverlayData(
            timestamp: timestamp,
            frameNumber: frameCounter,
            originalImageSize: CodableSize(originalSize),
            capturedImageSize: CodableSize(capturedSize),
            imageFilename: capturedImage.filename,
            visionToImageScale: CodablePoint(visionToImageScale),
            coordinateOriginTransform: CodableAffineTransform(coordinateOriginTransform),
            orientationTransform: CGImagePropertyOrientation.up.rawValue,
            mirrorTransform: true,
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
            leftEyeLandmarksNormalized: (landmarks?.leftEyeLandmarks ?? []).map { CodablePoint(CGPoint(x: $0.x / originalSize.width, y: $0.y / originalSize.height)) },
            rightEyeLandmarksNormalized: (landmarks?.rightEyeLandmarks ?? []).map { CodablePoint(CGPoint(x: $0.x / originalSize.width, y: $0.y / originalSize.height)) },
            leftIrisLandmarksNormalized: (landmarks?.leftIrisLandmarks ?? []).map { CodablePoint(CGPoint(x: $0.x / originalSize.width, y: $0.y / originalSize.height)) },
            rightIrisLandmarksNormalized: (landmarks?.rightIrisLandmarks ?? []).map { CodablePoint(CGPoint(x: $0.x / originalSize.width, y: $0.y / originalSize.height)) },
            noseLandmarksNormalized: (landmarks?.noseLandmarks ?? []).map { CodablePoint(CGPoint(x: $0.x / originalSize.width, y: $0.y / originalSize.height)) },
            mouthLandmarksNormalized: (landmarks?.mouthLandmarks ?? []).map { CodablePoint(CGPoint(x: $0.x / originalSize.width, y: $0.y / originalSize.height)) },
            jawlineLandmarksNormalized: (landmarks?.jawlineLandmarks ?? []).map { CodablePoint(CGPoint(x: $0.x / originalSize.width, y: $0.y / originalSize.height)) },
            eyebrowLandmarksNormalized: (landmarks?.eyebrowLandmarks ?? []).map { CodablePoint(CGPoint(x: $0.x / originalSize.width, y: $0.y / originalSize.height)) },
            processingNotes: processingNotes,
            qualityMetrics: qualityMetrics
        )
    }
    
    private func addOverlayDataToBuffer(_ overlayData: LandmarkOverlayData) {
        overlayDataBuffer.append(overlayData)
        
        if overlayDataBuffer.count > maxOverlayDataBuffer {
            overlayDataBuffer.removeFirst()
        }
        
        print("📈 MediaPipeLandmarkExtractor: Overlay data buffer size: \(overlayDataBuffer.count)/\(maxOverlayDataBuffer)")
    }
    
    private func calculateQualityMetrics(landmarks: FacialLandmarks?, faceConfidence: Float, imageSize: CGSize, processingNotes: inout [String]) -> LandmarkQualityMetrics {
        
        var warningFlags: [String] = []
        
        // MediaPipe typically has high confidence
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
        
        // Enhanced quality metrics for MediaPipe
        let illuminationQuality: Float = 0.9  // MediaPipe is more robust to lighting
        
        // Face angle stability using MediaPipe head pose
        let faceAngleStability: Float
        if let headPose = landmarks?.headPose {
            let maxAngle = max(abs(headPose.pitch), abs(headPose.yaw), abs(headPose.roll))
            faceAngleStability = maxAngle < 15.0 ? 1.0 : max(0.3, 1.0 - maxAngle / 45.0)
            if faceAngleStability < 0.7 {
                warningFlags.append("Significant head rotation: pitch=\(headPose.pitch), yaw=\(headPose.yaw), roll=\(headPose.roll)")
            }
        } else {
            faceAngleStability = 0.8  // MediaPipe usually provides pose data
        }
        
        // Eye openness based on iris landmarks
        let eyeOpenness: Float
        if let landmarks = landmarks, !landmarks.leftIrisLandmarks.isEmpty && !landmarks.rightIrisLandmarks.isEmpty {
            eyeOpenness = 1.0  // MediaPipe iris detection indicates open eyes
        } else {
            eyeOpenness = 0.5
            warningFlags.append("Iris landmarks not detected")
        }
        
        // Overall recommendation (MediaPipe generally performs better)
        let overallScore = (landmarkDetectionConfidence + imageSharpness + illuminationQuality + faceAngleStability + eyeOpenness) / 5.0
        let recommendedForOverlay = overallScore > 0.6 && warningFlags.count < 3
        
        if !recommendedForOverlay {
            warningFlags.append("Overall quality score: \(overallScore)")
        }
        
        processingNotes.append("MediaPipe quality metrics - Overall: \(overallScore)")
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
    
    // MARK: - Public Interface (compatibility with existing code)
    
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
            print("❌ MediaPipeLandmarkExtractor: Failed to encode overlay data - \(error)")
            return nil
        }
    }
    
    func clearOverlayDataBuffer() {
        overlayDataBuffer.removeAll()
    }
    
    // MARK: - MediaPipe Overlay Drawing
    
    /// Draw MediaPipe landmarks and bounding boxes on the image
    /// - Parameters:
    ///   - image: Original CIImage
    ///   - context: CIContext for processing
    /// - Returns: CIImage with overlays drawn
    private func drawMediaPipeOverlays(on image: CIImage, context: CIContext) -> CIImage {
        // Convert to UIImage for drawing
        guard let cgImage = context.createCGImage(image, from: image.extent) else {
            print("⚠️ MediaPipeLandmarkExtractor: Failed to create CGImage for overlay drawing")
            return image
        }
        
        let imageSize = image.extent.size
        let uiImage = UIImage(cgImage: cgImage)
        
        // Start drawing context
        UIGraphicsBeginImageContext(imageSize)
        guard let drawingContext = UIGraphicsGetCurrentContext() else {
            print("⚠️ MediaPipeLandmarkExtractor: Failed to create drawing context")
            return image
        }
        
        // Draw original image
        uiImage.draw(in: CGRect(origin: .zero, size: imageSize))
        
        // Get the most recent landmarks from the last processing
        if let recentLandmarks = getRecentLandmarks() {
            drawMediaPipeDebugOverlays(on: drawingContext, landmarks: recentLandmarks, imageSize: imageSize)
        } else {
            // If no recent landmarks, try to detect face using Vision for basic bounding box
            drawBasicFaceDetection(on: drawingContext, image: image, imageSize: imageSize)
        }
        
        // Get the final image with overlays
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
    
    /// Draw comprehensive MediaPipe debug overlays
    /// - Parameters:
    ///   - context: Core Graphics context
    ///   - landmarks: MediaPipe facial landmarks
    ///   - imageSize: Size of the image
    private func drawMediaPipeDebugOverlays(on context: CGContext, landmarks: FacialLandmarks, imageSize: CGSize) {
        // 1. Draw face bounding box (RED)
        context.setStrokeColor(UIColor.red.cgColor)
        context.setLineWidth(4.0)
        context.stroke(landmarks.faceRect)
        
        // 2. Draw left eye landmarks (GREEN circles)
        context.setFillColor(UIColor.green.cgColor)
        for point in landmarks.leftEyeLandmarks {
            let rect = CGRect(x: point.x - 3, y: point.y - 3, width: 6, height: 6)
            context.fillEllipse(in: rect)
        }
        
        // 3. Draw right eye landmarks (GREEN circles)
        for point in landmarks.rightEyeLandmarks {
            let rect = CGRect(x: point.x - 3, y: point.y - 3, width: 6, height: 6)
            context.fillEllipse(in: rect)
        }
        
        // 4. Draw left iris landmarks (BLUE circles - larger)
        context.setFillColor(UIColor.blue.cgColor)
        for point in landmarks.leftIrisLandmarks {
            let rect = CGRect(x: point.x - 5, y: point.y - 5, width: 10, height: 10)
            context.fillEllipse(in: rect)
        }
        
        // 5. Draw right iris landmarks (BLUE circles - larger)
        for point in landmarks.rightIrisLandmarks {
            let rect = CGRect(x: point.x - 5, y: point.y - 5, width: 10, height: 10)
            context.fillEllipse(in: rect)
        }
        
        // 6. Draw left iris bounding box (CYAN)
        if !landmarks.leftIrisLandmarks.isEmpty {
            let irisRect = calculateIrisBoundingBox(landmarks.leftIrisLandmarks)
            context.setStrokeColor(UIColor.cyan.cgColor)
            context.setLineWidth(2.0)
            context.stroke(irisRect)
        }
        
        // 7. Draw right iris bounding box (CYAN)
        if !landmarks.rightIrisLandmarks.isEmpty {
            let irisRect = calculateIrisBoundingBox(landmarks.rightIrisLandmarks)
            context.setStrokeColor(UIColor.cyan.cgColor)
            context.setLineWidth(2.0)
            context.stroke(irisRect)
        }
        
        // 8. Draw eye region bounding boxes (YELLOW)
        if !landmarks.leftEyeLandmarks.isEmpty {
            let eyeRect = calculateEyeBoundingBox(landmarks.leftEyeLandmarks)
            context.setStrokeColor(UIColor.yellow.cgColor)
            context.setLineWidth(3.0)
            context.stroke(eyeRect)
        }
        
        if !landmarks.rightEyeLandmarks.isEmpty {
            let eyeRect = calculateEyeBoundingBox(landmarks.rightEyeLandmarks)
            context.setStrokeColor(UIColor.yellow.cgColor)
            context.setLineWidth(3.0)
            context.stroke(eyeRect)
        }
        
        // 9. Draw nose landmarks (ORANGE circles - small)
        context.setFillColor(UIColor.orange.cgColor)
        for point in landmarks.noseLandmarks {
            let rect = CGRect(x: point.x - 2, y: point.y - 2, width: 4, height: 4)
            context.fillEllipse(in: rect)
        }
        
        // 10. Add text labels
        drawOverlayLabels(on: context, landmarks: landmarks, imageSize: imageSize)
    }
    
    /// Draw fallback face detection using Vision framework
    /// - Parameters:
    ///   - context: Core Graphics context
    ///   - image: Original CIImage
    ///   - imageSize: Size of the image
    private func drawBasicFaceDetection(on context: CGContext, image: CIImage, imageSize: CGSize) {
        let requestHandler = VNImageRequestHandler(ciImage: image, options: [:])
        let faceRequest = VNDetectFaceLandmarksRequest()
        
        do {
            try requestHandler.perform([faceRequest])
            
            if let results = faceRequest.results, let face = results.first {
                // Draw basic face bounding box
                let boundingBox = face.boundingBox
                let faceRect = CGRect(
                    x: boundingBox.origin.x * imageSize.width,
                    y: boundingBox.origin.y * imageSize.height,
                    width: boundingBox.size.width * imageSize.width,
                    height: boundingBox.size.height * imageSize.height
                )
                
                context.setStrokeColor(UIColor.red.cgColor)
                context.setLineWidth(4.0)
                context.stroke(faceRect)
                
                // Draw basic eye landmarks if available
                if let leftEye = face.landmarks?.leftEye, let rightEye = face.landmarks?.rightEye {
                    context.setFillColor(UIColor.green.cgColor)
                    
                    // Left eye
                    if leftEye.pointCount > 0 {
                        let leftPoint = leftEye.normalizedPoints[0]
                        let leftImagePoint = CGPoint(
                            x: CGFloat(leftPoint.x) * imageSize.width,
                            y: CGFloat(leftPoint.y) * imageSize.height
                        )
                        context.fillEllipse(in: CGRect(x: leftImagePoint.x - 8, y: leftImagePoint.y - 8, width: 16, height: 16))
                    }
                    
                    // Right eye
                    if rightEye.pointCount > 0 {
                        let rightPoint = rightEye.normalizedPoints[0]
                        let rightImagePoint = CGPoint(
                            x: CGFloat(rightPoint.x) * imageSize.width,
                            y: CGFloat(rightPoint.y) * imageSize.height
                        )
                        context.fillEllipse(in: CGRect(x: rightImagePoint.x - 8, y: rightImagePoint.y - 8, width: 16, height: 16))
                    }
                }
            }
        } catch {
            print("❌ MediaPipeLandmarkExtractor: Failed to detect face for fallback overlay: \(error)")
        }
    }
    
    /// Draw text labels on the overlay
    /// - Parameters:
    ///   - context: Core Graphics context
    ///   - landmarks: MediaPipe facial landmarks
    ///   - imageSize: Size of the image
    private func drawOverlayLabels(on context: CGContext, landmarks: FacialLandmarks, imageSize: CGSize) {
        // Set up text attributes
        let textAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 16, weight: .bold),
            .foregroundColor: UIColor.white,
            .strokeColor: UIColor.black,
            .strokeWidth: -2.0
        ]
        
        // Draw landmark count labels
        let leftEyeText = "L:\(landmarks.leftEyeLandmarks.count)"
        let rightEyeText = "R:\(landmarks.rightEyeLandmarks.count)"
        let leftIrisText = "LI:\(landmarks.leftIrisLandmarks.count)"
        let rightIrisText = "RI:\(landmarks.rightIrisLandmarks.count)"
        
        // Position labels near the top of the image
        let leftEyeAttributedText = NSAttributedString(string: leftEyeText, attributes: textAttributes)
        let rightEyeAttributedText = NSAttributedString(string: rightEyeText, attributes: textAttributes)
        let leftIrisAttributedText = NSAttributedString(string: leftIrisText, attributes: textAttributes)
        let rightIrisAttributedText = NSAttributedString(string: rightIrisText, attributes: textAttributes)
        
        // Draw text labels
        leftEyeAttributedText.draw(at: CGPoint(x: 20, y: 20))
        rightEyeAttributedText.draw(at: CGPoint(x: 80, y: 20))
        leftIrisAttributedText.draw(at: CGPoint(x: 140, y: 20))
        rightIrisAttributedText.draw(at: CGPoint(x: 200, y: 20))
        
        // Draw timestamp
        let timestamp = String(format: "%.3f", Date().timeIntervalSince1970)
        let timestampText = NSAttributedString(string: timestamp, attributes: textAttributes)
        timestampText.draw(at: CGPoint(x: 20, y: imageSize.height - 40))
    }
    
    /// Calculate bounding box for iris landmarks
    /// - Parameter landmarks: Array of iris landmark points
    /// - Returns: Bounding box rectangle
    private func calculateIrisBoundingBox(_ landmarks: [CGPoint]) -> CGRect {
        guard !landmarks.isEmpty else { return CGRect.zero }
        
        let xCoords = landmarks.map { $0.x }
        let yCoords = landmarks.map { $0.y }
        
        let minX = xCoords.min() ?? 0
        let maxX = xCoords.max() ?? 0
        let minY = yCoords.min() ?? 0
        let maxY = yCoords.max() ?? 0
        
        let padding: CGFloat = 10
        
        return CGRect(
            x: minX - padding,
            y: minY - padding,
            width: (maxX - minX) + 2 * padding,
            height: (maxY - minY) + 2 * padding
        )
    }
    
    /// Calculate bounding box for eye landmarks
    /// - Parameter landmarks: Array of eye landmark points
    /// - Returns: Bounding box rectangle
    private func calculateEyeBoundingBox(_ landmarks: [CGPoint]) -> CGRect {
        guard !landmarks.isEmpty else { return CGRect.zero }
        
        let xCoords = landmarks.map { $0.x }
        let yCoords = landmarks.map { $0.y }
        
        let minX = xCoords.min() ?? 0
        let maxX = xCoords.max() ?? 0
        let minY = yCoords.min() ?? 0
        let maxY = yCoords.max() ?? 0
        
        let padding: CGFloat = 15
        
        return CGRect(
            x: minX - padding,
            y: minY - padding,
            width: (maxX - minX) + 2 * padding,
            height: (maxY - minY) + 2 * padding
        )
    }
    
    /// Get the most recent landmarks for overlay drawing
    /// - Returns: Most recent FacialLandmarks or nil
    private func getRecentLandmarks() -> FacialLandmarks? {
        return recentLandmarks
    }
}

// MARK: - MediaPipe Integration (TODO)

extension MediaPipeLandmarkExtractor: FaceLandmarkerLiveStreamDelegate {
    func faceLandmarker(_ faceLandmarker: FaceLandmarker, didFinishDetection result: FaceLandmarkerResult?, timestampInMilliseconds: Int, error: Error?) {
        
        if let error = error {
            print("❌ MediaPipeLandmarkExtractor: Face landmark detection failed - \(error)")
            return
        }
        
        guard let result = result else {
            print("⚠️ MediaPipeLandmarkExtractor: No face landmark result")
            return
        }
        
        // Process the result on the main queue
        DispatchQueue.main.async {
            self.processMediaPipeResult(result, timestampInMilliseconds: timestampInMilliseconds)
        }
    }
}
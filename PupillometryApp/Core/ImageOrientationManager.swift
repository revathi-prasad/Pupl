//
//  ImageOrientationManager.swift
//  PupillometryApp
//
//  Created by Claude Code on 12/07/25.
//

import Foundation
import UIKit
import CoreImage
import AVFoundation
import Vision

// MARK: - Image Orientation Detection and Correction
class ImageOrientationManager {
    
    enum DetectedOrientation {
        case portrait          // Normal upright
        case portraitUpsideDown // Upside down
        case landscapeLeft     // Rotated 90° counterclockwise
        case landscapeRight    // Rotated 90° clockwise
        case unknown
    }
    
    // MARK: - Orientation Detection
    static func detectImageOrientation(from ciImage: CIImage) -> DetectedOrientation {
        // Use Vision framework to detect face orientation
        let requestHandler = VNImageRequestHandler(ciImage: ciImage, options: [:])
        let faceRequest = VNDetectFaceLandmarksRequest()
        
        do {
            try requestHandler.perform([faceRequest])
            
            guard let results = faceRequest.results,
                  let face = results.first,
                  let landmarks = face.landmarks else {
                print("⚠️ ImageOrientationManager: No face detected for orientation analysis")
                return .unknown
            }
            
            // Analyze face landmarks to determine orientation
            return analyzeFrameOrientation(landmarks: landmarks, imageSize: ciImage.extent.size)
            
        } catch {
            print("❌ ImageOrientationManager: Face detection failed - \(error)")
            return .unknown
        }
    }
    
    private static func analyzeFrameOrientation(landmarks: VNFaceLandmarks2D, imageSize: CGSize) -> DetectedOrientation {
        // Get nose and eye positions to determine face orientation
        guard let nose = landmarks.nose?.normalizedPoints.first,
              let leftEye = landmarks.leftEye?.normalizedPoints.first,
              let rightEye = landmarks.rightEye?.normalizedPoints.first else {
            return .unknown
        }
        
        // Convert normalized coordinates to actual image coordinates
        let nosePoint = CGPoint(x: nose.x * imageSize.width, y: nose.y * imageSize.height)
        let leftEyePoint = CGPoint(x: leftEye.x * imageSize.width, y: leftEye.y * imageSize.height)
        let rightEyePoint = CGPoint(x: rightEye.x * imageSize.width, y: rightEye.y * imageSize.height)
        
        // Calculate eye line angle
        let eyeLineVector = CGPoint(x: rightEyePoint.x - leftEyePoint.x, y: rightEyePoint.y - leftEyePoint.y)
        let eyeLineAngle = atan2(eyeLineVector.y, eyeLineVector.x) * 180 / .pi
        
        // Determine orientation based on eye line angle and face position
        let imageRatio = imageSize.width / imageSize.height
        
        if imageRatio > 1.2 { // Landscape image
            if abs(eyeLineAngle) < 30 { // Eyes roughly horizontal
                return nosePoint.y < (leftEyePoint.y + rightEyePoint.y) / 2 ? .landscapeRight : .landscapeLeft
            } else if abs(eyeLineAngle - 90) < 30 || abs(eyeLineAngle + 90) < 30 { // Eyes roughly vertical
                return nosePoint.x > (leftEyePoint.x + rightEyePoint.x) / 2 ? .portrait : .portraitUpsideDown
            }
        } else { // Portrait image
            if abs(eyeLineAngle) < 30 { // Eyes roughly horizontal
                return nosePoint.y > (leftEyePoint.y + rightEyePoint.y) / 2 ? .portrait : .portraitUpsideDown
            } else if abs(eyeLineAngle - 90) < 30 || abs(eyeLineAngle + 90) < 30 { // Eyes roughly vertical
                return nosePoint.x < (leftEyePoint.x + rightEyePoint.x) / 2 ? .landscapeRight : .landscapeLeft
            }
        }
        
        return .unknown
    }
    
    // MARK: - Image Correction
    static func correctImageOrientation(_ ciImage: CIImage, orientation: DetectedOrientation) -> CIImage {
        switch orientation {
        case .portrait:
            return ciImage // No correction needed
        case .portraitUpsideDown:
            return ciImage.transformed(by: CGAffineTransform(rotationAngle: .pi))
        case .landscapeLeft:
            return ciImage.transformed(by: CGAffineTransform(rotationAngle: .pi / 2))
        case .landscapeRight:
            return ciImage.transformed(by: CGAffineTransform(rotationAngle: -.pi / 2))
        case .unknown:
            return ciImage // Return original if orientation unknown
        }
    }
    
    // MARK: - Eye Region Calculation (Orientation-Aware)
    static func calculateEyeRegion(faceRect: CGRect, orientation: DetectedOrientation, preferredEye: EyePreference = .right) -> CGRect {
        
        switch orientation {
        case .portrait:
            // Standard portrait orientation - FIXED for front camera coordinate system
            // Eyes are in the UPPER portion of the face (around 20-40% from top)
            if preferredEye == .right {
                return CGRect(
                    x: faceRect.minX + faceRect.width * 0.55,
                    y: faceRect.minY + faceRect.height * 0.20,  // FIXED: Eyes are higher up
                    width: faceRect.width * 0.35,
                    height: faceRect.height * 0.25
                )
            } else {
                return CGRect(
                    x: faceRect.minX + faceRect.width * 0.1,
                    y: faceRect.minY + faceRect.height * 0.20,  // FIXED: Eyes are higher up
                    width: faceRect.width * 0.35,
                    height: faceRect.height * 0.25
                )
            }
            
        case .portraitUpsideDown:
            // Upside down
            if preferredEye == .right {
                return CGRect(
                    x: faceRect.minX + faceRect.width * 0.1,
                    y: faceRect.minY + faceRect.height * 0.4,
                    width: faceRect.width * 0.35,
                    height: faceRect.height * 0.25
                )
            } else {
                return CGRect(
                    x: faceRect.minX + faceRect.width * 0.55,
                    y: faceRect.minY + faceRect.height * 0.4,
                    width: faceRect.width * 0.35,
                    height: faceRect.height * 0.25
                )
            }
            
        case .landscapeLeft:
            // Rotated 90° left (face sideways, top of head to left)
            if preferredEye == .right {
                return CGRect(
                    x: faceRect.minX + faceRect.width * 0.35,
                    y: faceRect.minY + faceRect.height * 0.1,
                    width: faceRect.width * 0.25,
                    height: faceRect.height * 0.35
                )
            } else {
                return CGRect(
                    x: faceRect.minX + faceRect.width * 0.35,
                    y: faceRect.minY + faceRect.height * 0.55,
                    width: faceRect.width * 0.25,
                    height: faceRect.height * 0.35
                )
            }
            
        case .landscapeRight:
            // Rotated 90° right (face sideways, top of head to right)
            if preferredEye == .right {
                return CGRect(
                    x: faceRect.minX + faceRect.width * 0.4,
                    y: faceRect.minY + faceRect.height * 0.55,
                    width: faceRect.width * 0.25,
                    height: faceRect.height * 0.35
                )
            } else {
                return CGRect(
                    x: faceRect.minX + faceRect.width * 0.4,
                    y: faceRect.minY + faceRect.height * 0.1,
                    width: faceRect.width * 0.25,
                    height: faceRect.height * 0.35
                )
            }
            
        case .unknown:
            // Fallback to adaptive detection
            return calculateAdaptiveEyeRegion(faceRect: faceRect, preferredEye: preferredEye)
        }
    }
    
    private static func calculateAdaptiveEyeRegion(faceRect: CGRect, preferredEye: EyePreference) -> CGRect {
        // Use a larger, more generic region when orientation is unclear
        return CGRect(
            x: faceRect.minX + faceRect.width * 0.2,
            y: faceRect.minY + faceRect.height * 0.2,
            width: faceRect.width * 0.6,
            height: faceRect.height * 0.4
        )
    }
    
    // MARK: - Device Orientation Integration
    static func getDeviceOrientation() -> DetectedOrientation {
        switch UIDevice.current.orientation {
        case .portrait:
            return .portrait
        case .portraitUpsideDown:
            return .portraitUpsideDown
        case .landscapeLeft:
            return .landscapeLeft
        case .landscapeRight:
            return .landscapeRight
        default:
            return .unknown
        }
    }
    
    // MARK: - Comprehensive Orientation Analysis
    static func analyzeOrientation(from ciImage: CIImage) -> OrientationAnalysis {
        let detectedOrientation = detectImageOrientation(from: ciImage)
        let deviceOrientation = getDeviceOrientation()
        let imageRatio = ciImage.extent.width / ciImage.extent.height
        
        // Determine the most likely actual orientation
        let recommendedOrientation: DetectedOrientation
        
        if detectedOrientation != .unknown {
            recommendedOrientation = detectedOrientation
        } else if deviceOrientation != .unknown {
            recommendedOrientation = deviceOrientation
        } else {
            // Fallback based on image aspect ratio
            recommendedOrientation = imageRatio > 1.2 ? .landscapeRight : .portrait
        }
        
        return OrientationAnalysis(
            detectedFromFace: detectedOrientation,
            deviceOrientation: deviceOrientation,
            recommendedOrientation: recommendedOrientation,
            imageAspectRatio: imageRatio,
            confidence: calculateOrientationConfidence(detected: detectedOrientation, device: deviceOrientation)
        )
    }
    
    private static func calculateOrientationConfidence(detected: DetectedOrientation, device: DetectedOrientation) -> Float {
        if detected == device && detected != .unknown {
            return 1.0 // High confidence
        } else if detected != .unknown {
            return 0.8 // Medium-high confidence
        } else if device != .unknown {
            return 0.6 // Medium confidence
        } else {
            return 0.3 // Low confidence
        }
    }
}

// MARK: - Supporting Types
enum EyePreference {
    case left
    case right
    case both
}

struct OrientationAnalysis {
    let detectedFromFace: ImageOrientationManager.DetectedOrientation
    let deviceOrientation: ImageOrientationManager.DetectedOrientation
    let recommendedOrientation: ImageOrientationManager.DetectedOrientation
    let imageAspectRatio: Double
    let confidence: Float
}
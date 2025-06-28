// CameraManager.swift

import AVFoundation
import UIKit
import Vision

protocol CameraManagerDelegate: AnyObject {
    func cameraManager(_ manager: CameraManager, didOutput sampleBuffer: CMSampleBuffer, from camera: CameraType)
    func cameraManager(_ manager: CameraManager, didEncounterError error: Error)
}

enum CameraType {
    case nir
    case rgb
}

class CameraManager: NSObject {
    weak var delegate: CameraManagerDelegate?
    
    // Camera session configuration
    private let captureSession = AVCaptureSession()
    private var isMultiCamSupported: Bool {
        return AVCaptureMultiCamSession.isMultiCamSupported
    }
    
    // Camera outputs
    private var videoOutput: AVCaptureVideoDataOutput?
    private var nirOutput: AVCaptureVideoDataOutput?
    
    // Processing queues
    private let sessionQueue = DispatchQueue(label: "camera.session.queue")
    private let rgbProcessingQueue = DispatchQueue(label: "camera.rgb.processing", qos: .userInitiated)
    private let nirProcessingQueue = DispatchQueue(label: "camera.nir.processing", qos: .userInitiated)
    
    private var isSessionRunning = false
    private var rgbPreviewLayer: AVCaptureVideoPreviewLayer?
    
    override init() {
        super.init()
        setupSession()
    }
    
    // Configure preview layer for UI
    func previewLayer(for view: UIView) -> AVCaptureVideoPreviewLayer {
        if let existingLayer = rgbPreviewLayer {
            return existingLayer
        }
        
        let layer = AVCaptureVideoPreviewLayer(session: captureSession)
        layer.videoGravity = .resizeAspectFill
        layer.frame = view.bounds
        rgbPreviewLayer = layer
        return layer
    }
    
    private func setupSession() {
        sessionQueue.async { [weak self] in
            self?.configureSession()
        }
    }
    
    private func configureSession() {
        captureSession.beginConfiguration()
        
        // Set quality level
        captureSession.sessionPreset = .high
        
        // Configure based on device capabilities
        if isMultiCamSupported {
            setupDualCamera()
        } else {
            setupSingleCamera()
        }
        
        captureSession.commitConfiguration()
    }
    
    private func setupDualCamera() {
        // Try to get TrueDepth camera first, then fallback to wide angle
        var frontCamera: AVCaptureDevice?
        
        // iPhone 11 and newer support TrueDepth
        if #available(iOS 13.0, *) {
            frontCamera = AVCaptureDevice.default(.builtInTrueDepthCamera, for: .video, position: .front)
        }
        
        // Fallback to wide angle camera if TrueDepth not available
        if frontCamera == nil {
            frontCamera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front)
        }
        
        guard let camera = frontCamera else {
            delegate?.cameraManager(self, didEncounterError: CameraError.noCameraAvailable)
            return
        }
        
        do {
            // Configure front camera for RGB
            let rgbInput = try AVCaptureDeviceInput(device: camera)
            if captureSession.canAddInput(rgbInput) {
                captureSession.addInput(rgbInput)
            }
            
            // Configure RGB output
            let rgbOutput = AVCaptureVideoDataOutput()
            rgbOutput.videoSettings = [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
            ]
            rgbOutput.setSampleBufferDelegate(self, queue: rgbProcessingQueue)
            
            if captureSession.canAddOutput(rgbOutput) {
                captureSession.addOutput(rgbOutput)
                videoOutput = rgbOutput
            }
            
            // Try to set optimal frame rate for device
            try configureCameraForHighFrameRate(camera)
            
        } catch {
            delegate?.cameraManager(self, didEncounterError: error)
        }
    }
    
    private func setupSingleCamera() {
        // Fall back to single camera mode
        guard let frontCamera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front) else {
            delegate?.cameraManager(self, didEncounterError: CameraError.noCameraAvailable)
            return
        }
        
        do {
            let input = try AVCaptureDeviceInput(device: frontCamera)
            
            if captureSession.canAddInput(input) {
                captureSession.addInput(input)
            }
            
            // Configure output
            let output = AVCaptureVideoDataOutput()
            output.videoSettings = [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
            ]
            output.setSampleBufferDelegate(self, queue: rgbProcessingQueue)
            
            if captureSession.canAddOutput(output) {
                captureSession.addOutput(output)
                videoOutput = output
            }
            
            // Try to set higher frame rate
            try configureCameraForHighFrameRate(frontCamera)
            
        } catch {
            delegate?.cameraManager(self, didEncounterError: error)
        }
    }
    
    private func configureCameraForHighFrameRate(_ device: AVCaptureDevice) throws {
        print("🎥 Configuring frame rate for device: \(device.localizedName)")
        
        // iPhone 11 front camera supports max 30 FPS, be conservative
        let maxAllowedFPS: Double = 30.0
        
        // Find the best available format and frame rate
        var bestFormat: AVCaptureDevice.Format?
        var bestFrameRate: Double = 15.0 // Safe fallback
        
        // Examine all available formats
        for format in device.formats {
            let dimensions = CMVideoFormatDescriptionGetDimensions(format.formatDescription)
            let width = dimensions.width
            let height = dimensions.height
            
            // Prefer reasonable resolutions for pupillometry (not too high, not too low)
            let isGoodResolution = width >= 640 && width <= 1280
            
            if isGoodResolution {
                print("📱 Found format: \(width)x\(height)")
                
                // Find the highest supported frame rate for this format
                for range in format.videoSupportedFrameRateRanges {
                    print("  📊 FPS range: \(range.minFrameRate) - \(range.maxFrameRate)")
                    
                    let availableMaxFPS = min(range.maxFrameRate, maxAllowedFPS)
                    if availableMaxFPS > bestFrameRate {
                        bestFrameRate = availableMaxFPS
                        bestFormat = format
                        print("  ✅ New best: \(bestFrameRate) FPS")
                    }
                }
            }
        }
        
        // Apply the best configuration found
        guard let format = bestFormat else {
            print("⚠️ No suitable format found, using default")
            return
        }
        
        do {
            try device.lockForConfiguration()
            
            print("🔧 Setting format with max FPS: \(bestFrameRate)")
            device.activeFormat = format
            
            // Set frame rate with error handling
            let frameDuration = CMTime(value: 1, timescale: Int32(bestFrameRate))
            
            // Validate frame duration is supported
            if let range = format.videoSupportedFrameRateRanges.first(where: { 
                $0.minFrameRate <= bestFrameRate && $0.maxFrameRate >= bestFrameRate 
            }) {
                device.activeVideoMinFrameDuration = frameDuration
                device.activeVideoMaxFrameDuration = frameDuration
                print("✅ Successfully set frame rate to \(bestFrameRate) FPS")
            } else {
                print("⚠️ Frame rate \(bestFrameRate) not supported, using device default")
            }
            
            // Set focus and exposure for pupillometry
            if device.isFocusModeSupported(.continuousAutoFocus) {
                device.focusMode = .continuousAutoFocus
                print("✅ Set continuous autofocus")
            }
            
            if device.isExposureModeSupported(.continuousAutoExposure) {
                device.exposureMode = .continuousAutoExposure
                print("✅ Set continuous auto exposure")
            }
            
            device.unlockForConfiguration()
            
        } catch {
            print("❌ Error configuring camera: \(error.localizedDescription)")
            throw error
        }
    }
    
    func startSession() {
        sessionQueue.async { [weak self] in
            guard let self = self, !self.isSessionRunning else { return }
            self.captureSession.startRunning()
            self.isSessionRunning = true
        }
    }
    
    func stopSession() {
        print("🛑 CameraManager: Stopping session")
        sessionQueue.async { [weak self] in
            guard let self = self, self.isSessionRunning else { 
                print("⚠️ CameraManager: Session already stopped or nil")
                return 
            }
            self.captureSession.stopRunning()
            self.isSessionRunning = false
            print("✅ CameraManager: Session stopped successfully")
        }
    }
    
    // Check for camera authorization
    func checkAuthorization(completion: @escaping (Bool) -> Void) {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            completion(true)
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    completion(granted)
                }
            }
        default:
            completion(false)
        }
    }
}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate
extension CameraManager: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        // SAFETY: Only call delegate if it exists and session is running
        guard isSessionRunning, let delegate = delegate else { return }
        
        // Determine camera type based on output
        let cameraType: CameraType = (output == nirOutput) ? .nir : .rgb
        delegate.cameraManager(self, didOutput: sampleBuffer, from: cameraType)
    }
}

enum CameraError: LocalizedError {
    case noCameraAvailable
    case configurationFailed
    case authorizationFailed
    
    var errorDescription: String? {
        switch self {
        case .noCameraAvailable:
            return "No suitable camera available on this device"
        case .configurationFailed:
            return "Failed to configure camera"
        case .authorizationFailed:
            return "Camera access not authorized"
        }
    }
}

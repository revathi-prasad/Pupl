// CameraManager.swift

import AVFoundation
import UIKit
import Vision
import CoreMedia

enum CameraManagerError: Error {
    case sessionSetupFailed
    case deviceNotAvailable
    case inputCreationFailed
    case outputCreationFailed
}

protocol CameraManagerDelegate: AnyObject {
    func cameraManager(_ manager: CameraManager, didOutput sampleBuffer: CMSampleBuffer, from camera: CameraType)
    func cameraManager(_ manager: CameraManager, didEncounterError error: Error)
}

enum CameraType: String {
    case infrared = "NIR"    // IR camera - use new CNN pupil detection models
    case rgb = "RGB"         // RGB camera - use existing left/right eye models
}

class CameraManager: NSObject {
    static let shared = CameraManager()
    weak var delegate: CameraManagerDelegate?
    
    // Camera session configuration
    private var captureSession: AVCaptureSession!
    private func checkTrueDepthAvailability() -> Bool {
        print("🔍 CameraManager: Checking TrueDepth availability with detailed logging...")
        
        // Method 1: Simple default check
        let simpleCheck = AVCaptureDevice.default(.builtInTrueDepthCamera, for: .video, position: .front)
        print("   📱 Simple TrueDepth check result: \(simpleCheck != nil)")
        
        // Method 2: Discovery session (more robust)
        let discoverySession = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInTrueDepthCamera],
            mediaType: .video,
            position: .front
        )
        let discoveredDevices = discoverySession.devices
        print("   📱 Discovery session found \(discoveredDevices.count) TrueDepth devices")
        
        // Method 3: Check all available devices using discovery session
        let allDevicesDiscovery = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInWideAngleCamera, .builtInTrueDepthCamera],
            mediaType: .video,
            position: .front
        )
        let frontDevices = allDevicesDiscovery.devices
        print("   📱 All front cameras found: \(frontDevices.count)")
        for device in frontDevices {
            print("      - \(device.localizedName) (type: \(device.deviceType.rawValue))")
        }
        
        let trueDepthAvailable = simpleCheck != nil || !discoveredDevices.isEmpty
        print("   ✅ Final TrueDepth availability: \(trueDepthAvailable)")
        
        return trueDepthAvailable
    }
    
    // Camera inputs and outputs
    private var rgbInput: AVCaptureDeviceInput?
    private var depthInput: AVCaptureDeviceInput?
    private var videoOutput: AVCaptureVideoDataOutput?
    private var depthOutput: AVCaptureDepthDataOutput?
    private var nirOutput: AVCaptureVideoDataOutput?
    
    // Device references
    private var frontCamera: AVCaptureDevice?
    private var trueDepthCamera: AVCaptureDevice?
    
    // Processing queues
    private let sessionQueue = DispatchQueue(label: "camera.session.queue")
    private let rgbProcessingQueue = DispatchQueue(label: "camera.rgb.processing", qos: .userInitiated)
    private let nirProcessingQueue = DispatchQueue(label: "camera.infrared.processing", qos: .userInitiated)
    
    // Depth data storage for face distance extraction
    private var lastDepthData: AVDepthData?
    private var lastDepthTimestamp: CMTime = CMTime.invalid
    
    private var isSessionRunning = false
    private var isSessionConfigured = false
    private var rgbPreviewLayer: AVCaptureVideoPreviewLayer?
    
    override init() {
        super.init()
        initializeCaptureSession()
        setupSession()
        setupNotifications()
    }
    
    private func setupNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(sessionRuntimeError),
            name: .AVCaptureSessionRuntimeError,
            object: captureSession
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(sessionWasInterrupted),
            name: .AVCaptureSessionWasInterrupted,
            object: captureSession
        )
    }
    
    @objc private func sessionRuntimeError(notification: NSNotification) {
        guard let error = notification.userInfo?[AVCaptureSessionErrorKey] as? AVError else { return }
        print("❌ CameraManager: Session runtime error: \(error.localizedDescription)")
        delegate?.cameraManager(self, didEncounterError: error)
    }
    
    @objc private func sessionWasInterrupted(notification: NSNotification) {
        print("⚠️ CameraManager: Session was interrupted")
    }
    
    // Configure preview layer for UI
    func previewLayer(for view: UIView) -> AVCaptureVideoPreviewLayer {
        if let existingLayer = rgbPreviewLayer {
            return existingLayer
        }
        
        let layer = AVCaptureVideoPreviewLayer(session: captureSession)
        layer.videoGravity = .resizeAspectFill
        
        // Validate bounds to prevent NaN errors
        let bounds = view.bounds
        if bounds.width.isNaN || bounds.height.isNaN || bounds.width <= 0 || bounds.height <= 0 {
            print("⚠️ CameraManager: Invalid view bounds for preview layer: \(bounds)")
            // Set a default frame to prevent NaN
            layer.frame = CGRect(x: 0, y: 0, width: 350, height: 300)
        } else {
            layer.frame = bounds
        }
        
        rgbPreviewLayer = layer
        return layer
    }
    
    private func initializeCaptureSession() {
        print("📱 CameraManager: Initializing capture session...")
        captureSession = AVCaptureSession()
    }
    
    private func setupSession() {
        sessionQueue.async { [weak self] in
            self?.configureSession()
        }
    }
    
    private func configureSession() {
        print("🔧 CameraManager: Starting session configuration...")
        captureSession.beginConfiguration()
        
        // Set quality level for standard session
        captureSession.sessionPreset = .high
        
        // Configure based on device capabilities (check again at configuration time)
        let trueDepthAvailable = checkTrueDepthAvailability()
        if trueDepthAvailable {
            print("📱 CameraManager: Setting up TrueDepth camera with RGB+Depth")
            setupTrueDepthSystem()
        } else {
            print("📱 CameraManager: Setting up standard front camera")
            setupStandardFrontCamera()
        }
        
        captureSession.commitConfiguration()
        isSessionConfigured = true
        print("✅ CameraManager: Session configuration completed")
    }
    
    // MARK: - TrueDepth System Setup  
    private func setupTrueDepthSystem() {
        // Use discovery session for more robust TrueDepth detection
        let discoverySession = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInTrueDepthCamera],
            mediaType: .video,
            position: .front
        )
        
        guard let trueDepthDevice = discoverySession.devices.first else {
            print("⚠️ CameraManager: TrueDepth camera not found via discovery session, falling back to standard camera")
            setupStandardFrontCamera()
            return
        }
        
        print("✅ CameraManager: Found TrueDepth device: \(trueDepthDevice.localizedName)")
        
        trueDepthCamera = trueDepthDevice
        
        do {
            // Configure TrueDepth camera input
            let trueDepthInput = try AVCaptureDeviceInput(device: trueDepthDevice)
            
            if captureSession.canAddInput(trueDepthInput) {
                captureSession.addInput(trueDepthInput)
                rgbInput = trueDepthInput
                print("✅ CameraManager: Added TrueDepth camera input")
            }
            
            // Set up RGB video output
            setupRGBVideoOutput()
            
            // Set up depth data output (contains NIR information)
            setupDepthDataOutput()
            
            // Set up synchronized data output for RGB+Depth
            setupSynchronizedOutputs()
            
            // Configure camera settings
            try configureCameraForHighFrameRate(trueDepthDevice)
            try configureTrueDepthSettings(trueDepthDevice)
            
        } catch {
            print("❌ CameraManager: Failed to setup TrueDepth system - \(error)")
            delegate?.cameraManager(self, didEncounterError: error)
        }
    }
    
    private func setupStandardFrontCamera() {
        guard let frontCamera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front) else {
            print("❌ CameraManager: No front camera available")
            delegate?.cameraManager(self, didEncounterError: CameraManagerError.deviceNotAvailable)
            return
        }
        
        do {
            // Configure standard front camera input
            let cameraInput = try AVCaptureDeviceInput(device: frontCamera)
            
            if captureSession.canAddInput(cameraInput) {
                captureSession.addInput(cameraInput)
                rgbInput = cameraInput
                print("✅ CameraManager: Added standard front camera input")
            }
            
            // Set up RGB video output only (no depth data)
            setupRGBVideoOutput()
            
            // Configure camera settings for better quality
            try configureCameraForHighFrameRate(frontCamera)
            
        } catch {
            print("❌ CameraManager: Failed to setup standard front camera - \(error)")
            delegate?.cameraManager(self, didEncounterError: error)
        }
    }
    
    private func setupRGBVideoOutput() {
        let rgbOutput = AVCaptureVideoDataOutput()
        rgbOutput.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
        ]
        rgbOutput.setSampleBufferDelegate(self, queue: rgbProcessingQueue)
        
        if captureSession.canAddOutput(rgbOutput) {
            captureSession.addOutput(rgbOutput)
            videoOutput = rgbOutput
            print("✅ CameraManager: Added RGB video output")
        }
    }
    
    private func setupDepthDataOutput() {
        let depthDataOutput = AVCaptureDepthDataOutput()
        depthDataOutput.setDelegate(self, callbackQueue: nirProcessingQueue)
        depthDataOutput.isFilteringEnabled = false  // We want raw depth data
        
        if captureSession.canAddOutput(depthDataOutput) {
            captureSession.addOutput(depthDataOutput)
            depthOutput = depthDataOutput
            print("✅ CameraManager: Added depth data output")
        }
    }
    
    private func setupSynchronizedOutputs() {
        guard let videoOutput = videoOutput,
              let depthOutput = depthOutput else {
            print("⚠️ CameraManager: Cannot setup synchronized outputs - outputs not configured")
            return
        }
        
        // Create synchronized data output for RGB+Depth alignment
        let synchronizedDataOutput = AVCaptureDataOutputSynchronizer(
            dataOutputs: [videoOutput, depthOutput]
        )
        synchronizedDataOutput.setDelegate(self, queue: sessionQueue)
        
        print("✅ CameraManager: Configured synchronized RGB+Depth output")
    }
    
    private func configureTrueDepthSettings(_ device: AVCaptureDevice) throws {
        try device.lockForConfiguration()
        
        // Enable depth data delivery
        if device.activeDepthDataFormat == nil {
            let availableFormats = device.activeFormat.supportedDepthDataFormats
            if let depthFormat = availableFormats.first {
                try device.lockForConfiguration()
                device.activeDepthDataFormat = depthFormat
                device.unlockForConfiguration()
                print("✅ CameraManager: Set depth data format: \(depthFormat)")
            }
        }
        
        device.unlockForConfiguration()
    }
    
    private func setupDualCamera() {
        // Fallback implementation for devices without TrueDepth
        guard let frontDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front) else {
            delegate?.cameraManager(self, didEncounterError: CameraError.noCameraAvailable)
            return
        }
        
        frontCamera = frontDevice
        
        do {
            let rgbInput = try AVCaptureDeviceInput(device: frontDevice)
            if captureSession.canAddInput(rgbInput) {
                captureSession.addInput(rgbInput)
                self.rgbInput = rgbInput
            }
            
            setupRGBVideoOutput()
            try configureCameraForHighFrameRate(frontDevice)
            
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
            if format.videoSupportedFrameRateRanges.first(where: { 
                $0.minFrameRate <= bestFrameRate && $0.maxFrameRate >= bestFrameRate 
            }) != nil {
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
        print("📱 CameraManager: Starting camera session...")
        sessionQueue.async { [weak self] in
            guard let self = self else { 
                print("❌ CameraManager: Self is nil, cannot start session")
                return 
            }
            
            if self.isSessionRunning {
                print("⚠️ CameraManager: Session already running")
                return
            }
            
            // Wait for configuration to complete
            if !self.isSessionConfigured {
                print("⏳ CameraManager: Waiting for session configuration to complete...")
                // Try again after a short delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    self.startSession()
                }
                return
            }
            
            print("🚀 CameraManager: Starting capture session")
            self.captureSession.startRunning()
            self.isSessionRunning = true
            
            DispatchQueue.main.async {
                let isActuallyRunning = self.captureSession.isRunning
                print("✅ CameraManager: Session started, running: \(isActuallyRunning)")
                
                if !isActuallyRunning {
                    print("❌ CameraManager: Session failed to start! Checking for errors...")
                    
                    // Check inputs and outputs
                    print("📊 CameraManager: Session inputs: \(self.captureSession.inputs.count)")
                    print("📊 CameraManager: Session outputs: \(self.captureSession.outputs.count)")
                    print("📊 CameraManager: Session type: \(type(of: self.captureSession))")
                    
                    // Try to identify the issue
                    if self.captureSession.inputs.isEmpty {
                        print("❌ CameraManager: No camera inputs configured")
                    }
                    if self.captureSession.outputs.isEmpty {
                        print("❌ CameraManager: No outputs configured")
                    }
                    
                    // Session failed to start - report error
                    self.delegate?.cameraManager(self, didEncounterError: CameraManagerError.sessionSetupFailed)
                }
            }
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
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        print("📱 CameraManager: Current authorization status: \(status.rawValue)")
        
        switch status {
        case .authorized:
            print("✅ CameraManager: Camera access authorized")
            // NOW check TrueDepth availability after authorization
            print("🔍 CameraManager: Checking TrueDepth availability post-authorization...")
            let trueDepthAvailable = checkTrueDepthAvailability()
            print("📱 CameraManager: TrueDepth available: \(trueDepthAvailable)")
            completion(true)
        case .notDetermined:
            print("❓ CameraManager: Requesting camera access...")
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    print("📱 CameraManager: Access request result: \(granted)")
                    if granted {
                        // Check TrueDepth availability after permission granted
                        print("🔍 CameraManager: Checking TrueDepth availability post-permission...")
                        let trueDepthAvailable = self.checkTrueDepthAvailability()
                        print("📱 CameraManager: TrueDepth available: \(trueDepthAvailable)")
                    }
                    completion(granted)
                }
            }
        default:
            print("❌ CameraManager: Camera access denied or restricted")
            completion(false)
        }
    }
}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate
extension CameraManager: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        // SAFETY: Only call delegate if it exists and session is running
        guard isSessionRunning else { 
            print("⚠️ CameraManager: Received frame but session not marked as running")
            return 
        }
        
        guard let delegate = delegate else { 
            print("⚠️ CameraManager: Received frame but no delegate set")
            return 
        }
        
        // Determine camera type based on output
        let cameraType: CameraType = (output == depthOutput) ? .infrared : .rgb
        delegate.cameraManager(self, didOutput: sampleBuffer, from: cameraType)
    }
}

// MARK: - AVCaptureDepthDataOutputDelegate
extension CameraManager: AVCaptureDepthDataOutputDelegate {
    func depthDataOutput(_ output: AVCaptureDepthDataOutput, didOutput depthData: AVDepthData, timestamp: CMTime, connection: AVCaptureConnection) {
        // Process depth data as NIR equivalent
        guard isSessionRunning, let delegate = delegate else { return }
        
        // Store depth data for face distance extraction
        lastDepthData = depthData
        lastDepthTimestamp = timestamp
        
        // Convert depth data to sample buffer format for compatibility
        if let nirSampleBuffer = createNIRSampleBuffer(from: depthData, timestamp: timestamp) {
            delegate.cameraManager(self, didOutput: nirSampleBuffer, from: .infrared)
        }
    }
    
    /// Extract face distance from depth data at specified face center coordinates
    func extractFaceDistance(from depthData: AVDepthData, faceCenter: CGPoint) -> Float {
        // Convert depthData to 32-bit float format for easier processing
        let convertedDepth = depthData.converting(toDepthDataType: kCVPixelFormatType_DepthFloat32)
        let depthMap = convertedDepth.depthDataMap
        
        // Lock the pixel buffer for reading
        CVPixelBufferLockBaseAddress(depthMap, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(depthMap, .readOnly) }
        
        // Get buffer properties
        let width = CVPixelBufferGetWidth(depthMap)
        let height = CVPixelBufferGetHeight(depthMap)
        let bytesPerRow = CVPixelBufferGetBytesPerRow(depthMap)
        
        // Extract depth buffer
        guard let baseAddress = CVPixelBufferGetBaseAddress(depthMap) else {
            print("⚠️ CameraManager: Failed to get pixel buffer base address")
            return 400.0
        }
        let floatBuffer = baseAddress.bindMemory(to: Float32.self, capacity: width * height)
        
        // Convert normalized face center (0-1) to pixel coordinates
        let pixelX = Int(faceCenter.x * CGFloat(width))
        let pixelY = Int(faceCenter.y * CGFloat(height))
        
        // Bounds check to ensure we're within the depth map
        guard pixelX >= 0 && pixelX < width && pixelY >= 0 && pixelY < height else {
            print("⚠️ CameraManager: Face center out of bounds (x:\(pixelX)/\(width), y:\(pixelY)/\(height)), using fallback distance")
            
            // Try center of image as fallback
            let centerX = width / 2
            let centerY = height / 2
            let centerDepthValue = floatBuffer[centerY * (bytesPerRow / 4) + centerX]
            let centerDistanceMM = centerDepthValue * 1000.0
            
            if centerDistanceMM > 150.0 && centerDistanceMM < 1000.0 && !centerDistanceMM.isNaN {
                print("📏 CameraManager: Using image center depth: \(String(format: "%.1f", centerDistanceMM))mm")
                return centerDistanceMM
            }
            
            return 400.0 // Final fallback
        }
        
        // Extract depth value at face center pixel
        let depthValue = floatBuffer[pixelY * (bytesPerRow / 4) + pixelX]
        
        // Convert from meters to millimeters
        let distanceMM = depthValue * 1000.0
        
        // Validate reasonable range for face distance (15cm to 100cm)
        guard distanceMM > 150.0 && distanceMM < 1000.0 && !distanceMM.isNaN && !distanceMM.isInfinite else {
            print("⚠️ CameraManager: Unreasonable depth value (\(distanceMM)mm), using fallback distance")
            return 400.0 // Fallback if unreasonable or invalid
        }
        
        print("📏 CameraManager: Extracted face distance: \(String(format: "%.1f", distanceMM))mm from depth data")
        return distanceMM
    }
    
    /// Get the most recent face distance from stored depth data
    func getCurrentFaceDistance(faceCenter: CGPoint) -> Float? {
        guard let depthData = lastDepthData else {
            print("⚠️ CameraManager: No depth data available for face distance")
            return nil
        }
        
        // Check if depth data is recent (within last 100ms)
        let currentTime = CACurrentMediaTime()
        let depthTime = CMTimeGetSeconds(lastDepthTimestamp)
        if abs(currentTime - depthTime) > 0.1 {
            print("⚠️ CameraManager: Depth data too old (\(String(format: "%.3f", abs(currentTime - depthTime)))s)")
            return nil
        }
        
        return extractFaceDistance(from: depthData, faceCenter: faceCenter)
    }
    
    private func createNIRSampleBuffer(from depthData: AVDepthData, timestamp: CMTime) -> CMSampleBuffer? {
        // Convert depth data to grayscale image (simulating NIR)
        let depthPixelBuffer = depthData.depthDataMap
        
        // Create format description
        var formatDescription: CMFormatDescription?
        let status = CMVideoFormatDescriptionCreateForImageBuffer(
            allocator: kCFAllocatorDefault,
            imageBuffer: depthPixelBuffer,
            formatDescriptionOut: &formatDescription
        )
        
        guard status == noErr, let format = formatDescription else {
            print("❌ CameraManager: Failed to create format description for NIR data")
            return nil
        }
        
        // Create sample buffer
        var sampleBuffer: CMSampleBuffer?
        var timingInfo = CMSampleTimingInfo(
            duration: CMTime.invalid,
            presentationTimeStamp: timestamp,
            decodeTimeStamp: CMTime.invalid
        )
        let sampleStatus = CMSampleBufferCreateForImageBuffer(
            allocator: kCFAllocatorDefault,
            imageBuffer: depthPixelBuffer,
            dataReady: true,
            makeDataReadyCallback: nil,
            refcon: nil,
            formatDescription: format,
            sampleTiming: &timingInfo,
            sampleBufferOut: &sampleBuffer
        )
        
        if sampleStatus == noErr {
            return sampleBuffer
        } else {
            print("❌ CameraManager: Failed to create NIR sample buffer - status: \(sampleStatus)")
            return nil
        }
    }
}

// MARK: - AVCaptureDataOutputSynchronizerDelegate
extension CameraManager: AVCaptureDataOutputSynchronizerDelegate {
    func dataOutputSynchronizer(_ synchronizer: AVCaptureDataOutputSynchronizer, didOutput synchronizedDataCollection: AVCaptureSynchronizedDataCollection) {
        
        guard isSessionRunning, let delegate = delegate else { return }
        
        // Extract RGB sample buffer
        if let videoData = synchronizedDataCollection.synchronizedData(for: videoOutput!) as? AVCaptureSynchronizedSampleBufferData,
           !videoData.sampleBufferWasDropped {
            delegate.cameraManager(self, didOutput: videoData.sampleBuffer, from: .rgb)
        }
        
        // Extract depth data (NIR equivalent)
        if let depthData = synchronizedDataCollection.synchronizedData(for: depthOutput!) as? AVCaptureSynchronizedDepthData,
           !depthData.depthDataWasDropped {
            
            let timestamp = depthData.timestamp
            if let nirSampleBuffer = createNIRSampleBuffer(from: depthData.depthData, timestamp: timestamp) {
                delegate.cameraManager(self, didOutput: nirSampleBuffer, from: .infrared)
            }
        }
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

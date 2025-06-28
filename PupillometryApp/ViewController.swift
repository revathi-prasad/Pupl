//  PupillometryApp
//
//  Created by Revathi Prasad on 08/06/25.
//


import UIKit
import AVFoundation

class ViewController: UIViewController {
    
    // UI Elements
    @IBOutlet weak var previewView: UIView!
    @IBOutlet weak var statusLabel: UILabel!
    @IBOutlet weak var dataLabel: UILabel!
    @IBOutlet weak var startButton: UIButton!
    @IBOutlet weak var taskImageView: UIImageView!
    
    // Core components
    private let cameraManager = CameraManager()
    private let pupilDetector = PupilDetector()
    private let featureExtractor = FeatureExtractor()
    private let gradCPTTask = GradCPTTask()
    
    // Session management
    private let session = SessionData()
    private var isRecording = false
    
    // FPS tracking for dynamic display
    private var currentFPS: Double = 0.0
    private var frameCount = 0
    private var lastFrameTime: TimeInterval = 0
    
    // Data buffer - optimized for iPhone 11 compatibility
    private var measurementBuffer: [PupilMeasurement] = []
    private let bufferSize = 300 // 10 seconds at 30Hz (iPhone 11 compatible)
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupCameraManager()
        setupGradCPTTask()
    }
    
    private func setupUI() {
        statusLabel.text = "Ready to start"
        dataLabel.text = "No data yet"
        taskImageView.isHidden = true
        
        startButton.layer.cornerRadius = 8
        if #available(iOS 15.0, *) {
            var config = UIButton.Configuration.filled()
            config.cornerStyle = .medium
            startButton.configuration = config
        } else {
            startButton.backgroundColor = .systemBlue
        }
    }
    
    private func setupCameraManager() {
        cameraManager.delegate = self
        
        // Set up preview layer
        if let previewLayer = try? AVCaptureVideoPreviewLayer(session: AVCaptureSession()) {
            previewLayer.frame = previewView.bounds
            previewLayer.videoGravity = .resizeAspectFill
            previewView.layer.addSublayer(previewLayer)
        }
    }
    
    private func setupGradCPTTask() {
        gradCPTTask.delegate = self
    }
    
    @IBAction func startButtonTapped(_ sender: UIButton) {
        if isRecording {
            stopRecording()
        } else {
            startRecording()
        }
    }
    
    private func startRecording() {
        // Request camera permissions
        cameraManager.checkAuthorization { [weak self] authorized in
            guard let self = self else { return }
            
            guard authorized else {
                DispatchQueue.main.async {
                    self.statusLabel.text = "Camera access denied"
                }
                return
            }
            
            DispatchQueue.main.async {
                self.isRecording = true
                self.startButton.setTitle("Stop", for: .normal)
                if #available(iOS 15.0, *) {
                    var config = self.startButton.configuration
                    config?.baseBackgroundColor = .systemRed
                    self.startButton.configuration = config
                } else {
                    self.startButton.backgroundColor = .systemRed
                }
                
                // Start camera
                self.cameraManager.startSession()
                
                // Start task after 2 second delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    self.gradCPTTask.start()
                    self.taskImageView.isHidden = false
                }
                
                self.statusLabel.text = "Recording..."
            }
        }
    }
    
    private func stopRecording() {
        isRecording = false
        startButton.setTitle("Start", for: .normal)
        if #available(iOS 15.0, *) {
            var config = startButton.configuration
            config?.baseBackgroundColor = .systemBlue
            startButton.configuration = config
        } else {
            startButton.backgroundColor = .systemBlue
        }
        
        // Stop components
        cameraManager.stopSession()
        gradCPTTask.stop()
        taskImageView.isHidden = true
        
        // Extract features
        if let features = featureExtractor.extractFeatures(
            from: session.pupilMeasurements,
            events: session.taskEvents
        ) {
            displayFeatures(features)
        }
        
        statusLabel.text = "Recording stopped"
    }
    
    private func displayFeatures(_ features: ADHDFeatures) {
        let text = """
        ADHD Feature Analysis:
        
        Baseline: \(String(format: "%.2f", features.tonicStartMM)) mm
        Max Attention Response: \(String(format: "%.1f", features.maxPhasicAttention))%
        Reaction Time: \(String(format: "%.0f", features.reactionTime * 1000)) ms
        Accuracy: \(String(format: "%.0f", features.accuracy * 100))%
        Processing Speed: \(String(format: "%.2f", features.processingSpeed))
        
        Total measurements: \(session.pupilMeasurements.count)
        """
        
        dataLabel.text = text
    }
}

// MARK: - CameraManagerDelegate
extension ViewController: CameraManagerDelegate {
    func cameraManager(_ manager: CameraManager, didOutput sampleBuffer: CMSampleBuffer, from camera: CameraType) {
        // Detect pupil
        guard let measurement = pupilDetector.detectPupil(in: sampleBuffer) else { return }
        
        // Add to session
        session.pupilMeasurements.append(measurement)
        
        // Update buffer
        measurementBuffer.append(measurement)
        if measurementBuffer.count > bufferSize {
            measurementBuffer.removeFirst()
        }
        
        // Update UI
        DispatchQueue.main.async { [weak self] in
            self?.updateDataDisplay(measurement)
        }
    }
    
    func cameraManager(_ manager: CameraManager, didEncounterError error: Error) {
        DispatchQueue.main.async { [weak self] in
            self?.statusLabel.text = "Error: \(error.localizedDescription)"
        }
    }
    
    private func updateDataDisplay(_ measurement: PupilMeasurement) {
        // Calculate real-time FPS
        calculateFPS()
        
        let text = """
        Live Data:
        Pupil: \(String(format: "%.2f", measurement.diameterMM)) mm
        Confidence: \(String(format: "%.0f", measurement.confidence * 100))%
        FPS: \(Int(currentFPS))
        """
        
        dataLabel.text = text
    }
    
    private func calculateFPS() {
        let currentTime = CACurrentMediaTime()
        if lastFrameTime == 0 {
            lastFrameTime = currentTime
            frameCount = 1
            return
        }
        
        frameCount += 1
        
        // Calculate FPS every second
        let elapsed = currentTime - lastFrameTime
        if elapsed >= 1.0 {
            currentFPS = Double(frameCount) / elapsed
            frameCount = 0
            lastFrameTime = currentTime
        }
    }
}

// MARK: - GradCPTTaskDelegate
extension ViewController: GradCPTTaskDelegate {
    func task(_ task: GradCPTTask, didPresentStimulus stimulus: GradCPTTask.Stimulus, at time: TimeInterval) {
        // Update task image
        taskImageView.image = stimulus.image
        
        // Record event
        let event = TaskEvent(
            timestamp: time,
            type: .stimulusOnset,
            data: [
                "trial": stimulus.trialNumber,
                "type": stimulus.type == .target ? "target" : "nonTarget"
            ]
        )
        session.taskEvents.append(event)
    }
    
    func task(_ task: GradCPTTask, didReceiveResponse correct: Bool, reactionTime: TimeInterval) {
        let event = TaskEvent(
            timestamp: CACurrentMediaTime(),
            type: .response,
            data: [
                "correct": correct,
                "reactionTime": reactionTime
            ]
        )
        session.taskEvents.append(event)
    }
    
    func taskDidComplete(_ task: GradCPTTask) {
        stopRecording()
    }
}

// MARK: - Touch handling for responses
extension ViewController {
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        if isRecording {
            gradCPTTask.recordResponse()
        }
    }
}

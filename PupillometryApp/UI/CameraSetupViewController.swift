//
//  CameraSetupViewController.swift
//  PupillometryApp
//
//  Created by Revathi Prasad on 10/06/25.
//

//import UIKit
//
//class CameraSetupViewController: UIViewController {
//
//    override func viewDidLoad() {
//        super.viewDidLoad()
//
//        // Do any additional setup after loading the view.
//    }
//    
//
//    /*
//    // MARK: - Navigation
//
//    // In a storyboard-based application, you will often want to do a little preparation before navigation
//    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
//        // Get the new view controller using segue.destination.
//        // Pass the selected object to the new view controller.
//    }
//    */
//
//}

// CameraSetupViewController.swift
import UIKit
import AVFoundation

class CameraSetupViewController: UIViewController {
    @IBOutlet weak var cameraPreviewView: UIView!
    @IBOutlet weak var startCalibrationButton: UIButton!
    @IBOutlet weak var statusLabel: UILabel!
    @IBOutlet weak var activityIndicator: UIActivityIndicatorView!
    
    private let cameraManager = CameraManager.shared
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private let pupilDetector = PupilDetector() // CREATE ONCE, NOT EVERY FRAME
    private var faceDetected = false
    private var lastFeedbackTime: TimeInterval = 0
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        checkCameraAuthorization()
    }
    
    private func setupUI() {
        startCalibrationButton.layer.cornerRadius = 8.0
        startCalibrationButton.isEnabled = false
        
        // Setup loading indicator
        activityIndicator.hidesWhenStopped = true
        activityIndicator.startAnimating()
        
        statusLabel.text = "Initializing camera..."
        statusLabel.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        statusLabel.textColor = .white
        statusLabel.textAlignment = .center
        statusLabel.adjustsFontSizeToFitWidth = true
        statusLabel.minimumScaleFactor = 0.8
    }
    
    private func checkCameraAuthorization() {
        cameraManager.checkAuthorization { [weak self] authorized in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                if authorized {
                    self.setupCamera()
                } else {
                    self.statusLabel.text = "Camera access denied"
                    self.activityIndicator.stopAnimating()
                    
                    // Show alert
                    let alert = UIAlertController(
                        title: "Camera Access Required",
                        message: "Please enable camera access in Settings to use pupillometry features.",
                        preferredStyle: .alert
                    )
                    
                    alert.addAction(UIAlertAction(title: "Open Settings", style: .default) { _ in
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    })
                    
                    alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
                    
                    self.present(alert, animated: true)
                }
            }
        }
    }
    
    private func setupCamera() {
        print("📱 CameraSetupViewController: Setting up camera")
        cameraManager.delegate = self
        
        // Set up preview layer
        previewLayer = cameraManager.previewLayer(for: cameraPreviewView)
        if let previewLayer = previewLayer {
            cameraPreviewView.layer.addSublayer(previewLayer)
            print("✅ CameraSetupViewController: Preview layer added")
        } else {
            print("❌ CameraSetupViewController: Failed to create preview layer")
        }
        
        // Start camera
        print("📱 CameraSetupViewController: Starting camera session")
        cameraManager.startSession()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        if let previewLayer = previewLayer {
            let bounds = cameraPreviewView.bounds
            
            // Validate bounds to prevent NaN errors
            if bounds.width.isNaN || bounds.height.isNaN || bounds.width <= 0 || bounds.height <= 0 {
                print("⚠️ CameraSetupViewController: Invalid bounds detected: \(bounds)")
                return
            }
            
            previewLayer.frame = bounds
            print("📐 CameraSetupViewController: Updated preview layer frame to \(bounds)")
        }
    }
    
    @IBAction func startCalibrationTapped(_ sender: UIButton) {
        print("🔗 CameraSetupViewController: Button tapped - preparing for segue")
        
        // Prevent double-triggering
        sender.isEnabled = false
        
        // CRITICAL: Stop camera before transitioning to prevent memory corruption
        cameraManager.stopSession()
        cameraManager.delegate = nil
        
        // Don't call performSegue here - let the storyboard segue handle it
        // The segue should be connected directly from the button to the destination in the storyboard
        print("✅ CameraSetupViewController: Camera stopped, ready for storyboard segue")
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        // Only cleanup if we're actually leaving (not just presenting another view)
        if isMovingFromParent || isBeingDismissed {
            print("🧹 CameraSetupViewController: Cleaning up camera resources")
            cameraManager.stopSession()
            cameraManager.delegate = nil
        }
    }
    
    deinit {
        print("🗑️ CameraSetupViewController: deinit called")
        cameraManager.stopSession()
        cameraManager.delegate = nil
    }
}

extension CameraSetupViewController: CameraManagerDelegate {
    func cameraManager(_ manager: CameraManager, didOutput sampleBuffer: CMSampleBuffer, from camera: CameraType) {
        // Only process RGB frames for real-time feedback
        guard camera == .rgb else { return }
        
        // Only check face detection if not already detected
        guard !faceDetected else { return }
        
        // Use the single instance, not a new one every frame
        if pupilDetector.detectPupil(in: sampleBuffer) != nil {
            print("👤 CameraSetupViewController: Face detected!")
            faceDetected = true
            
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                
                self.activityIndicator.stopAnimating()
                self.statusLabel.text = "Face detected. Ready for calibration."
                self.startCalibrationButton.isEnabled = true
                self.startCalibrationButton.alpha = 1.0
            }
        } else {
            // Provide real-time positioning feedback
            self.provideFacePositionFeedback(from: sampleBuffer)
        }
    }
    
    private func provideFacePositionFeedback(from sampleBuffer: CMSampleBuffer) {
        // Throttle feedback updates to avoid UI spam
        let now = CFAbsoluteTimeGetCurrent()
        if now - lastFeedbackTime < 1.0 { return }
        lastFeedbackTime = now
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            // Provide guidance based on common issues
            let feedbackMessages = [
                "Position your face in the center",
                "Move closer to the camera (40-60cm)",
                "Ensure good lighting on your face",
                "Look directly at the camera",
                "Remove any glasses if possible"
            ]
            
            let randomMessage = feedbackMessages.randomElement() ?? "Adjusting position..."
            self.statusLabel.text = randomMessage
        }
    }
    
    func cameraManager(_ manager: CameraManager, didEncounterError error: Error) {
        DispatchQueue.main.async { [weak self] in
            self?.statusLabel.text = "Error: \(error.localizedDescription)"
            self?.activityIndicator.stopAnimating()
        }
    }
}

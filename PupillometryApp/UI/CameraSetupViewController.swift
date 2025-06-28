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
    
    private let cameraManager = CameraManager()
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private let pupilDetector = PupilDetector() // CREATE ONCE, NOT EVERY FRAME
    private var faceDetected = false
    
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
        cameraManager.delegate = self
        
        // Set up preview layer
        previewLayer = cameraManager.previewLayer(for: cameraPreviewView)
        if let previewLayer = previewLayer {
            cameraPreviewView.layer.addSublayer(previewLayer)
        }
        
        // Start camera
        cameraManager.startSession()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = cameraPreviewView.bounds
    }
    
    @IBAction func startCalibrationTapped(_ sender: UIButton) {
        print("🔗 CameraSetupViewController: Starting calibration segue")
        
        // CRITICAL: Stop camera before transitioning to prevent memory corruption
        cameraManager.stopSession()
        cameraManager.delegate = nil
        
        performSegue(withIdentifier: "showCalibration", sender: self)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        // Cleanup camera when leaving view
        print("🧹 CameraSetupViewController: Cleaning up camera resources")
        cameraManager.stopSession()
        cameraManager.delegate = nil
    }
    
    deinit {
        print("🗑️ CameraSetupViewController: deinit called")
        cameraManager.stopSession()
        cameraManager.delegate = nil
    }
}

extension CameraSetupViewController: CameraManagerDelegate {
    func cameraManager(_ manager: CameraManager, didOutput sampleBuffer: CMSampleBuffer, from camera: CameraType) {
        // Only check face detection if not already detected
        guard !faceDetected else { return }
        
        // Use the single instance, not a new one every frame
        if pupilDetector.detectPupil(in: sampleBuffer) != nil {
            faceDetected = true
            
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                
                self.activityIndicator.stopAnimating()
                self.statusLabel.text = "Face detected. Ready for calibration."
                self.startCalibrationButton.isEnabled = true
                self.startCalibrationButton.alpha = 1.0
            }
        }
    }
    
    func cameraManager(_ manager: CameraManager, didEncounterError error: Error) {
        DispatchQueue.main.async { [weak self] in
            self?.statusLabel.text = "Error: \(error.localizedDescription)"
            self?.activityIndicator.stopAnimating()
        }
    }
}

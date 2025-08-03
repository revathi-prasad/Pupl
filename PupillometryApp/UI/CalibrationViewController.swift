////
////  CalibrationViewController.swift
////  PupillometryApp
////
////  Created by Revathi Prasad on 10/06/25.
////
//
////import UIKit
////
////class CalibrationViewController: UIViewController {
////
////    override func viewDidLoad() {
////        super.viewDidLoad()
////
////        // Do any additional setup after loading the view.
////    }
////    
////
////    /*
////    // MARK: - Navigation
////
////    // In a storyboard-based application, you will often want to do a little preparation before navigation
////    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
////        // Get the new view controller using segue.destination.
////        // Pass the selected object to the new view controller.
////    }
////    */
////
////}
//
//// CalibrationViewController.swift
//import UIKit
//import AVFoundation
//
//class CalibrationViewController: UIViewController {
//    @IBOutlet weak var calibrationView: UIView!
//    @IBOutlet weak var instructionLabel: UILabel!
//    @IBOutlet weak var progressView: UIProgressView!
//    @IBOutlet weak var startTestButton: UIButton!
//    
//    private var calibrationPoints: [CGPoint] = []
//    private var currentPointIndex = 0
//    private var calibrationComplete = false
//    private var pointLayers: [CALayer] = []
//    
//    private let pupillometryManager = PupillometryManager.shared
//    private let numPoints = 9
//    private let pointDuration: TimeInterval = 2.0
//    
//    override func viewDidLoad() {
//        super.viewDidLoad()
//        setupUI()
//        setupCalibrationPoints()
//    }
//    
//    private func setupUI() {
//        startTestButton.layer.cornerRadius = 8.0
//        startTestButton.isEnabled = false
//        
//        progressView.progress = 0.0
//        progressView.progressTintColor = .systemBlue
//        
//        instructionLabel.text = "Follow the white dot with your eyes"
//    }
//    
//    private func setupCalibrationPoints() {
//        // Create a grid of points covering the screen
//        let width = calibrationView.bounds.width
//        let height = calibrationView.bounds.height
//        
//        calibrationPoints = [
//            CGPoint(x: width * 0.1, y: height * 0.1),   // Top left
//            CGPoint(x: width * 0.5, y: height * 0.1),   // Top center
//            CGPoint(x: width * 0.9, y: height * 0.1),   // Top right
//            CGPoint(x: width * 0.1, y: height * 0.5),   // Middle left
//            CGPoint(x: width * 0.5, y: height * 0.5),   // Center
//            CGPoint(x: width * 0.9, y: height * 0.5),   // Middle right
//            CGPoint(x: width * 0.1, y: height * 0.9),   // Bottom left
//            CGPoint(x: width * 0.5, y: height * 0.9),   // Bottom center
//            CGPoint(x: width * 0.9, y: height * 0.9)    // Bottom right
//        ]
//    }
//    
//    @IBAction func startTestTapped(_ sender: UIButton) {
//        if calibrationComplete {
//            // Move to assessment
//            performSegue(withIdentifier: "showAssessment", sender: self)
//        } else {
//            // Start calibration
//            startCalibration()
//            sender.isEnabled = false
//            sender.alpha = 0.5
//        }
//    }
//    
//    private func startCalibration() {
//        currentPointIndex = 0
//        displayCalibrationPoint()
//    }
//    
//    private func displayCalibrationPoint() {
//        // Remove previous point layers
//        pointLayers.forEach { $0.removeFromSuperlayer() }
//        pointLayers.removeAll()
//        
//        guard currentPointIndex < calibrationPoints.count else {
//            completeCalibration()
//            return
//        }
//        
//        // Update progress
//        let progress = Float(currentPointIndex) / Float(calibrationPoints.count)
//        progressView.progress = progress
//        
//        // Update instruction
//        instructionLabel.text = "Follow the white dot with your eyes\nPoint \(currentPointIndex + 1) of \(calibrationPoints.count)"
//        
//        // Create and animate the point
//        let point = calibrationPoints[currentPointIndex]
//        let pointLayer = CALayer()
//        pointLayer.backgroundColor = UIColor.white.cgColor
//        pointLayer.frame = CGRect(x: point.x - 6, y: point.y - 6, width: 12, height: 12)
//        pointLayer.cornerRadius = 6
//        
//        calibrationView.layer.addSublayer(pointLayer)
//        pointLayers.append(pointLayer)
//        
//        // Animation for pulse effect
//        let pulseAnimation = CABasicAnimation(keyPath: "transform.scale")
//        pulseAnimation.duration = 0.5
//        pulseAnimation.fromValue = 1.0
//        pulseAnimation.toValue = 1.3
//        pulseAnimation.autoreverses = true
//        pulseAnimation.repeatCount = Float.infinity
//        pointLayer.add(pulseAnimation, forKey: "pulse")
//        
//        // Record gaze data for this point
//        pupillometryManager.recordCalibrationPoint(at: point)
//        
//        // Schedule next point
//        DispatchQueue.main.asyncAfter(deadline: .now() + pointDuration) { [weak self] in
//            guard let self = self else { return }
//            self.currentPointIndex += 1
//            self.displayCalibrationPoint()
//        }
//    }
//    
//    private func completeCalibration() {
//        // Update UI
//        progressView.progress = 1.0
//        instructionLabel.text = "Calibration complete!"
//        
//        // Process calibration data
//        pupillometryManager.finalizeCalibration()
//        
//        // Enable button to continue
//        startTestButton.isEnabled = true
//        startTestButton.alpha = 1.0
//        startTestButton.setTitle("Start Assessment", for: .normal)
//        calibrationComplete = true
//    }
//}
//
//  CalibrationViewController.swift
//  PupillometryApp
//
//  Created by Revathi Prasad on 10/06/25.
//

import UIKit
import AVFoundation

class CalibrationViewController: UIViewController {
    @IBOutlet weak var calibrationView: UIView!
    @IBOutlet weak var instructionLabel: UILabel!
    @IBOutlet weak var progressView: UIProgressView!
    @IBOutlet weak var startTestButton: UIButton!
    
    private var calibrationPoints: [CGPoint] = []
    private var currentPointIndex = 0
    private var calibrationComplete = false
    private var pointLayers: [CALayer] = []
    private var isCalibrationInProgress = false
    
    // CRITICAL FIX: Replace nested DispatchQueue.main.asyncAfter with proper Timer management
    private var calibrationTimer: Timer?
    private var gazeCollectionTimer: Timer?
    
    private let pupillometryManager = PupillometryManager.shared
    private let numPoints = 9
    private let pointDuration: TimeInterval = 3.0
    private let gazeCollectionDelay: TimeInterval = 0.5
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        // DON'T setup calibration points here - bounds not ready yet
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        // Setup points AFTER layout is complete
        if calibrationPoints.isEmpty && calibrationView.bounds.width > 0 {
            setupCalibrationPoints()
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        print("👋 CalibrationViewController: viewWillDisappear called")
        
        // Comprehensive cleanup to prevent crashes
        cleanupCalibrationResources()
        
        // Stop session if still running when leaving calibration
        if pupillometryManager.currentSession != nil {
            print("🧹 CalibrationViewController: Cleaning up pupillometry session on view disappear")
            pupillometryManager.stopSession()
        }
    }
    
    deinit {
        print("🗑️ CalibrationViewController: deinit called - cleaning up")
        cleanupCalibrationResources()
    }
    
    private func setupUI() {
        // Black background for better contrast with white dots
        view.backgroundColor = .black
        calibrationView.backgroundColor = .black
        
        startTestButton.layer.cornerRadius = 8.0
        startTestButton.isEnabled = true
        startTestButton.setTitle("Start Calibration", for: .normal)
        startTestButton.backgroundColor = .systemBlue
        startTestButton.setTitleColor(.white, for: .normal)
        
        progressView.progress = 0.0
        progressView.progressTintColor = .systemBlue
        progressView.backgroundColor = .darkGray
        
        instructionLabel.text = "IMPORTANT: Keep your head still and follow each dot ONLY with your eyes.\nTap 'Start Calibration' when ready."
        instructionLabel.textColor = .white
        instructionLabel.textAlignment = .center
        instructionLabel.font = UIFont.systemFont(ofSize: 18, weight: .medium)
        instructionLabel.adjustsFontSizeToFitWidth = true
        instructionLabel.minimumScaleFactor = 0.8
    }
    
    private func setupCalibrationPoints() {
        // Force layout if bounds aren't ready yet
        if calibrationView.bounds.width == 0 || calibrationView.bounds.height == 0 {
            view.layoutIfNeeded()
        }
        
        // ONLY CHANGE: Add bounds check to prevent crash
        guard calibrationView.bounds.width > 0 && calibrationView.bounds.height > 0 else {
            print("⚠️ CalibrationViewController: Calibration view bounds not ready: \(calibrationView.bounds)")
            return
        }
        
        // Your existing point calculation - NO CHANGES
        let width = calibrationView.bounds.width
        let height = calibrationView.bounds.height
        
        print("📐 CalibrationViewController: Setting up points with view size: \(width) x \(height)")
        
        // Create 9 calibration points in 3x3 grid (research-backed optimal configuration)
        let fixedPoints = [
            CGPoint(x: width * 0.1, y: height * 0.1),   // Top left
            CGPoint(x: width * 0.5, y: height * 0.1),   // Top center
            CGPoint(x: width * 0.9, y: height * 0.1),   // Top right
            CGPoint(x: width * 0.1, y: height * 0.5),   // Middle left
            CGPoint(x: width * 0.5, y: height * 0.5),   // Center
            CGPoint(x: width * 0.9, y: height * 0.5),   // Middle right
            CGPoint(x: width * 0.1, y: height * 0.9),   // Bottom left
            CGPoint(x: width * 0.5, y: height * 0.9),   // Bottom center
            CGPoint(x: width * 0.9, y: height * 0.9)    // Bottom right
        ]
        
        // Randomize the order of calibration points
        calibrationPoints = fixedPoints.shuffled()
        
        print("🎲 CalibrationViewController: Randomized calibration order:")
        for (index, point) in calibrationPoints.enumerated() {
            print("   Point \(index + 1): (\(Int(point.x)), \(Int(point.y)))")
        }
        
        print("✅ CalibrationViewController: Created \(calibrationPoints.count) calibration points")
    }
    
    @IBAction func startTestTapped(_ sender: UIButton) {
        let buttonTitle = sender.title(for: .normal) ?? ""
        print("🔘 CalibrationViewController: Button tapped - '\(buttonTitle)'")
        
        if buttonTitle == "Done" && calibrationComplete {
            // Navigate to TaskInstructionsViewController programmatically
            print("🔗 Going to task instructions...")
            navigateToTaskInstructions()
            
        } else if buttonTitle == "Start Calibration" {
            // Start calibration process on THIS screen
            print("🎯 Starting calibration process...")
            
            // CRITICAL: Start pupillometry session BEFORE calibration!
            print("🎬 CalibrationViewController: Starting pupillometry session for data collection")
            pupillometryManager.startSession()
            
            // Ensure calibration points are set up before starting
            if calibrationPoints.isEmpty {
                setupCalibrationPoints()
            }
            
            print("🎯 CalibrationViewController: Starting calibration with \(calibrationPoints.count) points")
            print("📐 Calibration view bounds: \(calibrationView.bounds)")
            
            // Start calibration - NO SEGUE!
            startCalibration()
            sender.isEnabled = false
            sender.alpha = 0.5
            
        } else if buttonTitle == "Recalibrate" {
            // Reset and start again
            print("🔄 Recalibrating...")
            resetCalibration()
            startCalibration()
            sender.isEnabled = false
            sender.alpha = 0.5
        }
    }
    
    private func resetCalibration() {
        calibrationComplete = false
        currentPointIndex = 0
        pointLayers.forEach { $0.removeFromSuperlayer() }
        pointLayers.removeAll()
        progressView.progress = 0.0
    }
    
    private func startCalibration() {
        print("🎯 CalibrationViewController: Starting calibration...")
        isCalibrationInProgress = true
        currentPointIndex = 0
        displayCalibrationPoint()
    }
    
    private func displayCalibrationPoint() {
        print("📍 CalibrationViewController: Displaying point \(currentPointIndex + 1) of \(calibrationPoints.count)")
        
        // Safety check: ensure we're still in a valid state
        guard isCalibrationInProgress && view.window != nil else {
            print("⚠️ CalibrationViewController: Calibration not in progress or view not active, skipping")
            return
        }
        
        // Remove previous point layers
        pointLayers.forEach { $0.removeFromSuperlayer() }
        pointLayers.removeAll()
        
        // CRITICAL FIX: Add comprehensive bounds checking to prevent index crash
        guard currentPointIndex >= 0 && currentPointIndex < calibrationPoints.count else {
            print("❌ CalibrationViewController: FATAL - currentPointIndex \(currentPointIndex) out of bounds for array of size \(calibrationPoints.count)")
            print("🔄 CalibrationViewController: Forcing calibration completion to prevent crash")
            completeCalibration()
            return
        }
        
        // Double-check array is not empty
        guard !calibrationPoints.isEmpty else {
            print("❌ CalibrationViewController: FATAL - calibrationPoints array is empty!")
            print("🔄 CalibrationViewController: Attempting to rebuild calibration points...")
            setupCalibrationPoints()
            if calibrationPoints.isEmpty {
                print("❌ CalibrationViewController: Still empty after rebuild - aborting calibration")
                completeCalibration()
            }
            return  // Always return from guard else block
        }
        
        // Final bounds check before accessing array
        if currentPointIndex >= calibrationPoints.count {
            print("✅ CalibrationViewController: All points completed, finishing calibration")
            completeCalibration()
            return
        }
        
        // Update progress
        let progress = Float(currentPointIndex) / Float(calibrationPoints.count)
        progressView.progress = progress
        
        // Update instruction  
        instructionLabel.text = "Keep head STILL. Follow dot with EYES ONLY.\nPoint \(currentPointIndex + 1) of \(calibrationPoints.count)"
        
        // SAFELY access the array after all bounds checks
        let point = calibrationPoints[currentPointIndex]
        print("📍 Point location: \(point) (index \(currentPointIndex)/\(calibrationPoints.count))")
        
        // Create larger, more visible dot with high contrast
        let pointLayer = CALayer()
        pointLayer.backgroundColor = UIColor.red.cgColor  // Red for better visibility
        pointLayer.frame = CGRect(x: point.x - 20, y: point.y - 20, width: 40, height: 40)
        pointLayer.cornerRadius = 20
        pointLayer.borderWidth = 3
        pointLayer.borderColor = UIColor.white.cgColor
        
        // Add shadow for better visibility
        pointLayer.shadowColor = UIColor.black.cgColor
        pointLayer.shadowOffset = CGSize(width: 0, height: 0)
        pointLayer.shadowRadius = 5
        pointLayer.shadowOpacity = 0.5
        
        calibrationView.layer.addSublayer(pointLayer)
        pointLayers.append(pointLayer)
        
        // Enhanced animation with entrance effect
        pointLayer.transform = CATransform3DMakeScale(0.1, 0.1, 1.0)
        
        // Entrance animation
        let scaleIn = CABasicAnimation(keyPath: "transform.scale")
        scaleIn.fromValue = 0.1
        scaleIn.toValue = 1.0
        scaleIn.duration = 0.3
        scaleIn.timingFunction = CAMediaTimingFunction(name: .easeOut)
        
        // Continuous pulse animation
        let pulseAnimation = CABasicAnimation(keyPath: "transform.scale")
        pulseAnimation.fromValue = 1.0
        pulseAnimation.toValue = 1.2
        pulseAnimation.duration = 0.8
        pulseAnimation.autoreverses = true
        pulseAnimation.repeatCount = Float.infinity
        pulseAnimation.beginTime = CACurrentMediaTime() + 0.3 // Start after entrance
        
        pointLayer.add(scaleIn, forKey: "scaleIn")
        pointLayer.add(pulseAnimation, forKey: "pulse")
        
        // Record calibration data with pupillometry manager
        pupillometryManager.recordCalibrationPoint(at: point)
        
        // CRITICAL FIX: Use proper Timer instead of nested DispatchQueue.main.asyncAfter
        // This eliminates the cascading timer deadlock that causes Point 7 freeze
        
        // Start gaze collection after delay
        gazeCollectionTimer = Timer.scheduledTimer(withTimeInterval: gazeCollectionDelay, repeats: false) { [weak self] _ in
            self?.startGazeDataCollection(for: point)
        }
        
        // Schedule next point transition
        calibrationTimer = Timer.scheduledTimer(withTimeInterval: pointDuration, repeats: false) { [weak self] _ in
            self?.handleCalibrationPointTransition()
        }
    }
    
    private func startGazeDataCollection(for point: CGPoint) {
        print("👁️ CalibrationViewController: Starting gaze data collection for point \(point)")
        // This will be called by PupillometryManager to collect eye tracking data
        pupillometryManager.startCalibrationDataCollection(for: point)
    }
    
    private func stopGazeDataCollection() {
        print("⏹️ CalibrationViewController: Stopping gaze data collection")
        pupillometryManager.stopCalibrationDataCollection()
    }
    
    // CRITICAL FIX: Centralized calibration point transition logic
    // This replaces the nested timer approach that caused Point 7 deadlocks
    private func handleCalibrationPointTransition() {
        print("⏰ CalibrationViewController: Handling transition from point \(currentPointIndex)")
        
        // Safety checks
        guard isCalibrationInProgress && view.window != nil else {
            print("⚠️ CalibrationViewController: Calibration stopped or view not active, aborting transition")
            return
        }
        
        guard currentPointIndex >= 0 && currentPointIndex < calibrationPoints.count else {
            print("❌ CalibrationViewController: Invalid currentPointIndex \(currentPointIndex) for \(calibrationPoints.count) points")
            completeCalibration()
            return
        }
        
        // Stop current point data collection
        stopGazeDataCollection()
        
        // Move to next point
        currentPointIndex += 1
        
        if currentPointIndex >= calibrationPoints.count {
            print("✅ CalibrationViewController: All calibration points completed")
            completeCalibration()
        } else {
            print("🔄 CalibrationViewController: Moving to point \(currentPointIndex + 1)/\(calibrationPoints.count)")
            displayCalibrationPoint()
        }
    }
    
    private func completeCalibration() {
        print("🎯 CalibrationViewController: Finalizing calibration...")
        
        // Mark calibration as no longer in progress
        isCalibrationInProgress = false
        
        // Remove all calibration dots
        pointLayers.forEach { $0.removeFromSuperlayer() }
        pointLayers.removeAll()
        
        // Finalize calibration and get validation metrics
        let calibrationResult = pupillometryManager.finalizeCalibration()
        
        // Update UI based on calibration quality
        progressView.progress = 1.0
        
        if calibrationResult.isValid {
            instructionLabel.text = "✅ Calibration Complete!\nAccuracy: \(String(format: "%.1f", calibrationResult.accuracy * 100))%\nReady to proceed to task instructions"
            startTestButton.backgroundColor = .systemBlue
            startTestButton.setTitle("Done", for: .normal)
            calibrationComplete = true
            
            print("✅ CalibrationViewController: Calibration successful - Accuracy: \(calibrationResult.accuracy)")
        } else {
            instructionLabel.text = "⚠️ Calibration Quality Poor\nAccuracy: \(String(format: "%.1f", calibrationResult.accuracy * 100))%\nTap to recalibrate"
            startTestButton.backgroundColor = .systemOrange
            startTestButton.setTitle("Recalibrate", for: .normal)
            calibrationComplete = false
            
            print("⚠️ CalibrationViewController: Calibration needs improvement - Accuracy: \(calibrationResult.accuracy)")
        }
        
        // Always enable the button
        startTestButton.isEnabled = true
        startTestButton.alpha = 1.0
        
        // Show calibration metrics briefly
        showCalibrationMetrics(calibrationResult)
    }
    
    private func navigateToTaskInstructions() {
        print("🔗 CalibrationViewController: Creating PathwaySelectionViewController programmatically")
        
        // Clean up any remaining animations and timers
        cleanupCalibrationResources()
        
        // Stop the pupillometry session safely on background thread
        print("🛑 CalibrationViewController: Stopping pupillometry session after calibration")
        DispatchQueue.global(qos: .utility).async { [weak self] in
            self?.pupillometryManager.stopSession()
            
            // Return to main thread for navigation
            DispatchQueue.main.async { [weak self] in
                guard let self = self, let navigationController = self.navigationController else {
                    print("❌ Navigation controller or self is nil")
                    return
                }
                
                // Create PathwaySelectionViewController programmatically (not in storyboard)
                print("🔧 Creating PathwaySelectionViewController programmatically")
                let pathwaySelectionVC = PathwaySelectionViewController()
                pathwaySelectionVC.title = "Choose Assessment Type"
                navigationController.pushViewController(pathwaySelectionVC, animated: true)
                print("✅ Successfully navigated to PathwaySelectionViewController")
            }
        }
    }
    
    private func cleanupCalibrationResources() {
        print("🧹 CalibrationViewController: Cleaning up calibration resources...")
        
        // Stop calibration process
        isCalibrationInProgress = false
        
        // CRITICAL FIX: Invalidate timers to prevent Point 7 deadlock and memory leaks
        calibrationTimer?.invalidate()
        calibrationTimer = nil
        gazeCollectionTimer?.invalidate() 
        gazeCollectionTimer = nil
        
        // Remove all layer animations
        pointLayers.forEach { layer in
            layer.removeAllAnimations()
            layer.removeFromSuperlayer()
        }
        pointLayers.removeAll()
        
        // Clear calibration view layers
        calibrationView?.layer.sublayers?.forEach { layer in
            if layer != calibrationView?.layer {
                layer.removeAllAnimations()
                layer.removeFromSuperlayer()
            }
        }
        
        print("✅ CalibrationViewController: Resource cleanup completed")
    }
    
    private func showCalibrationMetrics(_ result: CalibrationResult) {
        // Create a temporary view to show calibration quality
        let metricsView = UIView(frame: CGRect(x: 20, y: 100, width: view.bounds.width - 40, height: 120))
        metricsView.backgroundColor = UIColor.black.withAlphaComponent(0.8)
        metricsView.layer.cornerRadius = 10
        metricsView.alpha = 0.0
        
        let metricsLabel = UILabel(frame: metricsView.bounds.insetBy(dx: 20, dy: 10))
        metricsLabel.textColor = .white
        metricsLabel.textAlignment = .center
        metricsLabel.numberOfLines = 0
        metricsLabel.font = UIFont.systemFont(ofSize: 16)
        
        let qualityText = result.isValid ? "GOOD" : "NEEDS IMPROVEMENT"
        let qualityColor = result.isValid ? "🟢" : "🟡"
        
        metricsLabel.text = """
        \(qualityColor) Calibration Quality: \(qualityText)
        📊 Accuracy: \(String(format: "%.1f", result.accuracy * 100))%
        👁️ Gaze Points Collected: \(result.dataPointsCollected)
        ⏱️ Average Response Time: \(String(format: "%.2f", result.averageResponseTime))s
        """
        
        metricsView.addSubview(metricsLabel)
        view.addSubview(metricsView)
        
        // Animate in and out
        UIView.animate(withDuration: 0.3, animations: {
            metricsView.alpha = 1.0
        }) { _ in
            UIView.animate(withDuration: 0.3, delay: 3.0, animations: {
                metricsView.alpha = 0.0
            }) { _ in
                metricsView.removeFromSuperview()
            }
        }
    }
}

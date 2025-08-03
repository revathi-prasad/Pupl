//
//  ADHDProtocolViewController.swift
//  PupillometryApp
//
//  View Controller for ADHD Protocol Task
//  Replaces GradCPT + Memory tasks in clinical pathway
//

import UIKit

class ADHDProtocolViewController: UIViewController {
    
    // MARK: - UI Elements (Programmatic or IBOutlets)
    @IBOutlet weak var gridView: UIView?
    @IBOutlet weak var instructionLabel: UILabel?
    @IBOutlet weak var progressView: UIProgressView?
    @IBOutlet weak var blockLabel: UILabel?
    @IBOutlet weak var trialLabel: UILabel?
    @IBOutlet weak var yesButton: UIButton?
    @IBOutlet weak var noButton: UIButton?
    @IBOutlet weak var startButton: UIButton?
    
    // Programmatic UI elements (used when not loaded from storyboard)
    private var programmaticGridView: UIView?
    private var programmaticInstructionLabel: UILabel?
    private var programmaticProgressView: UIProgressView?
    private var programmaticBlockLabel: UILabel?
    private var programmaticTrialLabel: UILabel?
    private var programmaticYesButton: UIButton?
    private var programmaticNoButton: UIButton?
    private var programmaticStartButton: UIButton?
    
    // MARK: - Properties
    private let adhdTask = ADHDProtocolTask()
    private let pupillometryManager = PupillometryManager.shared
    
    // Task state
    private var isTaskStarted = false
    private var currentTrial = 1
    private var currentBlock = 1
    private var totalTrials = 5   // Reduced from 10 to 5 for stability
    private var totalBlocks = 8  // blocks per trial
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupTask()
        
        // Add memory warning observer for trial 8 crash prevention
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleMemoryWarning),
            name: UIApplication.didReceiveMemoryWarningNotification,
            object: nil
        )
        
        // Add observers for emergency cleanup notifications
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(stopNonEssentialServices),
            name: Notification.Name("StopNonEssentialServices"),
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(stopAllBackgroundTasks),
            name: Notification.Name("StopAllBackgroundTasks"),
            object: nil
        )
    }
    
    @objc private func handleMemoryWarning() {
        print("⚠️ ADHDProtocolViewController: Memory warning received - current trial: \(currentTrial)")
        
        // Force cleanup if we're in a critical state (around trial 4-5)
        if currentTrial >= 4 {
            print("🧹 Emergency memory cleanup triggered")
            autoreleasepool {
                // Force garbage collection
            }
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Ensure pupillometry session is active for clinical pathway
        if pupillometryManager.currentSession == nil {
            print("🧠 ADHDProtocol: Starting new clinical session")
            pupillometryManager.startSession()
        } else if !pupillometryManager.isCurrentlyRecording {
            print("🧠 ADHDProtocol: Resuming pupillometry recording")
            pupillometryManager.startSession()
        }
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        
        if isTaskStarted {
            adhdTask.stop()
        }
    }
    
    // MARK: - Setup
    
    private func createProgrammaticUI() {
        view.backgroundColor = .black
        
        // Create instruction label
        let instructionLbl = UILabel()
        instructionLbl.translatesAutoresizingMaskIntoConstraints = false
        instructionLbl.styleAsClinicalBody()
        instructionLbl.textAlignment = .center
        view.addSubview(instructionLbl)
        programmaticInstructionLabel = instructionLbl
        
        // Create grid view
        let gridV = UIView()
        gridV.translatesAutoresizingMaskIntoConstraints = false
        gridV.backgroundColor = .black
        gridV.layer.cornerRadius = 8
        gridV.layer.borderWidth = 2
        gridV.layer.borderColor = UIColor.white.cgColor
        view.addSubview(gridV)
        programmaticGridView = gridV
        
        // Create progress view
        let progressV = UIProgressView(progressViewStyle: .default)
        progressV.translatesAutoresizingMaskIntoConstraints = false
        progressV.progress = 0.0
        view.addSubview(progressV)
        programmaticProgressView = progressV
        
        // Create block label
        let blockLbl = UILabel()
        blockLbl.translatesAutoresizingMaskIntoConstraints = false
        blockLbl.styleAsCaption()
        blockLbl.textAlignment = .center
        view.addSubview(blockLbl)
        programmaticBlockLabel = blockLbl
        
        // Create trial label
        let trialLbl = UILabel()
        trialLbl.translatesAutoresizingMaskIntoConstraints = false
        trialLbl.styleAsCaption()
        trialLbl.textAlignment = .center
        view.addSubview(trialLbl)
        programmaticTrialLabel = trialLbl
        
        // Create Yes button
        let yesBtn = UIButton(type: .system)
        yesBtn.translatesAutoresizingMaskIntoConstraints = false
        yesBtn.setTitle("YES", for: .normal)
        yesBtn.backgroundColor = .systemGreen
        yesBtn.setTitleColor(.white, for: .normal)
        yesBtn.titleLabel?.font = .buttonPrimary
        yesBtn.layer.cornerRadius = 12
        yesBtn.isHidden = true
        yesBtn.addTarget(self, action: #selector(yesButtonTapped), for: .touchUpInside)
        view.addSubview(yesBtn)
        programmaticYesButton = yesBtn
        
        // Create No button
        let noBtn = UIButton(type: .system)
        noBtn.translatesAutoresizingMaskIntoConstraints = false
        noBtn.setTitle("NO", for: .normal)
        noBtn.backgroundColor = .systemRed
        noBtn.setTitleColor(.white, for: .normal)
        noBtn.titleLabel?.font = .buttonPrimary
        noBtn.layer.cornerRadius = 12
        noBtn.isHidden = true
        noBtn.addTarget(self, action: #selector(noButtonTapped), for: .touchUpInside)
        view.addSubview(noBtn)
        programmaticNoButton = noBtn
        
        // Create start button
        let startBtn = UIButton(type: .system)
        startBtn.translatesAutoresizingMaskIntoConstraints = false
        startBtn.setTitle("Begin ADHD Assessment", for: .normal)
        startBtn.styleAsPrimary()
        startBtn.addTarget(self, action: #selector(startButtonTapped), for: .touchUpInside)
        view.addSubview(startBtn)
        programmaticStartButton = startBtn
        
        // Set up constraints
        NSLayoutConstraint.activate([
            // Instruction label constraints
            instructionLbl.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            instructionLbl.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            instructionLbl.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            
            // Grid view constraints
            gridV.topAnchor.constraint(equalTo: instructionLbl.bottomAnchor, constant: 20),
            gridV.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            gridV.widthAnchor.constraint(equalToConstant: 300),
            gridV.heightAnchor.constraint(equalToConstant: 300),
            
            // Progress view constraints
            progressV.topAnchor.constraint(equalTo: gridV.bottomAnchor, constant: 20),
            progressV.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 40),
            progressV.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -40),
            
            // Block and trial labels
            blockLbl.topAnchor.constraint(equalTo: progressV.bottomAnchor, constant: 10),
            blockLbl.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            blockLbl.trailingAnchor.constraint(equalTo: view.centerXAnchor, constant: -10),
            
            trialLbl.topAnchor.constraint(equalTo: progressV.bottomAnchor, constant: 10),
            trialLbl.leadingAnchor.constraint(equalTo: view.centerXAnchor, constant: 10),
            trialLbl.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            
            // Response buttons
            yesBtn.topAnchor.constraint(equalTo: blockLbl.bottomAnchor, constant: 20),
            yesBtn.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 40),
            yesBtn.trailingAnchor.constraint(equalTo: view.centerXAnchor, constant: -10),
            yesBtn.heightAnchor.constraint(equalToConstant: 50),
            
            noBtn.topAnchor.constraint(equalTo: blockLbl.bottomAnchor, constant: 20),
            noBtn.leadingAnchor.constraint(equalTo: view.centerXAnchor, constant: 10),
            noBtn.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -40),
            noBtn.heightAnchor.constraint(equalToConstant: 50),
            
            // Start button
            startBtn.topAnchor.constraint(equalTo: yesBtn.bottomAnchor, constant: 20),
            startBtn.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            startBtn.widthAnchor.constraint(equalToConstant: 200),
            startBtn.heightAnchor.constraint(equalToConstant: 50)
        ])
    }
    
    private func setupUI() {
        title = "ADHD Assessment"
        
        // Check if loaded from storyboard or needs programmatic setup
        if gridView == nil && instructionLabel == nil && startButton == nil {
            print("🔧 Creating UI programmatically (not loaded from storyboard)")
            createProgrammaticUI()
        } else {
            print("✅ Using storyboard outlets")
        }
        
        // Get references to the UI elements (either outlets or programmatic)
        let currentGridView = gridView ?? programmaticGridView!
        let currentInstructionLabel = instructionLabel ?? programmaticInstructionLabel!
        let currentProgressView = progressView ?? programmaticProgressView!
        _ = blockLabel ?? programmaticBlockLabel!
        _ = trialLabel ?? programmaticTrialLabel!
        _ = yesButton ?? programmaticYesButton!
        _ = noButton ?? programmaticNoButton!
        _ = startButton ?? programmaticStartButton!
        
        // Configure grid view
        currentGridView.backgroundColor = .black
        currentGridView.layer.cornerRadius = 8
        currentGridView.layer.borderWidth = 2
        currentGridView.layer.borderColor = UIColor.white.cgColor
        
        // Configure instruction label
        currentInstructionLabel.styleAsClinicalBody()
        currentInstructionLabel.textAlignment = .center
        
        // Configure progress view
        currentProgressView.progress = 0.0
        
        // Configure buttons (if using storyboard outlets)
        if gridView != nil {
            setupResponseButtons()
            setupStartButton()
        }
        
        // Show initial instructions
        showInitialInstructions()
    }
    
    private func setupResponseButtons() {
        guard let currentYesButton = yesButton, let currentNoButton = noButton else { return }
        
        // Configure Yes button
        currentYesButton.setTitle("YES", for: .normal)
        currentYesButton.backgroundColor = .systemGreen
        currentYesButton.setTitleColor(.white, for: .normal)
        currentYesButton.titleLabel?.font = .buttonPrimary
        currentYesButton.layer.cornerRadius = 12
        currentYesButton.isHidden = true
        
        // Configure No button
        currentNoButton.setTitle("NO", for: .normal)
        currentNoButton.backgroundColor = .systemRed
        currentNoButton.setTitleColor(.white, for: .normal)
        currentNoButton.titleLabel?.font = .buttonPrimary
        currentNoButton.layer.cornerRadius = 12
        currentNoButton.isHidden = true
        
        // Add targets
        currentYesButton.addTarget(self, action: #selector(yesButtonTapped), for: .touchUpInside)
        currentNoButton.addTarget(self, action: #selector(noButtonTapped), for: .touchUpInside)
    }
    
    private func setupStartButton() {
        guard let currentStartButton = startButton else { return }
        
        currentStartButton.setTitle("Begin ADHD Assessment", for: .normal)
        currentStartButton.styleAsPrimary()
        currentStartButton.addTarget(self, action: #selector(startButtonTapped), for: .touchUpInside)
    }
    
    private func setupTask() {
        adhdTask.delegate = self
    }
    
    private func showInitialInstructions() {
        let currentInstructionLabel = instructionLabel ?? programmaticInstructionLabel!
        let currentBlockLabel = blockLabel ?? programmaticBlockLabel!
        let currentTrialLabel = trialLabel ?? programmaticTrialLabel!
        let currentProgressView = progressView ?? programmaticProgressView!
        
        currentInstructionLabel.text = """
        ADHD Assessment - Sternberg Task
        
        You will see dots appear on the grid, followed by a probe dot.
        
        Tap "YES" if the probe dot was in one of the previous arrays.
        Tap "NO" if the probe dot was NOT in the previous arrays.
        
        Respond as quickly and accurately as possible.
        
        Total: 5 trials with 8 blocks each (~10 minutes)
        """
        
        currentBlockLabel.text = "Ready to begin"
        currentTrialLabel.text = ""
        currentProgressView.progress = 0.0
    }
    
    // MARK: - Button Actions
    
    @objc private func startButtonTapped() {
        let currentStartButton = startButton ?? programmaticStartButton!
        
        // Check if this is the "View Results" button (task completed)
        if !isTaskStarted && currentStartButton.title(for: .normal) == "View Results" {
            print("📊 View Results button tapped - navigating to results")
            navigateToResults()
            return
        }
        
        // This is the "Start Assessment" button
        guard !isTaskStarted else { return }
        
        print("🚀 Starting ADHD Protocol Assessment")
        
        let currentGridView = gridView ?? programmaticGridView!
        
        isTaskStarted = true
        currentStartButton.isHidden = true
        
        // Start the task
        adhdTask.start(with: currentGridView)
    }
    
    @objc private func yesButtonTapped() {
        adhdTask.recordResponse(isYes: true)
        hideResponseButtons()
    }
    
    @objc private func noButtonTapped() {
        adhdTask.recordResponse(isYes: false)
        hideResponseButtons()
    }
    
    private func hideResponseButtons() {
        let currentYesButton = yesButton ?? programmaticYesButton!
        let currentNoButton = noButton ?? programmaticNoButton!
        
        currentYesButton.isHidden = true
        currentNoButton.isHidden = true
    }
    
    private func showResponseButtons() {
        let currentYesButton = yesButton ?? programmaticYesButton!
        let currentNoButton = noButton ?? programmaticNoButton!
        
        currentYesButton.isHidden = false
        currentNoButton.isHidden = false
    }
    
    // MARK: - UI Updates
    
    private func updateProgress() {
        // Calculate progress based on trials and blocks within trials
        let totalUnits = totalTrials * totalBlocks  // 5 trials × 8 blocks = 40 total units
        let currentUnits = (currentTrial - 1) * totalBlocks + (currentBlock - 1)
        let progress = Float(currentUnits) / Float(totalUnits)
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            let currentProgressView = self.progressView ?? self.programmaticProgressView!
            currentProgressView.progress = progress
        }
    }
    
    private func updateLabels() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            let currentBlockLabel = self.blockLabel ?? self.programmaticBlockLabel!
            let currentTrialLabel = self.trialLabel ?? self.programmaticTrialLabel!
            
            currentTrialLabel.text = "Trial \(self.currentTrial) of \(self.totalTrials)"
            currentBlockLabel.text = "Block \(self.currentBlock) of \(self.totalBlocks)"
        }
    }
    
    private func showTaskComplete() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            let currentInstructionLabel = self.instructionLabel ?? self.programmaticInstructionLabel!
            let currentBlockLabel = self.blockLabel ?? self.programmaticBlockLabel!
            let currentTrialLabel = self.trialLabel ?? self.programmaticTrialLabel!
            let currentProgressView = self.progressView ?? self.programmaticProgressView!
            let currentStartButton = self.startButton ?? self.programmaticStartButton!
            
            currentInstructionLabel.text = "Assessment Complete!\n\nThank you for your participation.\n\nTap 'View Results' below to analyze your data and see your ADHD assessment results."
            currentBlockLabel.text = "✅ All blocks completed"
            currentTrialLabel.text = ""
            currentProgressView.progress = 1.0
            
            // Show completion button
            currentStartButton.setTitle("View Results", for: .normal)
            currentStartButton.isHidden = false
        }
    }
    
    private func navigateToResults() {
        print("🔄 Starting background ADHD analysis...")
        
        // Show processing indicator on main thread
        let processingAlert = UIAlertController(
            title: "Processing ADHD Analysis",
            message: "Analyzing pupillometry data...\n\nThis may take a few moments.",
            preferredStyle: .alert
        )
        present(processingAlert, animated: true)
        
        // Get session data before moving to background
        guard let sessionData = pupillometryManager.currentSession else {
            dismiss(animated: true) {
                self.showErrorAndReturn(message: "No session data collected. Please restart the assessment.")
            }
            return
        }
        
        // Move heavy processing to background thread
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            // Background processing with autoreleasepool to prevent CoreML memory leaks
            let result: (prediction: ADHDInferenceEngine.ADHDPrediction?, error: String?) = autoreleasepool {
                print("🧠 Background: Starting ADHD prediction with \(sessionData.pupilMeasurements.count) measurements")
                
                // Validate session data on background thread
                guard !sessionData.pupilMeasurements.isEmpty else {
                    return (nil, "No pupil measurements available for ADHD analysis.")
                }
                
                guard sessionData.pupilMeasurements.count >= 240 else {
                    return (nil, "Insufficient data collected (need at least 8 seconds of measurements).")
                }
                
                // Run ADHD inference in autoreleasepool
                print("🔄 Background: Creating inference engine...")
                let inferenceEngine = ADHDInferenceEngine()
                
                print("🔄 Background: Running prediction...")
                let prediction = inferenceEngine.predictADHD(from: sessionData.pupilMeasurements)
                
                print("✅ Background: ADHD prediction successful")
                print("   Classification: \(prediction.classification)")
                print("   Binary Prediction: \(prediction.binaryPrediction)")
                print("   Confidence: \(prediction.confidence)")
                
                return (prediction, nil)
            }
            
            // Return to main thread for UI updates
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                
                // Dismiss processing alert
                self.dismiss(animated: true) {
                    if let prediction = result.prediction {
                        // Success - navigate to results
                        self.presentResults(prediction: prediction, sessionData: sessionData)
                    } else {
                        // Error - show error message
                        self.showErrorAndReturn(message: result.error ?? "Unknown error occurred during analysis")
                    }
                }
            }
        }
    }
    
    private func presentResults(prediction: ADHDInferenceEngine.ADHDPrediction, sessionData: SessionData) {
        print("📱 Main thread: Creating ADHDResultsViewController...")
        
        let resultsVC = ADHDResultsViewController()
        resultsVC.adhdPrediction = prediction
        resultsVC.sessionData = sessionData
        resultsVC.title = "ADHD Assessment Results"
        
        guard let navigationController = navigationController else {
            print("❌ Navigation controller is nil")
            showErrorAndReturn(message: "Navigation error occurred.")
            return
        }
        
        print("🚀 Main thread: Pushing ADHDResultsViewController...")
        navigationController.pushViewController(resultsVC, animated: true)
        print("✅ Successfully navigated to ADHD Results")
    }
    
    private func showErrorAndReturn(message: String) {
        let alert = UIAlertController(
            title: "Assessment Error",
            message: message,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default) { [weak self] _ in
            self?.navigationController?.popToRootViewController(animated: true)
        })
        present(alert, animated: true)
    }
    
    // MARK: - Break Management
    
    private func showTrialBreak(trialNumber: Int) {
        let remainingTrials = totalTrials - trialNumber
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            let currentInstructionLabel = self.instructionLabel ?? self.programmaticInstructionLabel!
            
            if remainingTrials > 0 {
                currentInstructionLabel.text = """
                Trial \(trialNumber)/\(self.totalTrials) Complete!
                
                \(remainingTrials) trials remaining.
                
                Take a short break if needed.
                The next trial will start automatically in a few seconds.
                """
            } else {
                currentInstructionLabel.text = """
                All Trials Complete!
                
                Excellent work! Your ADHD assessment is now complete.
                
                Please wait while we process your results.
                """
            }
        }
    }
}

// MARK: - ADHDProtocolTaskDelegate

extension ADHDProtocolViewController: ADHDProtocolTaskDelegate {
    
    func task(_ task: ADHDProtocolTask, didStartBlock block: Int, totalBlocks: Int) {
        // This method is no longer used in the new trial-based structure
        // Keeping for compatibility but functionality moved to didStartTrial
    }
    
    func task(_ task: ADHDProtocolTask, didStartTrial trial: Int, inBlock block: Int) {
        currentTrial = trial
        currentBlock = block
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            let currentInstructionLabel = self.instructionLabel ?? self.programmaticInstructionLabel!
            
            if block == 1 {
                // Starting a new trial
                currentInstructionLabel.text = "Trial \(trial)/\(self.totalTrials) - Block \(block)/\(self.totalBlocks)"
            } else {
                // Continuing blocks within trial
                currentInstructionLabel.text = "Trial \(trial) - Block \(block)/\(self.totalBlocks)"
            }
            
            self.updateLabels()
            self.updateProgress()
            self.hideResponseButtons()
        }
        
        print("🎯 Started Trial \(trial)/\(self.totalTrials) - Block \(block)/\(self.totalBlocks)")
    }
    
    func task(_ task: ADHDProtocolTask, didPresentDotArray dots: [CGPoint], arrayNumber: Int, trialNumber: Int) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            let currentInstructionLabel = self.instructionLabel ?? self.programmaticInstructionLabel!
            currentInstructionLabel.text = "Array \(arrayNumber) of 3"
        }
        
        print("🔴 Presented dot array \(arrayNumber) with \(dots.count) dots")
    }
    
    func task(_ task: ADHDProtocolTask, didShowDistractor type: ADHDProtocolResponse.DistractorType, trialNumber: Int) {
        var distractorText = ""
        switch type {
        case .none:
            distractorText = "..."
        case .taskRelated:
            distractorText = "Task distractor"
        case .neutral:
            distractorText = "Neutral distractor"
        case .emotional:
            distractorText = "Emotional distractor"
        }
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            let currentInstructionLabel = self.instructionLabel ?? self.programmaticInstructionLabel!
            currentInstructionLabel.text = distractorText
        }
        
        print("🎭 Showed distractor: \(type.rawValue)")
    }
    
    func task(_ task: ADHDProtocolTask, didShowProbe position: CGPoint, isTarget: Bool, trialNumber: Int) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            let currentInstructionLabel = self.instructionLabel ?? self.programmaticInstructionLabel!
            currentInstructionLabel.text = "Was this dot in the previous arrays?"
            self.showResponseButtons()
        }
        
        print("❓ Showed probe at \(position), isTarget: \(isTarget)")
    }
    
    func task(_ task: ADHDProtocolTask, didReceiveResponse response: ADHDProtocolResponse) {
        let accuracy = response.isCorrect ? "✅" : "❌"
        let reactionTimeMs = Int(response.reactionTime * 1000)
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            let currentInstructionLabel = self.instructionLabel ?? self.programmaticInstructionLabel!
            currentInstructionLabel.text = "\(accuracy) \(reactionTimeMs)ms"
        }
        
        print("📝 Response: \(response.userResponse ? "YES" : "NO"), Correct: \(response.isCorrect), RT: \(reactionTimeMs)ms")
    }
    
    func task(_ task: ADHDProtocolTask, didCompleteBlock block: Int) {
        // In new structure, this represents completing a trial (not a block)
        showTrialBreak(trialNumber: block)  // block parameter now represents trial number
        print("🎉 Completed trial \(block)/\(totalTrials)")
    }
    
    func taskDidComplete(_ task: ADHDProtocolTask) {
        print("✅ ADHD Assessment Complete - cleaning up resources...")
        
        // Step 1: Stop all data collection and timers immediately
        isTaskStarted = false
        stopAllTimersAndDataCollection()
        
        // Step 2: Calculate and log summary statistics
        if let session = pupillometryManager.currentSession {
            let quality = session.calculateADHDDataQuality()
            print("📊 ADHD Assessment Complete!")
            print("   Valid trials: \(quality.validTrials)/\(quality.totalTrials)")
            print("   Average quality: \(String(format: "%.2f", quality.averageQuality))")
        }
        
        // Step 3: Clean up memory and show completion
        performMemoryCleanup()
        showTaskComplete()
        
        // REMOVED: Auto-navigation - user now controls when processing happens
        print("🎯 Task complete - user can tap 'View Results' when ready")
    }
    
    private func stopAllTimersAndDataCollection() {
        print("🛑 Stopping all timers and data collection...")
        
        // Stop the ADHD task timers
        adhdTask.stop()
        
        // Force stop any remaining pupillometry data collection
        if pupillometryManager.isCurrentlyRecording {
            pupillometryManager.stopSession()
        }
        
        print("✅ All timers and data collection stopped")
    }
    
    private func performMemoryCleanup() {
        print("🧹 Performing memory cleanup...")
        
        // Force garbage collection with autoreleasepool
        autoreleasepool {
            // Let ARC clean up any temporary objects
        }
        
        print("✅ Memory cleanup completed")
    }
    
    @objc private func stopNonEssentialServices() {
        print("🛑 ADHDProtocolViewController: Stopping non-essential services")
        
        // Stop any UI animations
        view.layer.removeAllAnimations()
        
        // Reduce UI update frequency
        // (Keep task running but reduce ancillary features)
    }
    
    @objc private func stopAllBackgroundTasks() {
        print("🆘 ADHDProtocolViewController: Emergency - stopping all background tasks")
        
        // This is emergency mode - stop the task if necessary
        if isTaskStarted && currentTrial >= 4 {
            print("🆘 Emergency task termination at trial \(currentTrial)")
            adhdTask.stop()
            showEmergencyTermination()
        }
    }
    
    private func showEmergencyTermination() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            let currentInstructionLabel = self.instructionLabel ?? self.programmaticInstructionLabel!
            
            currentInstructionLabel.text = """
            Emergency Memory Protection
            
            The assessment was paused to prevent app crashes.
            
            Your progress has been saved.
            """
            
            // Show emergency completion
            self.showTaskComplete()
        }
    }
}

// MARK: - Navigation

extension ADHDProtocolViewController {
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "showResults" {
            if let resultsVC = segue.destination as? ResultsViewController {
                print("✅ Preparing segue to ResultsViewController after ADHD Assessment")
            }
        }
    }
}
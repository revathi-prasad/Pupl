//
//  ChangeLocalizationViewController.swift
//  PupillometryApp
//
//  Created by Revathi Prasad on 25/06/25.
//

import UIKit

class ChangeLocalizationViewController: UIViewController {
    @IBOutlet weak var instructionLabel: UILabel!
    @IBOutlet weak var progressView: UIProgressView!
    @IBOutlet weak var gridContainerView: UIView!
    @IBOutlet weak var statusLabel: UILabel!
    
    private let changeLocalizationTask = ChangeLocalizationTask()
    private let pupillometryManager = PupillometryManager.shared
    
    // UI State
    private var gridButtons: [UIButton] = []
    private var isInRetentionPhase = false
    private var currentArray: ChangeLocalizationTask.TrialArray?
    
    // Task timing parameters (synchronized with ChangeLocalizationTask)
    private let encodingDuration: TimeInterval = 2.0 // Match task's encoding duration
    private let retentionInterval: TimeInterval = 1.0 // Match task's retention interval
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupTask()
        
        // Test haptic feedback on load
        print("🔧 Testing haptic feedback...")
        HapticFeedbackManager.shared.neutralResponse()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        startTask()
    }
    
    private func setupUI() {
        title = "Change Localization Task"
        view.backgroundColor = .black
        
        instructionLabel.text = "Remember the colors, then identify what changed"
        instructionLabel.textColor = .white
        instructionLabel.textAlignment = .center
        instructionLabel.font = UIFont.systemFont(ofSize: 18, weight: .medium)
        
        progressView.progress = 0.0
        progressView.progressTintColor = .systemBlue
        
        statusLabel.textColor = .lightGray
        statusLabel.textAlignment = .center
        statusLabel.text = "Loading..."
        statusLabel.font = UIFont.systemFont(ofSize: 14)
        
        // Setup grid container
        gridContainerView.backgroundColor = .clear
    }
    
    private func setupTask() {
        changeLocalizationTask.delegate = self
    }
    
    private func startTask() {
        print("🚀 ChangeLocalizationViewController: Starting Change Localization Task")
        pupillometryManager.startSession()
        changeLocalizationTask.start()
    }
    
    private func createGrid(for trial: ChangeLocalizationTask.TrialArray) {
        // Clear existing grid
        gridButtons.forEach { $0.removeFromSuperview() }
        gridButtons.removeAll()
        
        // Calculate grid layout based on set size
        let gridSize = gridSizeFor(setSize: trial.setSize)
        let buttonSize: CGFloat = 80
        let spacing: CGFloat = 20
        
        let totalWidth = CGFloat(gridSize.columns) * buttonSize + CGFloat(gridSize.columns - 1) * spacing
        let totalHeight = CGFloat(gridSize.rows) * buttonSize + CGFloat(gridSize.rows - 1) * spacing
        
        let startX = (gridContainerView.bounds.width - totalWidth) / 2
        let startY = (gridContainerView.bounds.height - totalHeight) / 2
        
        // Create buttons for the grid
        for i in 0..<trial.setSize {
            let row = i / gridSize.columns
            let col = i % gridSize.columns
            
            let x = startX + CGFloat(col) * (buttonSize + spacing)
            let y = startY + CGFloat(row) * (buttonSize + spacing)
            
            let button = UIButton(type: .custom)
            button.frame = CGRect(x: x, y: y, width: buttonSize, height: buttonSize)
            button.backgroundColor = trial.colors[i]
            button.layer.borderWidth = 2
            button.layer.borderColor = UIColor.darkGray.cgColor
            button.layer.cornerRadius = 8
            button.tag = i
            button.addTarget(self, action: #selector(gridButtonTapped(_:)), for: .touchUpInside)
            button.isEnabled = false // Initially disabled during encoding
            
            gridContainerView.addSubview(button)
            gridButtons.append(button)
        }
    }
    
    private func gridSizeFor(setSize: Int) -> (rows: Int, columns: Int) {
        switch setSize {
        case 4: return (2, 2)
        case 6: return (2, 3)
        case 8: return (2, 4)
        default: return (2, 3)
        }
    }
    
    @objc private func gridButtonTapped(_ sender: UIButton) {
        print("🔵 Button tapped! Tag: \(sender.tag), isInRetentionPhase: \(isInRetentionPhase)")
        
        guard isInRetentionPhase else { 
            print("❌ Button tap ignored - not in retention phase")
            return 
        }
        
        // Immediate neutral haptic feedback to confirm tap registration
        HapticFeedbackManager.shared.neutralResponse()
        print("🔵 Neutral haptic feedback - tap registered")
        
        let selectedIndex = sender.tag
        print("🔵 Recording response for index: \(selectedIndex)")
        
        // Visual feedback BEFORE recording response to ensure it's visible
        sender.layer.borderColor = UIColor.yellow.cgColor // More visible color
        sender.layer.borderWidth = 6
        sender.backgroundColor = sender.backgroundColor?.withAlphaComponent(0.7) // Slightly dim
        
        // Brief pause to show selection, then record response
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            self?.changeLocalizationTask.recordResponse(selectedIndex: selectedIndex)
        }
        
        // Disable all buttons after response
        gridButtons.forEach { $0.isEnabled = false }
    }
    
    private func showRetentionPhase(for trial: ChangeLocalizationTask.TrialArray) {
        print("🔵 ChangeLocalizationViewController: Starting retention phase")
        
        // Disable all buttons and hide them (blank screen during retention)
        gridButtons.forEach { button in
            button.isHidden = true
            button.isEnabled = false
            button.isUserInteractionEnabled = false
            button.layer.borderColor = UIColor.darkGray.cgColor
            button.layer.borderWidth = 2
        }
        
        instructionLabel.text = "Remember the colors..."
        statusLabel.text = "Retention period"
        isInRetentionPhase = false // Not in retention phase for user interaction
        
        print("🔵 ChangeLocalizationViewController: All buttons disabled and hidden for retention")
        
        // After retention interval, show test array (using actual task timing)
        DispatchQueue.main.asyncAfter(deadline: .now() + retentionInterval) { [weak self] in
            print("🔵 ChangeLocalizationViewController: Retention period complete after \(self?.retentionInterval ?? 1.0)s")
            self?.showTestPhase(for: trial)
        }
    }
    
    private func showTestPhase(for trial: ChangeLocalizationTask.TrialArray) {
        print("🔵 ChangeLocalizationViewController: Starting test phase")
        
        // Show buttons again with one color changed
        gridButtons.forEach { $0.isHidden = false }
        
        // Update the changed item's color
        if trial.changedIndex < gridButtons.count {
            gridButtons[trial.changedIndex].backgroundColor = trial.newColor
            print("🔵 Changed square \(trial.changedIndex) to new color")
        }
        
        // Enable all buttons for response
        gridButtons.forEach { button in 
            button.isEnabled = true 
            button.isUserInteractionEnabled = true
            button.layer.borderColor = UIColor.systemBlue.cgColor // Blue border when interactive
            button.layer.borderWidth = 3
            button.alpha = 1.0
        }
        
        print("🔵 All \(gridButtons.count) buttons enabled for interaction")
        
        instructionLabel.text = "Which square changed color?"
        statusLabel.text = "Tap the changed square"
        isInRetentionPhase = true
        
        print("🔵 Test phase ready - isInRetentionPhase: \(isInRetentionPhase)")
    }
    
    @IBAction func backButtonTapped(_ sender: UIButton) {
        changeLocalizationTask.stop()
        pupillometryManager.stopSession()
        navigationController?.popViewController(animated: true)
    }
}

// MARK: - ChangeLocalizationTaskDelegate
extension ChangeLocalizationViewController: ChangeLocalizationTaskDelegate {
    func task(_ task: ChangeLocalizationTask, didPresentArray array: ChangeLocalizationTask.TrialArray, at time: TimeInterval) {
        currentArray = array
        isInRetentionPhase = false
        
        DispatchQueue.main.async { [weak self] in
            // Update progress
            let progress = Float(array.trialNumber) / Float(task.getCurrentTrialInfo()?.totalTrials ?? 240)
            self?.progressView.progress = progress
            
            // Update status
            if let trialInfo = task.getCurrentTrialInfo() {
                self?.statusLabel.text = "Trial \(trialInfo.trialNumber) of \(trialInfo.totalTrials) • Set size: \(trialInfo.setSize)"
            }
            
            // Create and show the grid
            self?.createGrid(for: array)
            self?.instructionLabel.text = "Remember these colors"
            
            // Record the event
            let event = TaskEvent(
                timestamp: time,
                type: .stimulusOnset,
                data: [
                    "trial": array.trialNumber,
                    "setSize": array.setSize,
                    "changedIndex": array.changedIndex,
                    "taskType": "changeLocalization"
                ],
                contentType: .memory
            )
            PupillometryManager.shared.recordEvent(event)
            
            // After encoding duration, start retention phase (using actual task timing)
            DispatchQueue.main.asyncAfter(deadline: .now() + (self?.encodingDuration ?? 2.0)) {
                print("🔵 ChangeLocalizationViewController: Starting retention phase after \(self?.encodingDuration ?? 2.0)s encoding")
                self?.showRetentionPhase(for: array)
            }
        }
    }
    
    func task(_ task: ChangeLocalizationTask, didReceiveResponse correct: Bool, reactionTime: TimeInterval, selectedIndex: Int, setSize: Int, trial: Int) {
        print("📊 Response: \(correct ? "Correct" : "Incorrect"), RT: \(String(format: "%.3f", reactionTime))s, Set Size: \(setSize)")
        
        // Track performance data for ChangeLocalizationTask
        pupillometryManager.currentSession?.addMemoryTaskResponse(
            setSize: setSize,
            correct: correct,
            reactionTime: reactionTime,
            trialNumber: trial
        )
        
        // Record the response event
        let event = TaskEvent(
            timestamp: CACurrentMediaTime(),
            type: .response,
            data: [
                "correct": correct,
                "reactionTime": reactionTime,
                "selectedIndex": selectedIndex,
                "setSize": setSize,
                "trial": trial,
                "taskType": "changeLocalization"
            ],
            contentType: .memory
        )
        PupillometryManager.shared.recordEvent(event)
        
        // No visual feedback to avoid bias - response tracking is silent
        // Performance data is recorded for research analysis
    }
    
    func taskDidComplete(_ task: ChangeLocalizationTask) {
        print("🎯 ChangeLocalizationViewController: Change Localization Task completed!")
        
        DispatchQueue.main.async { [weak self] in
            self?.instructionLabel.text = "Task Complete!"
            self?.statusLabel.text = "Processing results..."
            self?.progressView.progress = 1.0
            
            // Navigate to results
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                self?.performSegue(withIdentifier: "showResults", sender: self)
            }
        }
    }
}
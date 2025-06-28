//
//  AssessmentViewController.swift
//  PupillometryApp
//
//  Created by Revathi Prasad on 10/06/25.
//

//import UIKit
//
//class AssessmentViewController: UIViewController {
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
// AssessmentViewController.swift
import UIKit

class AssessmentViewController: UIViewController {
    @IBOutlet weak var testDisplayView: UIView!
    @IBOutlet weak var taskInstructionLabel: UILabel!
    @IBOutlet weak var progressView: UIProgressView!
    @IBOutlet weak var trialCounterLabel: UILabel!
    @IBOutlet weak var stopTestButton: UIButton!
    
    private let gradCPTTask = GradCPTTask()
    private let pupillometryManager = PupillometryManager.shared
    private let memoryTask = MemoryTask()
    
    private var currentTask: TaskProtocol?
    private var taskCompleted = false
    public var totalTrials: Int = 900
    
    override func viewDidLoad() {
        super.viewDidLoad()
        print("📱 AssessmentViewController: viewDidLoad() called")
        setupUI()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        print("📱 AssessmentViewController: viewWillAppear() called")
        
        // DO NOT AUTO-START PUPILLOMETRY SESSION
        // It will be started when user clicks "Start Task"
        print("⏸️ AssessmentViewController: NOT auto-starting pupillometry session")
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        print("📱 AssessmentViewController: viewDidAppear() called")
    }
    
    private func setupUI() {
        print("🔧 AssessmentViewController: setupUI() called")
        
        // Check if outlets are connected
        if stopTestButton == nil {
            print("❌ CRITICAL: stopTestButton outlet is nil!")
            return
        }
        if taskInstructionLabel == nil {
            print("❌ CRITICAL: taskInstructionLabel outlet is nil!")
            return
        }
        if testDisplayView == nil {
            print("❌ CRITICAL: testDisplayView outlet is nil!")
            return
        }
        print("✅ All IBOutlets are connected properly")
        
        // Configure UI elements
        stopTestButton.layer.cornerRadius = 8.0
        progressView.progress = 0.0
        
        // Configure instruction label font
        taskInstructionLabel.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        taskInstructionLabel.textAlignment = .center
        taskInstructionLabel.numberOfLines = 0
        
        // Configure trial counter label font
        trialCounterLabel.font = UIFont.systemFont(ofSize: 14, weight: .regular)
        trialCounterLabel.textAlignment = .center
        
        print("🔧 UI Setup complete")
        
        // DO NOT AUTO-START ANYTHING
        // Wait for user to explicitly start the task
        print("🔍 AssessmentViewController: Ready - waiting for user to start task")
        
        // Just show initial instructions - no auto-starting
        showInitialInstructions()
    }
    
    private func showInitialInstructions() {
        print("📋 AssessmentViewController: Showing initial task instructions")
        
        // Show instruction text  
        taskInstructionLabel.text = "Face Recognition Task\n\nTap the screen when you see a MALE face\nDo NOT tap for FEMALE faces"
        trialCounterLabel.text = "Ready to begin task"
        
        // Configure button - BLUE not green
        stopTestButton.setTitle("Start Task", for: .normal)
        stopTestButton.backgroundColor = UIColor.systemBlue
        stopTestButton.setTitleColor(UIColor.white, for: .normal)
        stopTestButton.titleLabel?.font = UIFont.systemFont(ofSize: 18, weight: .bold)
        stopTestButton.isHidden = false
        stopTestButton.isEnabled = true
        
        // Clear display view
        testDisplayView.subviews.forEach { $0.removeFromSuperview() }
        
        print("✅ AssessmentViewController: Ready for user to start task")
    }
    
    private func configureGradCPTTask() {
        print("🔧 AssessmentViewController: configureGradCPTTask() called")
        
        // Force memory cleanup before starting intensive task
        autoreleasepool {
            // Clear any previous task data
        }
        
        taskInstructionLabel.text = "Tap for MALE faces\nDo not tap for FEMALE faces"
        trialCounterLabel.text = "Get ready..."
        gradCPTTask.delegate = self
        currentTask = gradCPTTask
        
        // Optimized trial count for iPhone 11 memory constraints
        gradCPTTask.totalTrials = 50 // Reduced for stability on iPhone 11
        print("📝 Set total trials to: \(gradCPTTask.totalTrials)")
        
        // Clear any existing views
        testDisplayView.subviews.forEach { $0.removeFromSuperview() }
        print("🗑️ Cleared existing views")
        
        // Create stimulus view
        let stimulusView = UIImageView(frame: CGRect(x: 0, y: 0, width: 200, height: 200))
        stimulusView.contentMode = .scaleAspectFit
        stimulusView.center = testDisplayView.center
        stimulusView.tag = 100 // For identification
        testDisplayView.addSubview(stimulusView)
        print("📺 Created stimulus view")
        
        // Configure button for task mode
        stopTestButton.setTitle("Stop Test", for: .normal)
        stopTestButton.backgroundColor = UIColor.systemRed
        stopTestButton.setTitleColor(UIColor.white, for: .normal)
        stopTestButton.titleLabel?.font = UIFont.systemFont(ofSize: 18, weight: .bold)
        stopTestButton.isHidden = false
        stopTestButton.isEnabled = true
        print("🔘 Button configured for task mode")
        
        // Start the task immediately - no delays
        print("🚀 Starting GradCPT task...")
        
        // Delay task start slightly to ensure UI is ready
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            guard let self = self else { return }
            
            do {
                print("🚀 About to call gradCPTTask.start()")
                self.gradCPTTask.start()
                print("✅ GradCPT task started successfully")
            } catch {
                print("❌ Error starting GradCPT task: \(error)")
                // Fallback - show error to user
                self.taskInstructionLabel.text = "Error starting task. Please try again."
                self.stopTestButton.setTitle("Retry", for: .normal)
                self.stopTestButton.backgroundColor = UIColor.systemOrange
            }
        }
    }
    
    private func configureMemoryTask() {
        print("🟦 AssessmentViewController: Configuring memory task...")
        
        taskInstructionLabel.text = "Which square changed color?"
        trialCounterLabel.text = "Get ready for memory task..."
        memoryTask.delegate = self
        currentTask = memoryTask
        
        // Update button for memory task
        stopTestButton.setTitle("Stop Test", for: .normal)
        stopTestButton.backgroundColor = UIColor.systemRed
        stopTestButton.setTitleColor(UIColor.white, for: .normal)
        
        // Remove previous task views
        testDisplayView.subviews.forEach {
            if $0.tag == 100 {
                $0.removeFromSuperview()
            }
        }
        
        // Create memory grid view
        let gridView = MemoryGridView(frame: CGRect(x: 0, y: 0, width: 280, height: 280))
        gridView.center = testDisplayView.center
        gridView.tag = 100
        testDisplayView.addSubview(gridView)
        
        print("🟦 Starting memory task...")
        // Start the task
        memoryTask.start(with: gridView)
    }
    
    @IBAction func stopTestTapped(_ sender: UIButton) {
        let buttonTitle = sender.title(for: .normal) ?? "Unknown"
        print("🔘 Button tapped! Title: '\(buttonTitle)', taskCompleted: \(taskCompleted)")
        
        switch buttonTitle {
        case "Start Task":
            print("🚀 Starting GradCPT task...")
            
            // NOW start pupillometry session
            print("🎬 Starting pupillometry session...")
            pupillometryManager.startSession()
            
            configureGradCPTTask()
            
        case "Next Task":
            print("🟦 Starting Memory task...")
            configureMemoryTask()
            
        case "Show Results":
            print("📊 Going to results...")
            performSegue(withIdentifier: "showResults", sender: self)
            
        case "Stop Test":
            print("⏹️ Stopping test...")
            // Confirm with alert
            let alert = UIAlertController(
                title: "Stop Assessment?",
                message: "Are you sure you want to stop the assessment? Progress will be lost.",
                preferredStyle: .alert
            )
            
            alert.addAction(UIAlertAction(title: "Continue Assessment", style: .cancel))
            
            alert.addAction(UIAlertAction(title: "Stop", style: .destructive) { [weak self] _ in
                self?.currentTask?.stop()
                self?.pupillometryManager.stopSession()
                self?.navigationController?.popToRootViewController(animated: true)
            })
            
            present(alert, animated: true)
            
        default:
            print("⚠️ Unknown button title: \(buttonTitle)")
        }
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        // Forward touch to current task
        if let task = currentTask as? GradCPTTask {
            task.recordResponse()
        }
    }
    
    override func shouldPerformSegue(withIdentifier identifier: String, sender: Any?) -> Bool {
        print("🤔 AssessmentViewController: shouldPerformSegue called with identifier: \(identifier)")
        
        if identifier == "showResults" {
            // Only allow the showResults segue if we're actually ready to show results
            let buttonTitle = stopTestButton.title(for: .normal) ?? ""
            let shouldGo = (buttonTitle == "Show Results")
            print("🤔 Should perform showResults segue? \(shouldGo) (button title: '\(buttonTitle)')")
            return shouldGo
        }
        
        return true
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        print("📱 AssessmentViewController: prepare(for segue) called with identifier: \(segue.identifier ?? "nil")")
        
        if segue.identifier == "showResults" {
            if let resultsVC = segue.destination as? ResultsViewController {
                print("✅ Successfully preparing segue to ResultsViewController")
                // Any setup needed for results can be done here
            } else {
                print("❌ ERROR: Segue destination is not ResultsViewController! It's: \(type(of: segue.destination))")
            }
        } else {
            print("⚠️ Unknown segue identifier: \(segue.identifier ?? "nil")")
        }
    }
}

extension AssessmentViewController: GradCPTTaskDelegate {
    func task(_ task: GradCPTTask, didPresentStimulus stimulus: GradCPTTask.Stimulus, at time: TimeInterval) {
        print("📺 AssessmentViewController: Presenting stimulus - Trial \(stimulus.trialNumber) of \(task.totalTrials)")
        
        // Memory pressure monitoring for critical trials
        if stimulus.trialNumber % 15 == 0 {
            autoreleasepool {
                // Force cleanup every 15 trials
                print("🧹 AssessmentViewController: Memory cleanup at trial \(stimulus.trialNumber)")
            }
        }
        
        // Update stimulus display
        if let imageView = testDisplayView.viewWithTag(100) as? UIImageView {
            imageView.image = stimulus.image
        }
        
        // Update trial counter
        trialCounterLabel.text = "Trial \(stimulus.trialNumber) of \(task.totalTrials)"
        
        // Update progress
        progressView.progress = Float(stimulus.trialNumber) / Float(task.totalTrials)
        
        // Record event
        let event = TaskEvent(
            timestamp: time,
            type: .stimulusOnset,
            data: [
                "trial": stimulus.trialNumber,
                "type": stimulus.type == .target ? "target" : "nonTarget"
            ]
        )
        pupillometryManager.recordEvent(event)
    }
    
    func task(_ task: GradCPTTask, didReceiveResponse correct: Bool, reactionTime: TimeInterval) {
        print("👆 AssessmentViewController: User response - correct: \(correct), RT: \(reactionTime)")
        
        // Record response event
        let event = TaskEvent(
            timestamp: CACurrentMediaTime(),
            type: .response,
            data: [
                "correct": correct,
                "reactionTime": reactionTime
            ]
        )
        pupillometryManager.recordEvent(event)
    }
    
    func taskDidComplete(_ task: GradCPTTask) {
        print("🎯 AssessmentViewController: GradCPT task completed!")
        
        // Show completion message and Next Task button
        taskInstructionLabel.text = "Face Recognition Task Complete!"
        trialCounterLabel.text = "Well done! Ready for the next task?"
        
        // Clear display view
        testDisplayView.subviews.forEach { $0.removeFromSuperview() }
        
        // Configure Next Task button
        stopTestButton.setTitle("Next Task", for: .normal)
        stopTestButton.backgroundColor = UIColor.systemBlue
        stopTestButton.setTitleColor(UIColor.white, for: .normal)
        stopTestButton.isHidden = false
        stopTestButton.isEnabled = true
        
        print("✅ AssessmentViewController: Waiting for user to proceed to memory task")
    }
}

extension AssessmentViewController: MemoryTaskDelegate {
    func memoryTask(_ task: MemoryTask, didStartTrial trial: Int, total: Int) {
        print("🟦 AssessmentViewController: Memory task trial \(trial) of \(total)")
        
        trialCounterLabel.text = "Trial \(trial) of \(total)"
        progressView.progress = Float(trial) / Float(total)
        
        // Record event
        let event = TaskEvent(
            timestamp: CACurrentMediaTime(),
            type: .trialStart,
            data: [
                "trial": trial,
                "total": total
            ]
        )
        pupillometryManager.recordEvent(event)
    }
    
    func memoryTask(_ task: MemoryTask, didReceiveResponse correct: Bool, reactionTime: TimeInterval) {
        print("👆 AssessmentViewController: Memory task response - correct: \(correct), RT: \(reactionTime)")
        
        // Record response event
        let event = TaskEvent(
            timestamp: CACurrentMediaTime(),
            type: .response,
            data: [
                "correct": correct,
                "reactionTime": reactionTime
            ]
        )
        pupillometryManager.recordEvent(event)
    }
    
    func memoryTaskDidComplete(_ task: MemoryTask) {
        print("🎉 AssessmentViewController: Memory task completed! Assessment finished!")
        
        taskCompleted = true
        pupillometryManager.stopSession()
        
        // Update UI for results
        taskInstructionLabel.text = "Assessment Complete!"
        trialCounterLabel.text = "All tasks finished successfully. View your results below."
        stopTestButton.setTitle("Show Results", for: .normal)
        stopTestButton.backgroundColor = UIColor.systemBlue
        stopTestButton.setTitleColor(UIColor.white, for: .normal)
        
        // Clear the display view
        testDisplayView.subviews.forEach { $0.removeFromSuperview() }
        
        print("✅ AssessmentViewController: Ready to show results")
    }
}

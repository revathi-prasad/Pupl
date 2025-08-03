//
//  TaskInstructionsViewController.swift
//  PupillometryApp
//
//  Created by Claude Code on 26/06/25.
//

import UIKit

class TaskInstructionsViewController: UIViewController {
    
    @IBOutlet weak var instructionLabel: UILabel?
    @IBOutlet weak var exampleDisplayView: UIView?
    @IBOutlet weak var startTaskButton: UIButton?
    
    // Programmatic UI elements (used when not loaded from storyboard)
    private var programmaticInstructionLabel: UILabel?
    private var programmaticExampleDisplayView: UIView?
    private var programmaticStartTaskButton: UIButton?
    
    private let pupillometryManager = PupillometryManager.shared
    
    // Pathway-specific properties
    private var currentPathwayType: PathwayType {
        return pupillometryManager.currentSession?.pathwayType ?? .consumer
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }
    
    private func createProgrammaticUI() {
        view.backgroundColor = .black
        
        // Create instruction label
        let instructionLbl = UILabel()
        instructionLbl.translatesAutoresizingMaskIntoConstraints = false
        instructionLbl.styleAsClinicalBody()
        instructionLbl.textAlignment = .center
        view.addSubview(instructionLbl)
        programmaticInstructionLabel = instructionLbl
        
        // Create example display view
        let exampleView = UIView()
        exampleView.translatesAutoresizingMaskIntoConstraints = false
        exampleView.styleAsCard()
        view.addSubview(exampleView)
        programmaticExampleDisplayView = exampleView
        
        // Create start task button
        let startBtn = UIButton(type: .system)
        startBtn.translatesAutoresizingMaskIntoConstraints = false
        startBtn.addTarget(self, action: #selector(startTaskTapped(_:)), for: .touchUpInside)
        view.addSubview(startBtn)
        programmaticStartTaskButton = startBtn
        
        // Set up constraints
        NSLayoutConstraint.activate([
            // Instruction label constraints
            instructionLbl.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            instructionLbl.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            instructionLbl.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            
            // Example display view constraints
            exampleView.topAnchor.constraint(equalTo: instructionLbl.bottomAnchor, constant: 40),
            exampleView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            exampleView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            exampleView.heightAnchor.constraint(equalToConstant: 300),
            
            // Start button constraints
            startBtn.topAnchor.constraint(equalTo: exampleView.bottomAnchor, constant: 30),
            startBtn.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            startBtn.widthAnchor.constraint(equalToConstant: 240),
            startBtn.heightAnchor.constraint(equalToConstant: 50)
        ])
    }
    
    private func setupUI() {
        print("📋 TaskInstructionsViewController: Setting up UI")
        
        // Check if loaded from storyboard or needs programmatic setup
        if instructionLabel == nil && exampleDisplayView == nil && startTaskButton == nil {
            print("🔧 Creating UI programmatically (not loaded from storyboard)")
            createProgrammaticUI()
        } else {
            print("✅ Using storyboard outlets")
        }
        
        // Get references to the UI elements (either outlets or programmatic)
        let currentInstructionLabel = instructionLabel ?? programmaticInstructionLabel!
        let _ = exampleDisplayView ?? programmaticExampleDisplayView!  // currentExampleDisplayView - not used
        let currentStartTaskButton = startTaskButton ?? programmaticStartTaskButton!
        
        // Configure instruction label
        currentInstructionLabel.styleAsClinicalBody()
        currentInstructionLabel.textAlignment = .center
        
        // Setup pathway-specific instructions
        setupInstructionsForPathway(instructionLabel: currentInstructionLabel)
        
        // Configure start button with modern styling
        currentStartTaskButton.styleAsPrimary()
        setupButtonForPathway(button: currentStartTaskButton)
        
        // Generate and show pathway-specific examples
        showExamplesForPathway()
        
        print("✅ TaskInstructionsViewController: UI setup complete")
    }
    
    // MARK: - Pathway-Specific Setup
    
    private func setupInstructionsForPathway(instructionLabel: UILabel) {
        switch currentPathwayType {
        case .clinical:
            instructionLabel.text = """
            ADHD Check-In
            Memory and Focus Test
            
            Quick Overview
            ⏱️ Takes about 5 minutes
            📱 Uses your front camera to track your eyes
            🎯 8 rounds of memory & focus tasks
            
            About The Test
            Remember The Dots - You'll see 3 screens with dots.
            Try to remember where they are.
            
            Distraction Time - While you wait, some things will
            pop up to try and distract you
            
            Memory Check - A new dot will appear. Was it one
            of the ones you saw before?
            """
            
        case .consumer:
            instructionLabel.text = """
            ATTENTION ANALYSIS OVERVIEW
            
            This quick assessment focuses on:
            
            📺 Video Attention Analysis
            👁️ Eye Movement Patterns
            🧠 Focus & Engagement Metrics
            
            ⏱️ Total time: ~5-8 minutes
            📱 Personal insights & summaries
            
            Ready for your attention analysis?
            """
        }
        
        print("📋 TaskInstructions: Setup for \(currentPathwayType.displayName) pathway")
    }
    
    private func setupButtonForPathway(button: UIButton) {
        switch currentPathwayType {
        case .clinical:
            button.setTitle("Begin ADHD Assessment", for: .normal)
        case .consumer:
            button.setTitle("Start Attention Analysis", for: .normal)
        }
    }
    
    private func showExamplesForPathway() {
        switch currentPathwayType {
        case .clinical:
            showClinicalExamples()
        case .consumer:
            showConsumerExamples()
        }
    }
    
    private func showClinicalExamples() {
        print("🏥 Showing clinical assessment examples...")
        
        let currentExampleDisplayView = exampleDisplayView ?? programmaticExampleDisplayView!
        currentExampleDisplayView.subviews.forEach { $0.removeFromSuperview() }
        currentExampleDisplayView.backgroundColor = UIColor.darkGray
        
        // Create vertical stack for clinical components
        let mainStackView = UIStackView()
        mainStackView.translatesAutoresizingMaskIntoConstraints = false
        mainStackView.axis = .vertical
        mainStackView.distribution = .fillEqually
        mainStackView.spacing = 15
        mainStackView.alignment = .fill
        currentExampleDisplayView.addSubview(mainStackView)
        
        // Component 1: Dot Arrays
        let dotArrayComponent = createComponentView(
            title: "1. Memory Arrays",
            description: "Remember dot positions across 3 arrays",
            color: .systemBlue,
            icon: "🔴"
        )
        
        // Component 2: Distractor Phase
        let distractorComponent = createComponentView(
            title: "2. Distraction Phase",
            description: "Visual distractors during memory delay",
            color: .systemOrange,
            icon: "🎭"
        )
        
        // Component 3: Probe Response
        let probeComponent = createComponentView(
            title: "3. Memory Probe",
            description: "Was this dot in the previous arrays?",
            color: .systemGreen,
            icon: "❓"
        )
        
        mainStackView.addArrangedSubview(dotArrayComponent)
        mainStackView.addArrangedSubview(distractorComponent)
        mainStackView.addArrangedSubview(probeComponent)
        
        NSLayoutConstraint.activate([
            mainStackView.topAnchor.constraint(equalTo: currentExampleDisplayView.topAnchor, constant: 10),
            mainStackView.leadingAnchor.constraint(equalTo: currentExampleDisplayView.leadingAnchor, constant: 15),
            mainStackView.trailingAnchor.constraint(equalTo: currentExampleDisplayView.trailingAnchor, constant: -15),
            mainStackView.bottomAnchor.constraint(equalTo: currentExampleDisplayView.bottomAnchor, constant: -10)
        ])
        
        print("✅ Clinical examples displayed")
    }
    
    private func showConsumerExamples() {
        print("👤 Showing consumer pathway examples...")
        
        let currentExampleDisplayView = exampleDisplayView ?? programmaticExampleDisplayView!
        currentExampleDisplayView.subviews.forEach { $0.removeFromSuperview() }
        currentExampleDisplayView.backgroundColor = UIColor.darkGray
        
        // Create video examples layout
        let stackView = UIStackView()
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.axis = .vertical
        stackView.distribution = .fillEqually
        stackView.spacing = 20
        stackView.alignment = .fill
        currentExampleDisplayView.addSubview(stackView)
        
        // Video types examples
        let video1 = createVideoExampleView(title: "📺 Advertisement Videos", description: "Track attention during commercial content")
        let video2 = createVideoExampleView(title: "🎬 Entertainment Content", description: "Analyze focus patterns during engaging videos")
        let video3 = createVideoExampleView(title: "📊 Attention Insights", description: "Get personalized attention & focus metrics")
        
        stackView.addArrangedSubview(video1)
        stackView.addArrangedSubview(video2)
        stackView.addArrangedSubview(video3)
        
        NSLayoutConstraint.activate([
            stackView.centerXAnchor.constraint(equalTo: currentExampleDisplayView.centerXAnchor),
            stackView.centerYAnchor.constraint(equalTo: currentExampleDisplayView.centerYAnchor),
            stackView.leadingAnchor.constraint(equalTo: currentExampleDisplayView.leadingAnchor, constant: 20),
            stackView.trailingAnchor.constraint(equalTo: currentExampleDisplayView.trailingAnchor, constant: -20)
        ])
        
        print("✅ Consumer examples displayed")
    }
    
    private func createComponentView(title: String, description: String, color: UIColor, icon: String) -> UIView {
        let container = UIView()
        container.backgroundColor = color.withAlphaComponent(0.1)
        container.layer.cornerRadius = 8
        container.layer.borderWidth = 2
        container.layer.borderColor = color.cgColor
        
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = "\(icon) \(title)\n\(description)"
        label.font = .bodyMedium
        label.textColor = color
        label.textAlignment = .center
        label.numberOfLines = 0
        container.addSubview(label)
        
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            label.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 10),
            label.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -10)
        ])
        
        return container
    }
    
    private func createVideoExampleView(title: String, description: String) -> UIView {
        let container = UIView()
        container.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.1)
        container.layer.cornerRadius = 12
        container.layer.borderWidth = 2
        container.layer.borderColor = UIColor.systemBlue.cgColor
        
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = "\(title)\n\(description)"
        label.font = .bodyMedium
        label.textColor = .systemBlue
        label.textAlignment = .center
        label.numberOfLines = 0
        container.addSubview(label)
        
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            label.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 15),
            label.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -15)
        ])
        
        return container
    }
    
    @IBAction func startTaskTapped(_ sender: UIButton) {
        print("🚀 TaskInstructions: Start button tapped for \(currentPathwayType.displayName) pathway")
        
        // Start pathway-appropriate flow
        navigateToAssessment()
    }
    
    private func navigateToAssessment() {
        print("🔗 TaskInstructions: Navigating based on pathway type: \(currentPathwayType.displayName)")
        
        switch currentPathwayType {
        case .clinical:
            navigateToClinicalAssessment()
        case .consumer:
            navigateToConsumerFlow()
        }
    }
    
    private func navigateToClinicalAssessment() {
        print("🏥 TaskInstructions: Starting ADHD protocol assessment flow")
        
        // Create ADHDProtocolViewController programmatically since it's not in storyboard
        let adhdProtocolVC = ADHDProtocolViewController()
        adhdProtocolVC.title = "ADHD Assessment"
        print("✅ Created ADHDProtocolViewController programmatically")
        navigationController?.pushViewController(adhdProtocolVC, animated: true)
        print("✅ Successfully navigated to ADHDProtocolViewController")
    }
    
    private func navigateToConsumerFlow() {
        print("👤 TaskInstructions: Starting consumer video flow")
        
        // Navigate directly to first YouTube video for consumer pathway
        let youtubeVC = YouTubeVideoViewController1()
        youtubeVC.title = "Video Attention Analysis"
        navigationController?.pushViewController(youtubeVC, animated: true)
        print("✅ Successfully navigated to consumer YouTube flow")
    }
    
    private func showErrorAlert(_ message: String) {
        let alert = UIAlertController(title: "Navigation Error", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        print("📱 TaskInstructionsViewController: prepare(for segue) called with identifier: \(segue.identifier ?? "nil")")
        
        if segue.identifier == "showAssessment" {
            if segue.destination is ADHDProtocolViewController {
                print("✅ Successfully preparing segue to ADHDProtocolViewController")
                // Any setup needed for the ADHD assessment can be done here
            } else {
                print("❌ ERROR: Segue destination is not ADHDProtocolViewController! It's: \(type(of: segue.destination))")
            }
        } else {
            print("⚠️ Unknown segue identifier: \(segue.identifier ?? "nil")")
        }
    }
}
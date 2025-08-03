//
//  PathwaySelectionViewController.swift
//  PupillometryApp
//
//  Created by Claude on 26/07/25.
//

import UIKit

class PathwaySelectionViewController: UIViewController {
    
    // MARK: - UI Properties (Programmatic)
    private var titleLabel: UILabel!
    private var descriptionLabel: UILabel!
    private var clinicalButton: UIButton!
    private var consumerButton: UIButton!
    private var clinicalDescriptionLabel: UILabel!
    private var consumerDescriptionLabel: UILabel!
    private var disclaimerTextView: UITextView!
    
    // MARK: - Properties
    private let pupillometryManager = PupillometryManager.shared
    
    override func viewDidLoad() {
        super.viewDidLoad()
        createUI()
        setupUI()
        setupContent()
    }
    
    private func createUI() {
        view.backgroundColor = .black
        
        // Create UI elements
        titleLabel = UILabel()
        descriptionLabel = UILabel()
        clinicalButton = UIButton(type: .system)
        consumerButton = UIButton(type: .system)
        clinicalDescriptionLabel = UILabel()
        consumerDescriptionLabel = UILabel()
        disclaimerTextView = UITextView()
        
        // Add to view
        [titleLabel, descriptionLabel, clinicalButton, consumerButton,
         clinicalDescriptionLabel, consumerDescriptionLabel, disclaimerTextView].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview($0)
        }
        
        // Add button actions
        clinicalButton.addTarget(self, action: #selector(clinicalButtonTapped(_:)), for: .touchUpInside)
        consumerButton.addTarget(self, action: #selector(consumerButtonTapped(_:)), for: .touchUpInside)
        
        setupConstraints()
    }
    
    private func setupConstraints() {
        NSLayoutConstraint.activate([
            // Title label
            titleLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 32),
            titleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 32),
            titleLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -32),
            
            // Description label  
            descriptionLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 16),
            descriptionLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 32),
            descriptionLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -32),
            
            // Clinical button
            clinicalButton.topAnchor.constraint(equalTo: descriptionLabel.bottomAnchor, constant: 48),
            clinicalButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 32),
            clinicalButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -32),
            clinicalButton.heightAnchor.constraint(equalToConstant: 56),
            
            // Clinical description
            clinicalDescriptionLabel.topAnchor.constraint(equalTo: clinicalButton.bottomAnchor, constant: 12),
            clinicalDescriptionLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 48),
            clinicalDescriptionLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -48),
            
            // Consumer button
            consumerButton.topAnchor.constraint(equalTo: clinicalDescriptionLabel.bottomAnchor, constant: 32),
            consumerButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 32),
            consumerButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -32),
            consumerButton.heightAnchor.constraint(equalToConstant: 56),
            
            // Consumer description
            consumerDescriptionLabel.topAnchor.constraint(equalTo: consumerButton.bottomAnchor, constant: 12),
            consumerDescriptionLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 48),
            consumerDescriptionLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -48),
            
            // Disclaimer text view
            disclaimerTextView.topAnchor.constraint(equalTo: consumerDescriptionLabel.bottomAnchor, constant: 32),
            disclaimerTextView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 32),
            disclaimerTextView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -32),
            disclaimerTextView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -32)
        ])
    }
    
    private func setupUI() {
        // Configure title
        titleLabel.font = UIFont.systemFont(ofSize: 24, weight: .bold)
        titleLabel.textColor = .white
        titleLabel.textAlignment = .center
        
        // Configure description
        descriptionLabel.font = UIFont.systemFont(ofSize: 16, weight: .regular)
        descriptionLabel.textColor = .white
        descriptionLabel.textAlignment = .center
        descriptionLabel.numberOfLines = 0
        
        // Configure buttons
        setupButton(clinicalButton, title: "Clinical Assessment", color: .systemBlue)
        setupButton(consumerButton, title: "Personal Insights", color: .systemGreen)
        
        // Configure pathway descriptions
        clinicalDescriptionLabel.font = UIFont.systemFont(ofSize: 14, weight: .regular)
        clinicalDescriptionLabel.textColor = .lightGray
        clinicalDescriptionLabel.numberOfLines = 0
        
        consumerDescriptionLabel.font = UIFont.systemFont(ofSize: 14, weight: .regular)
        consumerDescriptionLabel.textColor = .lightGray
        consumerDescriptionLabel.numberOfLines = 0
        
        // Configure disclaimer
        disclaimerTextView.font = UIFont.systemFont(ofSize: 12, weight: .regular)
        disclaimerTextView.textColor = .lightGray
        disclaimerTextView.backgroundColor = .clear
        disclaimerTextView.isEditable = false
        disclaimerTextView.isScrollEnabled = true
    }
    
    private func setupButton(_ button: UIButton, title: String, color: UIColor) {
        button.setTitle(title, for: .normal)
        button.backgroundColor = color
        button.setTitleColor(.white, for: .normal)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 18, weight: .semibold)
        button.layer.cornerRadius = 12
        button.layer.shadowColor = UIColor.black.cgColor
        button.layer.shadowOffset = CGSize(width: 0, height: 2)
        button.layer.shadowOpacity = 0.1
        button.layer.shadowRadius = 4
    }
    
    private func setupContent() {
        titleLabel.text = "Choose Your Assessment Type"
        descriptionLabel.text = "Select the type of pupillometry assessment that best fits your needs."
        
        clinicalDescriptionLabel.text = """
        • ADHD diagnostic assessment (5 trials)
        • Sternberg working memory protocol
        • Advanced pupillometry analysis
        • XGBoost machine learning classification
        • Clinical-grade metrics & reporting
        """
        
        consumerDescriptionLabel.text = """
        • Quick attention insights
        • Video engagement analysis
        • Personal focus metrics
        • Easy-to-understand results
        • Shareable summaries
        """
        
        disclaimerTextView.text = """
        Clinical Assessment: Designed for research and clinical use. Results should be interpreted by qualified professionals.

        Personal Insights: For personal awareness and wellness tracking. Not intended for medical diagnosis or treatment decisions.

        All data is collected and stored securely with appropriate privacy protections based on the assessment type selected.
        """
    }
    
    // MARK: - Actions
    
    @IBAction func clinicalButtonTapped(_ sender: UIButton) {
        print("🏥 PathwaySelection: Clinical pathway selected")
        
        // Set pathway type in current session
        pupillometryManager.currentSession?.pathwayType = PathwayType.clinical
        
        // Provide haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
        
        // Navigate to clinical flow
        navigateToClinicalFlow()
    }
    
    @IBAction func consumerButtonTapped(_ sender: UIButton) {
        print("👤 PathwaySelection: Consumer pathway selected")
        
        // Set pathway type in current session  
        pupillometryManager.currentSession?.pathwayType = PathwayType.consumer
        
        // Provide haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
        
        // Navigate to consumer flow
        navigateToConsumerFlow()
    }
    
    // MARK: - Navigation
    
    private func navigateToClinicalFlow() {
        // Clinical pathway: ADHD diagnostic assessment (5 trials × 8 blocks each)
        print("🏥 PathwaySelection: Creating TaskInstructionsViewController for ADHD clinical pathway")
        let taskInstructionsVC = TaskInstructionsViewController()
        taskInstructionsVC.title = "ADHD Assessment Instructions"
        navigationController?.pushViewController(taskInstructionsVC, animated: true)
    }
    
    private func navigateToConsumerFlow() {
        // Consumer pathway: YouTube videos only for attention analysis
        print("👤 PathwaySelection: Creating YouTubeVideoViewController1 for consumer pathway")
        let youtubeVC = YouTubeVideoViewController1()
        youtubeVC.title = "Video Attention Analysis"
        navigationController?.pushViewController(youtubeVC, animated: true)
    }
}
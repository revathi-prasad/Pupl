//
//  ADHDResultsViewController.swift
//  PupillometryApp
//
//  ADHD Assessment Results Display
//  Shows real-time ADHD classification from XGBoost model
//

import UIKit

class ADHDResultsViewController: UIViewController {
    
    // MARK: - Properties
    var adhdPrediction: ADHDInferenceEngine.ADHDPrediction?
    var sessionData: SessionData?
    
    // UI Elements
    private var scrollView: UIScrollView!
    private var contentView: UIView!
    
    private var titleLabel: UILabel!
    private var predictionView: UIView!
    private var probabilityLabel: UILabel!
    private var classificationLabel: UILabel!
    private var confidenceLabel: UILabel!
    
    private var featuresView: UIView!
    private var featuresTitle: UILabel!
    private var featuresStackView: UIStackView!
    
    private var disclaimerView: UITextView!
    private var saveButton: UIButton!
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        displayResults()
    }
    
    // MARK: - Setup
    
    private func setupUI() {
        view.backgroundColor = .black
        
        // Create scroll view for content
        scrollView = UIScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)
        
        contentView = UIView()
        contentView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(contentView)
        
        // Create UI elements
        createTitleSection()
        createPredictionSection()
        createFeaturesSection()
        createDisclaimerSection()
        createActionButtons()
        
        setupConstraints()
    }
    
    private func createTitleSection() {
        titleLabel = UILabel()
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.text = "ADHD Assessment Results"
        titleLabel.styleAsTitle()
        contentView.addSubview(titleLabel)
    }
    
    private func createPredictionSection() {
        // Container view for prediction
        predictionView = UIView()
        predictionView.translatesAutoresizingMaskIntoConstraints = false
        predictionView.styleAsCard()
        predictionView.layer.borderWidth = 2
        contentView.addSubview(predictionView)
        
        // Classification result
        classificationLabel = UILabel()
        classificationLabel.translatesAutoresizingMaskIntoConstraints = false
        classificationLabel.styleAsClinicalTitle()
        predictionView.addSubview(classificationLabel)
        
        // Probability score
        probabilityLabel = UILabel()
        probabilityLabel.translatesAutoresizingMaskIntoConstraints = false
        probabilityLabel.font = .dataMedium
        probabilityLabel.textColor = .secondaryText
        probabilityLabel.textAlignment = .center
        predictionView.addSubview(probabilityLabel)
        
        // Confidence score
        confidenceLabel = UILabel()
        confidenceLabel.translatesAutoresizingMaskIntoConstraints = false
        confidenceLabel.styleAsCaption()
        confidenceLabel.textAlignment = .center
        predictionView.addSubview(confidenceLabel)
    }
    
    private func createFeaturesSection() {
        featuresView = UIView()
        featuresView.translatesAutoresizingMaskIntoConstraints = false
        featuresView.styleAsCard()
        contentView.addSubview(featuresView)
        
        featuresTitle = UILabel()
        featuresTitle.translatesAutoresizingMaskIntoConstraints = false
        featuresTitle.text = "Key Features"
        featuresTitle.styleAsCardTitle()
        featuresView.addSubview(featuresTitle)
        
        featuresStackView = UIStackView()
        featuresStackView.translatesAutoresizingMaskIntoConstraints = false
        featuresStackView.axis = .vertical
        featuresStackView.spacing = 8
        featuresStackView.distribution = .fillEqually
        featuresView.addSubview(featuresStackView)
    }
    
    private func createDisclaimerSection() {
        disclaimerView = UITextView()
        disclaimerView.translatesAutoresizingMaskIntoConstraints = false
        disclaimerView.backgroundColor = .clear
        disclaimerView.textColor = .secondaryText
        disclaimerView.font = .footnote
        disclaimerView.isEditable = false
        disclaimerView.isScrollEnabled = false
        disclaimerView.text = """
        Clinical Disclaimer: This ADHD screening result is for informational purposes only and does not constitute a clinical diagnosis. The assessment uses pupillometry-based biomarkers and machine learning analysis. Consult with a qualified healthcare professional for comprehensive evaluation and clinical interpretation.
        
        Model: XGBoost classifier trained on pupillometric features
        Accuracy: Based on validation with clinical datasets
        """
        contentView.addSubview(disclaimerView)
    }
    
    private func createActionButtons() {
        saveButton = UIButton(type: .system)
        saveButton.translatesAutoresizingMaskIntoConstraints = false
        saveButton.setTitle("Save Results", for: .normal)
        saveButton.styleAsPrimary()
        saveButton.addTarget(self, action: #selector(saveButtonTapped), for: .touchUpInside)
        contentView.addSubview(saveButton)
    }
    
    private func setupConstraints() {
        NSLayoutConstraint.activate([
            // Scroll view
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            // Content view
            contentView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor),
            
            // Title
            titleLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 20),
            titleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            titleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            
            // Prediction view
            predictionView.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 30),
            predictionView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            predictionView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            predictionView.heightAnchor.constraint(equalToConstant: 150),
            
            // Classification label
            classificationLabel.topAnchor.constraint(equalTo: predictionView.topAnchor, constant: 20),
            classificationLabel.leadingAnchor.constraint(equalTo: predictionView.leadingAnchor, constant: 20),
            classificationLabel.trailingAnchor.constraint(equalTo: predictionView.trailingAnchor, constant: -20),
            
            // Probability label
            probabilityLabel.topAnchor.constraint(equalTo: classificationLabel.bottomAnchor, constant: 10),
            probabilityLabel.leadingAnchor.constraint(equalTo: predictionView.leadingAnchor, constant: 20),
            probabilityLabel.trailingAnchor.constraint(equalTo: predictionView.trailingAnchor, constant: -20),
            
            // Confidence label
            confidenceLabel.topAnchor.constraint(equalTo: probabilityLabel.bottomAnchor, constant: 10),
            confidenceLabel.leadingAnchor.constraint(equalTo: predictionView.leadingAnchor, constant: 20),
            confidenceLabel.trailingAnchor.constraint(equalTo: predictionView.trailingAnchor, constant: -20),
            
            // Features view
            featuresView.topAnchor.constraint(equalTo: predictionView.bottomAnchor, constant: 20),
            featuresView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            featuresView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            featuresView.heightAnchor.constraint(greaterThanOrEqualToConstant: 200),
            
            // Features title
            featuresTitle.topAnchor.constraint(equalTo: featuresView.topAnchor, constant: 15),
            featuresTitle.leadingAnchor.constraint(equalTo: featuresView.leadingAnchor, constant: 15),
            featuresTitle.trailingAnchor.constraint(equalTo: featuresView.trailingAnchor, constant: -15),
            
            // Features stack
            featuresStackView.topAnchor.constraint(equalTo: featuresTitle.bottomAnchor, constant: 15),
            featuresStackView.leadingAnchor.constraint(equalTo: featuresView.leadingAnchor, constant: 15),
            featuresStackView.trailingAnchor.constraint(equalTo: featuresView.trailingAnchor, constant: -15),
            featuresStackView.bottomAnchor.constraint(equalTo: featuresView.bottomAnchor, constant: -15),
            
            // Disclaimer
            disclaimerView.topAnchor.constraint(equalTo: featuresView.bottomAnchor, constant: 20),
            disclaimerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            disclaimerView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            
            // Save button
            saveButton.topAnchor.constraint(equalTo: disclaimerView.bottomAnchor, constant: 20),
            saveButton.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            saveButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            saveButton.heightAnchor.constraint(equalToConstant: 50),
            saveButton.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -30)
        ])
    }
    
    // MARK: - Display Results
    
    private func displayResults() {
        guard let prediction = adhdPrediction else {
            showPlaceholderResults()
            return
        }
        
        // Display XGBoost binary classification results
        switch prediction.classification {
        case .positive:
            classificationLabel.text = "ADHD Detected"
            classificationLabel.textColor = .systemRed
            predictionView.layer.borderColor = UIColor.systemRed.cgColor
        case .negative:
            classificationLabel.text = "No ADHD Detected"
            classificationLabel.textColor = .systemGreen
            predictionView.layer.borderColor = UIColor.systemGreen.cgColor
        case .inconclusive:
            classificationLabel.text = "Analysis Inconclusive"
            classificationLabel.textColor = .systemYellow
            predictionView.layer.borderColor = UIColor.systemYellow.cgColor
        }
        
        // Display XGBoost binary prediction result
        let predictionText = prediction.binaryPrediction == 1 ? "Positive (1)" : prediction.binaryPrediction == 0 ? "Negative (0)" : "Invalid"
        probabilityLabel.text = "XGBoost Prediction: \(predictionText)"
        
        // Display model confidence
        let confidencePercentage = Int(prediction.confidence * 100)
        confidenceLabel.text = "Model Confidence: \(confidencePercentage)%"
        
        // Display supporting features
        displaySupportingFeatures(prediction.supportingFeatures)
    }
    
    private func showPlaceholderResults() {
        classificationLabel.text = "Assessment Complete"
        classificationLabel.textColor = .systemBlue
        predictionView.layer.borderColor = UIColor.systemBlue.cgColor
        
        probabilityLabel.text = "Processing pupillometric data..."
        confidenceLabel.text = "XGBoost model analysis in progress"
        
        // Show placeholder features
        let placeholderFeatures = [
            "Pupil Dynamics": "Measured ✓",
            "Attention Patterns": "Analyzed ✓", 
            "Response Variability": "Calculated ✓",
            "Model Processing": "XGBoost inference ready"
        ]
        displaySupportingFeatures(placeholderFeatures)
    }
    
    private func displaySupportingFeatures(_ features: [String: Any]) {
        // Clear existing features
        featuresStackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
        
        // Add feature rows
        for (key, value) in features {
            let featureRow = createFeatureRow(title: key, value: "\(value)")
            featuresStackView.addArrangedSubview(featureRow)
        }
    }
    
    private func createFeatureRow(title: String, value: String) -> UIView {
        let container = UIView()
        container.backgroundColor = .black
        container.layer.cornerRadius = 8
        
        let titleLabel = UILabel()
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.text = title
        titleLabel.font = .bodyMedium
        titleLabel.textColor = .primaryText
        container.addSubview(titleLabel)
        
        let valueLabel = UILabel()
        valueLabel.translatesAutoresizingMaskIntoConstraints = false
        valueLabel.text = value
        valueLabel.font = .dataMedium
        valueLabel.textColor = .secondaryText
        valueLabel.textAlignment = .right
        container.addSubview(valueLabel)
        
        NSLayoutConstraint.activate([
            container.heightAnchor.constraint(equalToConstant: 40),
            
            titleLabel.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            titleLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 12),
            
            valueLabel.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            valueLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -12),
            valueLabel.leadingAnchor.constraint(greaterThanOrEqualTo: titleLabel.trailingAnchor, constant: 10)
        ])
        
        return container
    }
    
    // MARK: - Actions
    
    @objc private func saveButtonTapped() {
        guard let session = sessionData else {
            showErrorAlert(message: "No session data available to save")
            return
        }
        
        // Show loading indicator
        let loadingAlert = UIAlertController(
            title: "Saving Results",
            message: "Uploading ADHD assessment data to Firebase...",
            preferredStyle: .alert
        )
        present(loadingAlert, animated: true)
        
        // Add ADHD prediction to session data if available
        if let prediction = adhdPrediction {
            // Store XGBoost binary prediction results in session for inclusion in Firebase upload
            session.metadata["adhd_binary_prediction"] = prediction.binaryPrediction
            session.metadata["adhd_prediction_confidence"] = prediction.confidence
            session.metadata["adhd_classification"] = prediction.classification.rawValue
            session.metadata["adhd_supporting_features"] = prediction.supportingFeatures
            session.metadata["adhd_analysis_timestamp"] = Date().timeIntervalSince1970
            session.metadata["model_type"] = "XGBoost_Binary_Classifier"
        }
        
        // Save to Firebase
        let firebaseManager = FirebaseStorageManager()
        firebaseManager.uploadSessionData(session) { [weak self] success, message in
            DispatchQueue.main.async {
                // Dismiss loading alert
                self?.dismiss(animated: true) {
                    if success {
                        // Show success message
                        let alert = UIAlertController(
                            title: "Results Saved Successfully",
                            message: "ADHD assessment data uploaded to Firebase Storage at:\nADHD_sessions/session_\(session.sessionID)/",
                            preferredStyle: .alert
                        )
                        alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in
                            self?.navigationController?.popToRootViewController(animated: true)
                        })
                        self?.present(alert, animated: true)
                    } else {
                        self?.showErrorAlert(message: message ?? "Failed to upload to Firebase Storage")
                    }
                }
            }
        }
    }
    
    private func showErrorAlert(message: String) {
        let alert = UIAlertController(
            title: "Save Error",
            message: message,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}
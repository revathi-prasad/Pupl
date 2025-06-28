//
//  ResultsViewController.swift
//  PupillometryApp
//
//  Created by Revathi Prasad on 09/06/25.
//

//import UIKit
//
//class ResultsViewController: UIViewController {
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

//
//  ResultsViewController.swift
//  PupillometryApp
//
//  Created by Revathi Prasad on 09/06/25.
//

import UIKit
//import Charts

class ResultsViewController: UIViewController {
    
    // MARK: - IBOutlets for Performance Summary Labels
    @IBOutlet weak var sustainedAttentionLabel: UITextField!
    @IBOutlet weak var workingMemoryLabel: UITextField!
    @IBOutlet weak var responseVariabilityLabel: UITextField!
    @IBOutlet weak var commissionErrorsLabel: UITextField!
    
    // MARK: - Other IBOutlets
//    @IBOutlet weak var performanceTable: UITableView!
    @IBOutlet weak var disclaimerLabel: UITextView!
    @IBOutlet weak var saveResultsButton: UIButton!
    @IBOutlet weak var newAssessmentButton: UIButton!
    @IBOutlet weak var resultsSavedLabel: UILabel!
    
    private let pupillometryManager = PupillometryManager.shared
    private let cloudStorageManager = FirebaseStorageManager()
    private var features: ADHDFeatures?
    private var resultsSaved = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        loadResults()
        updatePerformanceLabels()
    }
    
    private func setupUI() {
        // Configure table (if still needed)
//        performanceTable?.dataSource = self
//        performanceTable?.delegate = self
//        performanceTable?.layer.cornerRadius = 10
//        performanceTable?.layer.borderWidth = 1
//        performanceTable?.layer.borderColor = UIColor.lightGray.cgColor
        
        // Configure disclaimer
        disclaimerLabel.text = "Clinical Disclaimer: These results are for screening purposes only and do not constitute a clinical diagnosis. Consult with a qualified healthcare professional for comprehensive evaluation."
        disclaimerLabel.isEditable = false
        disclaimerLabel.isScrollEnabled = false
        disclaimerLabel.backgroundColor = UIColor.clear
        disclaimerLabel.textColor = UIColor.systemGray
        disclaimerLabel.font = UIFont.systemFont(ofSize: 12)
        
        // Configure save button
        saveResultsButton.layer.cornerRadius = 8.0
        saveResultsButton.backgroundColor = UIColor.systemBlue
        saveResultsButton.setTitleColor(.white, for: .normal)
    }
    
    private func loadResults() {
        // Get features from the session
        features = pupillometryManager.extractSessionFeatures()
    }
    
    private func updatePerformanceLabels() {
        // Update the 4 performance metric labels
        sustainedAttentionLabel?.text = getAttentionRating()
        workingMemoryLabel?.text = getMemoryRating()
        responseVariabilityLabel?.text = getVariabilityRating()
        commissionErrorsLabel?.text = getErrorRating()
        
        // Apply styling to labels
        stylePerformanceLabels()
    }
    
    private func stylePerformanceLabels() {
        let labels = [sustainedAttentionLabel, workingMemoryLabel, responseVariabilityLabel, commissionErrorsLabel]
        
        for label in labels {
            label?.textAlignment = .right
            label?.font = UIFont.systemFont(ofSize: 14, weight: .medium)
            
            // Color code based on content
            if let text = label?.text {
                switch text.lowercased() {
                case "elevated risk", "high", "above average":
                    label?.textColor = UIColor.systemRed
                case "borderline", "moderate", "normal range":
                    label?.textColor = UIColor.systemOrange
                case "below average", "low":
                    label?.textColor = UIColor.systemGreen
                default:
                    label?.textColor = UIColor.label
                }
            }
        }
    }
    
    @IBAction func saveResultsTapped(_ sender: UIButton) {
        if resultsSaved {
            // Show new assessment options
            let alert = UIAlertController(
                title: "Results Saved",
                message: "Would you like to start a new assessment?",
                preferredStyle: .alert
            )
            
            alert.addAction(UIAlertAction(title: "New Assessment", style: .default) { [weak self] _ in
                self?.navigationController?.popToRootViewController(animated: true)
            })
            
            alert.addAction(UIAlertAction(title: "Close", style: .cancel))
            
            present(alert, animated: true)
        } else {
            // Save results to cloud
            saveResultsToCloud()
        }
    }
    
    @IBAction func newAssessmentTapped(_ sender: UIButton) {
        // Navigate back to welcome screen to start new assessment
        navigationController?.popToRootViewController(animated: true)
    }
    
//    private func saveResultsToCloud() {
//        // Show loading indicator
//        let loadingAlert = UIAlertController(
//            title: "Saving Results",
//            message: "Please wait while we upload your results...",
//            preferredStyle: .alert
//        )
//        
//        let loadingIndicator = UIActivityIndicatorView(frame: CGRect(x: 10, y: 5, width: 50, height: 50))
//        loadingIndicator.hidesWhenStopped = true
//        loadingIndicator.startAnimating()
//        loadingAlert.view.addSubview(loadingIndicator)
//        
//        present(loadingAlert, animated: true)
//        
//        // Check if authorized
//        if cloudStorageManager.isAuthorized {
//            uploadSession()
//        } else {
//            // Dismiss loading alert
//            dismiss(animated: true) {
//                // Sign in to Google Drive
//                self.cloudStorageManager.signIn(from: self) { [weak self] success in
//                    if success {
//                        self?.uploadSession()
//                    } else {
//                        self?.showErrorAlert(message: "Could not authenticate with Google Drive")
//                    }
//                }
//            }
//        }
//    }
    
    private func saveResultsToCloud() {
        guard let session = pupillometryManager.currentSession else {
            showErrorAlert(message: "No session data available")
            return
        }
        
        cloudStorageManager.uploadSessionData(session) { [weak self] success, message in
            // Handle result
        }
    }
    
    private func uploadSession() {
        guard let session = pupillometryManager.currentSession else {
            showErrorAlert(message: "No session data available")
            return
        }
        
        cloudStorageManager.uploadSessionData(session) { [weak self] success, message in
            DispatchQueue.main.async {
                // Dismiss loading alert
                self?.dismiss(animated: true) {
                    if success {
                        // Update UI
                        self?.resultsSaved = true
                        self?.saveResultsButton.setTitle("New Assessment", for: .normal)
                        
                        // Show success message
                        let alert = UIAlertController(
                            title: "Results Saved",
                            message: "Your assessment data has been successfully saved to Google Drive.",
                            preferredStyle: .alert
                        )
                        alert.addAction(UIAlertAction(title: "OK", style: .default))
                        self?.present(alert, animated: true)
                    } else {
                        self?.showErrorAlert(message: message ?? "Failed to save results")
                    }
                }
            }
        }
    }
    
    private func showErrorAlert(message: String) {
        let alert = UIAlertController(
            title: "Error",
            message: message,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
    
    // MARK: - Rating Calculation Methods
    
    private func getAttentionRating() -> String {
        guard let features = features else { return "Not Available" }
        
        // Based on maxPhasicAttention threshold values
        if features.maxPhasicAttention < 0.05 {
            return "Elevated Risk"
        } else if features.maxPhasicAttention < 0.1 {
            return "Borderline"
        } else {
            return "Normal Range"
        }
    }
    
    private func getMemoryRating() -> String {
        guard let features = features else { return "Not Available" }
        
        // Based on accuracy thresholds
        if features.accuracy < 0.7 {
            return "Below Average"
        } else if features.accuracy < 0.85 {
            return "Normal Range"
        } else {
            return "Above Average"
        }
    }
    
    private func getVariabilityRating() -> String {
        guard let features = features else { return "Not Available" }
        
        // Based on baseline stability (higher stability = lower variability)
        if features.baselineStability > 0.3 {
            return "High"
        } else if features.baselineStability > 0.15 {
            return "Moderate"
        } else {
            return "Low"
        }
    }
    
    private func getErrorRating() -> String {
        guard let features = features else { return "Not Available" }
        
        // Commission errors are the inverse of accuracy
        let errorRate = 1.0 - features.accuracy
        
        if errorRate > 0.25 {
            return "Above Average"
        } else if errorRate > 0.15 {
            return "Normal Range"
        } else {
            return "Below Average"
        }
    }
}

// MARK: - UITableViewDataSource, UITableViewDelegate (if table view is still needed)

extension ResultsViewController: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 4
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .value1, reuseIdentifier: "resultCell")
        
        switch indexPath.row {
        case 0:
            cell.textLabel?.text = "Sustained Attention"
            cell.detailTextLabel?.text = getAttentionRating()
        case 1:
            cell.textLabel?.text = "Working Memory Capacity"
            cell.detailTextLabel?.text = getMemoryRating()
        case 2:
            cell.textLabel?.text = "Response Variability"
            cell.detailTextLabel?.text = getVariabilityRating()
        case 3:
            cell.textLabel?.text = "Commission Errors"
            cell.detailTextLabel?.text = getErrorRating()
        default:
            break
        }
        
        return cell
    }
}

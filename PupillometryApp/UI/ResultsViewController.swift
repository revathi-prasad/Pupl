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
    @IBOutlet weak var sustainedAttentionLabel: UITextField?
    @IBOutlet weak var workingMemoryLabel: UITextField?
    @IBOutlet weak var responseVariabilityLabel: UITextField?
    @IBOutlet weak var commissionErrorsLabel: UITextField?
    
    // MARK: - Other IBOutlets
//    @IBOutlet weak var performanceTable: UITableView!
    @IBOutlet weak var disclaimerLabel: UITextView?
    @IBOutlet weak var saveResultsButton: UIButton?
    @IBOutlet weak var newAssessmentButton: UIButton?
    @IBOutlet weak var resultsSavedLabel: UILabel?
    
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
        
        // Configure disclaimer based on pathway
        let pathwayType = pupillometryManager.currentSession?.pathwayType ?? .consumer
        switch pathwayType {
        case .clinical:
            disclaimerLabel?.text = "Clinical Disclaimer: These ADHD screening results are for informational purposes only and do not constitute a clinical diagnosis. Consult with a qualified healthcare professional for comprehensive evaluation."
        case .consumer:
            disclaimerLabel?.text = "Information Disclaimer: These attention metrics are for personal insights only. Results are not diagnostic and should not be used for medical purposes."
        }
        disclaimerLabel?.isEditable = false
        disclaimerLabel?.isScrollEnabled = false
        disclaimerLabel?.backgroundColor = UIColor.clear
        disclaimerLabel?.textColor = UIColor.lightGray
        disclaimerLabel?.font = UIFont.systemFont(ofSize: 12)
        
        // Configure save button
        saveResultsButton?.layer.cornerRadius = 8.0
        saveResultsButton?.backgroundColor = UIColor.systemBlue
        saveResultsButton?.setTitleColor(.white, for: .normal)
    }
    
    private func loadResults() {
        // Get features from the session
        features = pupillometryManager.extractSessionFeatures()
    }
    
    private func updatePerformanceLabels() {
        guard let session = pupillometryManager.currentSession else {
            // Show "Not Available" for all metrics if no session
            sustainedAttentionLabel?.text = "Not Available"
            workingMemoryLabel?.text = "Not Available"
            responseVariabilityLabel?.text = "Not Available"
            commissionErrorsLabel?.text = "Not Available"
            stylePerformanceLabels()
            return
        }
        
        // Check pathway type to determine which metrics to show
        switch session.pathwayType {
        case .clinical:
            // Clinical pathway: ADHD Protocol metrics
            if !session.adhdProtocolResponses.isEmpty {
                sustainedAttentionLabel?.text = getADHDAttentionRating(session: session)
                workingMemoryLabel?.text = getADHDMemoryRating(session: session)
                responseVariabilityLabel?.text = getADHDVariabilityRating(session: session)
                commissionErrorsLabel?.text = getADHDErrorRating(session: session)
            } else {
                // Fallback to legacy GradCPT metrics if ADHD data not available
                sustainedAttentionLabel?.text = getAttentionRating()
                workingMemoryLabel?.text = getMemoryRating()
                responseVariabilityLabel?.text = getVariabilityRating()
                commissionErrorsLabel?.text = getErrorRating()
            }
            
        case .consumer:
            // Consumer pathway: Show engagement metrics from YouTube videos
            sustainedAttentionLabel?.text = getVideoEngagementRating(session: session)
            workingMemoryLabel?.text = "Not Applicable"
            responseVariabilityLabel?.text = getVideoFocusStability(session: session)
            commissionErrorsLabel?.text = "Not Applicable"
        }
        
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
                case "not applicable":
                    label?.textColor = UIColor.lightGray
                    label?.isEnabled = false
                case "elevated risk", "high", "above average", "variable focus":
                    label?.textColor = UIColor.systemRed
                    label?.isEnabled = true
                case "borderline", "moderate", "normal range", "moderate engagement", "moderate focus":
                    label?.textColor = UIColor.systemOrange
                    label?.isEnabled = true
                case "below average", "low", "low engagement", "stable focus":
                    label?.textColor = UIColor.systemGreen
                    label?.isEnabled = true
                case "high engagement":
                    label?.textColor = UIColor.systemBlue
                    label?.isEnabled = true
                default:
                    label?.textColor = UIColor.label
                    label?.isEnabled = true
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
        
        // Show loading indicator
        let loadingAlert = UIAlertController(
            title: "Saving Results",
            message: "Uploading data to Firebase Storage...",
            preferredStyle: .alert
        )
        
        let loadingIndicator = UIActivityIndicatorView(style: .medium)
        loadingIndicator.startAnimating()
        loadingAlert.view.addSubview(loadingIndicator)
        loadingIndicator.center = CGPoint(x: loadingAlert.view.bounds.midX, y: loadingAlert.view.bounds.midY + 50)
        
        present(loadingAlert, animated: true)
        
        cloudStorageManager.uploadSessionData(session) { [weak self] success, message in
            DispatchQueue.main.async {
                // Dismiss loading alert
                self?.dismiss(animated: true) {
                    if success {
                        // Update UI
                        self?.resultsSaved = true
                        self?.saveResultsButton?.setTitle("Results Saved ✓", for: .normal)
                        self?.saveResultsButton?.backgroundColor = UIColor.systemGreen
                        self?.resultsSavedLabel?.text = "✓ Results saved to Firebase Storage"
                        self?.resultsSavedLabel?.textColor = UIColor.systemGreen
                        self?.resultsSavedLabel?.isHidden = false
                        
                        // Show success message with storage path
                        let alert = UIAlertController(
                            title: "Results Saved Successfully",
                            message: "Session data uploaded to Firebase Storage at:\npupillometry_data/session_\(session.sessionID)/",
                            preferredStyle: .alert
                        )
                        alert.addAction(UIAlertAction(title: "OK", style: .default))
                        self?.present(alert, animated: true)
                    } else {
                        self?.showErrorAlert(message: message ?? "Failed to upload to Firebase Storage")
                    }
                }
            }
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
                        self?.saveResultsButton?.setTitle("New Assessment", for: .normal)
                        
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
    
    // MARK: - ADHD Protocol Rating Methods
    
    private func getADHDAttentionRating(session: SessionData) -> String {
        let responses = session.adhdProtocolResponses
        guard !responses.isEmpty else { return "Not Available" }
        
        // Calculate mean reaction time for sustained attention
        let reactionTimes = responses.compactMap { $0.reactionTime }
        guard !reactionTimes.isEmpty else { return "Not Available" }
        
        let meanRT = reactionTimes.reduce(0, +) / Double(reactionTimes.count)
        
        // ADHD research thresholds (in seconds)
        if meanRT > 1.5 {
            return "Elevated Risk"  // Slow responses may indicate attention issues
        } else if meanRT > 1.0 {
            return "Borderline"
        } else {
            return "Normal Range"
        }
    }
    
    private func getADHDMemoryRating(session: SessionData) -> String {
        let responses = session.adhdProtocolResponses
        guard !responses.isEmpty else { return "Not Available" }
        
        // Calculate working memory performance by load condition
        let highLoadResponses = responses.filter { $0.loadCondition == .high }
        let lowLoadResponses = responses.filter { $0.loadCondition == .low }
        
        let highLoadAccuracy = highLoadResponses.isEmpty ? 0.0 : 
            Double(highLoadResponses.filter { $0.isCorrect }.count) / Double(highLoadResponses.count)
        let lowLoadAccuracy = lowLoadResponses.isEmpty ? 0.0 :
            Double(lowLoadResponses.filter { $0.isCorrect }.count) / Double(lowLoadResponses.count)
        
        // Working memory capacity estimate (difference between conditions)
        let memoryCapacity = lowLoadAccuracy - highLoadAccuracy
        
        if memoryCapacity < 0.1 {
            return "Below Average"  // Small difference indicates poor working memory
        } else if memoryCapacity < 0.2 {
            return "Normal Range"
        } else {
            return "Above Average"
        }
    }
    
    private func getADHDVariabilityRating(session: SessionData) -> String {
        let responses = session.adhdProtocolResponses
        guard responses.count > 1 else { return "Not Available" }
        
        let reactionTimes = responses.compactMap { $0.reactionTime }
        guard reactionTimes.count > 1 else { return "Not Available" }
        
        // Calculate standard deviation of reaction times
        let mean = reactionTimes.reduce(0, +) / Double(reactionTimes.count)
        let variance = reactionTimes.reduce(0) { $0 + pow($1 - mean, 2) } / Double(reactionTimes.count - 1)
        let standardDeviation = sqrt(variance)
        
        // ADHD research: Higher variability indicates attention issues
        if standardDeviation > 0.4 {
            return "Elevated Risk"  // High variability
        } else if standardDeviation > 0.25 {
            return "Borderline"
        } else {
            return "Normal Range"
        }
    }
    
    private func getADHDErrorRating(session: SessionData) -> String {
        let responses = session.adhdProtocolResponses
        guard !responses.isEmpty else { return "Not Available" }
        
        // Calculate commission errors (false positives) and omission errors
        let commissionErrors = responses.filter { !$0.isTarget && $0.userResponse }.count
        let omissionErrors = responses.filter { $0.isTarget && !$0.userResponse }.count
        let totalErrors = commissionErrors + omissionErrors
        
        let errorRate = Double(totalErrors) / Double(responses.count)
        
        if errorRate > 0.3 {
            return "Elevated Risk"
        } else if errorRate > 0.2 {
            return "Borderline"
        } else {
            return "Normal Range"
        }
    }
    
    // MARK: - Consumer Pathway (YouTube) Rating Methods
    
    private func getVideoEngagementRating(session: SessionData) -> String {
        // Analyze pupil data during YouTube videos for engagement
        let videoMeasurements = session.pupilMeasurements.filter { measurement in
            [.youtubeVideo1, .youtubeVideo2, .youtubeVideo3, .youtubeVideo4].contains(measurement.contentType)
        }
        
        guard !videoMeasurements.isEmpty else { return "Not Available" }
        
        // Calculate mean pupil diameter during videos
        let meanDiameter = videoMeasurements.reduce(0) { $0 + $1.diameterMM } / Float(videoMeasurements.count)
        
        // Engagement thresholds (larger pupils typically indicate higher engagement)
        if meanDiameter > 4.5 {
            return "High Engagement"
        } else if meanDiameter > 4.0 {
            return "Moderate Engagement"
        } else {
            return "Low Engagement"
        }
    }
    
    private func getVideoFocusStability(session: SessionData) -> String {
        // Analyze pupil variability during videos for focus stability
        let videoMeasurements = session.pupilMeasurements.filter { measurement in
            [.youtubeVideo1, .youtubeVideo2, .youtubeVideo3, .youtubeVideo4].contains(measurement.contentType)
        }
        
        guard videoMeasurements.count > 1 else { return "Not Available" }
        
        let diameters = videoMeasurements.map { $0.diameterMM }
        let mean = diameters.reduce(0, +) / Float(diameters.count)
        let variance = diameters.reduce(0) { $0 + pow($1 - mean, 2) } / Float(diameters.count - 1)
        let standardDeviation = sqrt(variance)
        
        // Focus stability (lower variability = better focus)
        if standardDeviation < 0.3 {
            return "Stable Focus"
        } else if standardDeviation < 0.5 {
            return "Moderate Focus"
        } else {
            return "Variable Focus"
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

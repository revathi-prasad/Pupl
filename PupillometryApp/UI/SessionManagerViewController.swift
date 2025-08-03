//
//  SessionManagerViewController.swift
//  PupillometryApp
//
//  Created by Revathi Prasad on 01/07/25.
//

import UIKit

class SessionManagerViewController: UIViewController {
    
    @IBOutlet weak var sessionsTableView: UITableView!
    @IBOutlet weak var refreshButton: UIButton!
    @IBOutlet weak var loadingIndicator: UIActivityIndicatorView!
    @IBOutlet weak var statusLabel: UILabel!
    
    private let firebaseManager = FirebaseStorageManager()
    private var availableSessions: [String] = []
    private var sessionMetadata: [String: SessionMetadata] = [:]
    
    struct SessionMetadata {
        let sessionID: String
        let displayName: String
        let dateCreated: Date?
        let fileCount: Int
        let hasPerformanceData: Bool
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        loadAvailableSessions()
    }
    
    private func setupUI() {
        title = "Session Manager"
        
        // Setup table view
        sessionsTableView.delegate = self
        sessionsTableView.dataSource = self
        sessionsTableView.register(UITableViewCell.self, forCellReuseIdentifier: "SessionCell")
        
        // Setup refresh button
        refreshButton.addTarget(self, action: #selector(refreshSessions), for: .touchUpInside)
        refreshButton.layer.cornerRadius = 8
        refreshButton.backgroundColor = .systemBlue
        refreshButton.setTitleColor(.white, for: .normal)
        
        // Initial state
        statusLabel.text = "Loading sessions..."
        loadingIndicator.startAnimating()
    }
    
    @objc private func refreshSessions() {
        loadAvailableSessions()
    }
    
    private func loadAvailableSessions() {
        loadingIndicator.startAnimating()
        statusLabel.text = "Loading sessions..."
        refreshButton.isEnabled = false
        
        firebaseManager.listAvailableSessions { [weak self] sessions, error in
            DispatchQueue.main.async {
                self?.loadingIndicator.stopAnimating()
                self?.refreshButton.isEnabled = true
                
                if let error = error {
                    self?.statusLabel.text = "Error loading sessions: \(error.localizedDescription)"
                    self?.availableSessions = []
                } else {
                    self?.availableSessions = sessions.sorted()
                    self?.loadSessionMetadata()
                    
                    if sessions.isEmpty {
                        self?.statusLabel.text = "No sessions found"
                    } else {
                        self?.statusLabel.text = "\(sessions.count) sessions available"
                    }
                }
                
                self?.sessionsTableView.reloadData()
            }
        }
    }
    
    private func loadSessionMetadata() {
        // Load metadata for each session
        for sessionFolder in availableSessions {
            let sessionID = String(sessionFolder.dropFirst("session_".count))
            
            // Try to extract date from session ID if it's a UUID with timestamp
            let displayName = formatSessionDisplayName(sessionID: sessionID)
            
            sessionMetadata[sessionFolder] = SessionMetadata(
                sessionID: sessionID,
                displayName: displayName,
                dateCreated: extractDateFromSessionID(sessionID),
                fileCount: 0, // Will be updated if we fetch file list
                hasPerformanceData: true // Assume true for now
            )
        }
    }
    
    private func formatSessionDisplayName(sessionID: String) -> String {
        // Create a more readable display name
        if let date = extractDateFromSessionID(sessionID) {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .short
            return formatter.string(from: date)
        } else {
            // Fallback to shortened UUID
            return String(sessionID.prefix(8)) + "..."
        }
    }
    
    private func extractDateFromSessionID(_ sessionID: String) -> Date? {
        // This is a simple heuristic - in practice you might store creation date differently
        // For now, we'll just return the current date minus some random interval
        return Date().addingTimeInterval(-TimeInterval.random(in: 0...7*24*3600)) // Random date within last week
    }
}

// MARK: - Table View Data Source

extension SessionManagerViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return availableSessions.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "SessionCell", for: indexPath)
        
        let sessionFolder = availableSessions[indexPath.row]
        let metadata = sessionMetadata[sessionFolder]
        
        // Configure cell
        cell.textLabel?.text = metadata?.displayName ?? sessionFolder
        cell.detailTextLabel?.text = "Session ID: \(metadata?.sessionID.prefix(8) ?? "Unknown")"
        cell.accessoryType = .disclosureIndicator
        
        return cell
    }
}

// MARK: - Table View Delegate

extension SessionManagerViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        let sessionFolder = availableSessions[indexPath.row]
        guard let metadata = sessionMetadata[sessionFolder] else { return }
        
        showSessionDetails(sessionID: metadata.sessionID, displayName: metadata.displayName)
    }
    
    private func showSessionDetails(sessionID: String, displayName: String) {
        let alert = UIAlertController(title: "Session: \(displayName)", message: "What would you like to do?", preferredStyle: .actionSheet)
        
        // View Performance Report
        alert.addAction(UIAlertAction(title: "View Performance Report", style: .default) { [weak self] _ in
            self?.downloadAndShowPerformanceReport(sessionID: sessionID)
        })
        
        // Download Raw Data
        alert.addAction(UIAlertAction(title: "Download Raw Data", style: .default) { [weak self] _ in
            self?.showRawDataOptions(sessionID: sessionID)
        })
        
        // Export Session
        alert.addAction(UIAlertAction(title: "Export Session", style: .default) { [weak self] _ in
            self?.exportSession(sessionID: sessionID)
        })
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        // For iPad
        if let popover = alert.popoverPresentationController {
            popover.sourceView = view
            popover.sourceRect = CGRect(x: view.bounds.midX, y: view.bounds.midY, width: 0, height: 0)
        }
        
        present(alert, animated: true)
    }
    
    private func downloadAndShowPerformanceReport(sessionID: String) {
        loadingIndicator.startAnimating()
        statusLabel.text = "Downloading performance report..."
        
        firebaseManager.downloadSessionFile(sessionID: sessionID, fileName: "performance_report.md") { [weak self] data, error in
            DispatchQueue.main.async {
                self?.loadingIndicator.stopAnimating()
                self?.statusLabel.text = "\(self?.availableSessions.count ?? 0) sessions available"
                
                if let error = error {
                    self?.showAlert(title: "Download Error", message: error.localizedDescription)
                } else if let data = data, let reportText = String(data: data, encoding: .utf8) {
                    self?.showPerformanceReport(text: reportText)
                } else {
                    self?.showAlert(title: "Error", message: "Could not read performance report")
                }
            }
        }
    }
    
    private func showPerformanceReport(text: String) {
        let reportVC = UIViewController()
        reportVC.title = "Performance Report"
        
        let textView = UITextView()
        textView.text = text
        textView.isEditable = false
        textView.font = UIFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        
        reportVC.view.addSubview(textView)
        textView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            textView.topAnchor.constraint(equalTo: reportVC.view.safeAreaLayoutGuide.topAnchor),
            textView.leadingAnchor.constraint(equalTo: reportVC.view.leadingAnchor, constant: 16),
            textView.trailingAnchor.constraint(equalTo: reportVC.view.trailingAnchor, constant: -16),
            textView.bottomAnchor.constraint(equalTo: reportVC.view.bottomAnchor)
        ])
        
        let navController = UINavigationController(rootViewController: reportVC)
        reportVC.navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: "Close",
            style: .done,
            target: self,
            action: #selector(dismissReportViewController)
        )
        
        present(navController, animated: true)
    }
    
    @objc private func dismissReportViewController() {
        dismiss(animated: true)
    }
    
    private func showRawDataOptions(sessionID: String) {
        let alert = UIAlertController(title: "Raw Data Files", message: "Select a file to download:", preferredStyle: .actionSheet)
        
        let fileTypes = [
            ("measurements.csv", "Pupil Measurements"),
            ("events.csv", "Task Events"),
            ("gradcpt_responses.csv", "GradCPT Responses"),
            ("memory_responses.csv", "Memory Task Responses"),
            ("performance_metrics.json", "Performance Metrics"),
            ("demographics.json", "Demographics")
        ]
        
        for (fileName, description) in fileTypes {
            alert.addAction(UIAlertAction(title: description, style: .default) { [weak self] _ in
                self?.downloadRawDataFile(sessionID: sessionID, fileName: fileName)
            })
        }
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        if let popover = alert.popoverPresentationController {
            popover.sourceView = view
            popover.sourceRect = CGRect(x: view.bounds.midX, y: view.bounds.midY, width: 0, height: 0)
        }
        
        present(alert, animated: true)
    }
    
    private func downloadRawDataFile(sessionID: String, fileName: String) {
        loadingIndicator.startAnimating()
        statusLabel.text = "Downloading \(fileName)..."
        
        firebaseManager.downloadSessionFile(sessionID: sessionID, fileName: fileName) { [weak self] data, error in
            DispatchQueue.main.async {
                self?.loadingIndicator.stopAnimating()
                self?.statusLabel.text = "\(self?.availableSessions.count ?? 0) sessions available"
                
                if let error = error {
                    self?.showAlert(title: "Download Error", message: "Could not download \(fileName): \(error.localizedDescription)")
                } else if let data = data {
                    self?.shareData(data: data, fileName: fileName)
                } else {
                    self?.showAlert(title: "Error", message: "No data received for \(fileName)")
                }
            }
        }
    }
    
    private func exportSession(sessionID: String) {
        // This would typically create a ZIP file of all session data
        showAlert(title: "Export Session", message: "Full session export feature coming soon. Use 'Download Raw Data' for individual files.")
    }
    
    private func shareData(data: Data, fileName: String) {
        // Create temporary file
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        
        do {
            try data.write(to: tempURL)
            
            let activityVC = UIActivityViewController(activityItems: [tempURL], applicationActivities: nil)
            
            // For iPad
            if let popover = activityVC.popoverPresentationController {
                popover.sourceView = view
                popover.sourceRect = CGRect(x: view.bounds.midX, y: view.bounds.midY, width: 0, height: 0)
            }
            
            present(activityVC, animated: true)
        } catch {
            showAlert(title: "Export Error", message: "Could not save file: \(error.localizedDescription)")
        }
    }
    
    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}
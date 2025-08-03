//
//  YouTubeVideoViewController4.swift
//  PupillometryApp
//
//  Created by Claude Code on 25/07/25.
//  YouTube Ad Video 4 - Final video content type tracking for dashboard analytics
//

import UIKit
import WebKit

class YouTubeVideoViewController4: UIViewController {
    
    // MARK: - IBOutlets (Storyboard-based)
    @IBOutlet weak var videoContainerView: UIView?
    @IBOutlet weak var instructionLabel: UILabel?
    @IBOutlet weak var progressView: UIProgressView?
    @IBOutlet weak var continueButton: UIButton?
    @IBOutlet weak var skipButton: UIButton?
    
    // MARK: - Programmatic UI Elements
    private var webView: WKWebView!
    private var programmaticInstructionLabel: UILabel?
    private var programmaticProgressView: UIProgressView?
    private var programmaticContinueButton: UIButton?
    private var programmaticSkipButton: UIButton?
    
    // MARK: - Properties
    private let pupillometryManager = PupillometryManager.shared
    
    // YouTube video configuration - Video 4 (Final/Summary)
    private let videoID = "dQw4w9WgXcQ"  // Placeholder - replace with actual final ad video ID
    private let videoTitle = "Premium Coffee Brand - Advertisement 4 (Brand Summary)"
    private let contentType: ContentType = .youtubeVideo4
    
    // Timing and progress tracking
    private var videoStartTime: TimeInterval = 0
    private var currentVideoTime: TimeInterval = 0
    private var videoDuration: TimeInterval = 25.0  // Final summary ad
    private var progressTimer: Timer?
    
    // Pupillometry tracking
    private var isTrackingActive = false
    
    // MARK: - Lifecycle Methods
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupWebView()
        configureVideoTracking()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Set current content type for measurement flagging
        pupillometryManager.setCurrentContentType(contentType, taskPhase: "video_playback")
        
        // Ensure pupillometry recording is active for video tracking
        if !pupillometryManager.isCurrentlyRecording {
            print("🎞️ YouTubeVideo4: Resuming pupillometry recording")
            pupillometryManager.startSession()
        } else {
            print("🎞️ YouTubeVideo4: Pupillometry recording already active")
        }
        
        prepareForVideoPlayback()
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        stopVideoTracking()
    }
    
    // MARK: - UI Setup
    
    private func setupUI() {
        title = "YouTube Ad Video 4"
        view.backgroundColor = .black
        
        // Use storyboard outlets if available, otherwise create programmatically
        if instructionLabel == nil {
            createProgrammaticUI()
        } else {
            configureStoryboardUI()
        }
    }
    
    private func createProgrammaticUI() {
        // Create instruction label with final video messaging
        let instructionLbl = UILabel()
        instructionLbl.translatesAutoresizingMaskIntoConstraints = false
        instructionLbl.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        instructionLbl.textAlignment = .center
        instructionLbl.numberOfLines = 0
        instructionLbl.text = "🏁 Final advertisement - brand summary and call to action.\\n\\nWatch this concluding video while we complete attention measurement."
        view.addSubview(instructionLbl)
        programmaticInstructionLabel = instructionLbl
        
        // Create video container view
        let containerView = UIView()
        containerView.translatesAutoresizingMaskIntoConstraints = false
        containerView.backgroundColor = .black
        containerView.layer.cornerRadius = 12
        view.addSubview(containerView)
        videoContainerView = containerView
        
        // Create progress view
        let progressVw = UIProgressView(progressViewStyle: .default)
        progressVw.translatesAutoresizingMaskIntoConstraints = false
        progressVw.progressTintColor = .systemPurple  // Final video theme color
        view.addSubview(progressVw)
        programmaticProgressView = progressVw
        
        // Create continue button (leads to completion/results)
        let continueBtn = UIButton(type: .system)
        continueBtn.translatesAutoresizingMaskIntoConstraints = false
        continueBtn.setTitle("Complete Video Session", for: .normal)
        continueBtn.backgroundColor = .systemPurple
        continueBtn.setTitleColor(.white, for: .normal)
        continueBtn.layer.cornerRadius = 8
        continueBtn.titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        continueBtn.addTarget(self, action: #selector(continueButtonTapped), for: .touchUpInside)
        continueBtn.isEnabled = false
        continueBtn.alpha = 0.5
        view.addSubview(continueBtn)
        programmaticContinueButton = continueBtn
        
        // Create skip button
        let skipBtn = UIButton(type: .system)
        skipBtn.translatesAutoresizingMaskIntoConstraints = false
        skipBtn.setTitle("Skip Final Video", for: .normal)
        skipBtn.setTitleColor(.systemGray, for: .normal)
        skipBtn.titleLabel?.font = UIFont.systemFont(ofSize: 14, weight: .regular)
        skipBtn.addTarget(self, action: #selector(skipButtonTapped), for: .touchUpInside)
        view.addSubview(skipBtn)
        programmaticSkipButton = skipBtn
        
        // Setup constraints
        setupProgrammaticConstraints()
    }
    
    private func setupProgrammaticConstraints() {
        guard let instructionLabel = programmaticInstructionLabel,
              let videoContainer = videoContainerView,
              let progressView = programmaticProgressView,
              let continueButton = programmaticContinueButton,
              let skipButton = programmaticSkipButton else { return }
        
        NSLayoutConstraint.activate([
            // Instruction label
            instructionLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            instructionLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            instructionLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            
            // Video container
            videoContainer.topAnchor.constraint(equalTo: instructionLabel.bottomAnchor, constant: 20),
            videoContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            videoContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            videoContainer.heightAnchor.constraint(equalTo: videoContainer.widthAnchor, multiplier: 9.0/16.0),
            
            // Progress view
            progressView.topAnchor.constraint(equalTo: videoContainer.bottomAnchor, constant: 20),
            progressView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            progressView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            
            // Continue button
            continueButton.topAnchor.constraint(equalTo: progressView.bottomAnchor, constant: 30),
            continueButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            continueButton.widthAnchor.constraint(equalToConstant: 220),
            continueButton.heightAnchor.constraint(equalToConstant: 44),
            
            // Skip button
            skipButton.topAnchor.constraint(equalTo: continueButton.bottomAnchor, constant: 10),
            skipButton.centerXAnchor.constraint(equalTo: view.centerXAnchor)
        ])
    }
    
    private func configureStoryboardUI() {
        instructionLabel?.text = "🏁 Final advertisement - brand summary and call to action.\\n\\nWatch this concluding video while we complete attention measurement."
        continueButton?.setTitle("Complete Video Session", for: .normal)
        continueButton?.isEnabled = false
        continueButton?.alpha = 0.5
        skipButton?.setTitle("Skip Final Video", for: .normal)
        
        // Add button targets
        continueButton?.addTarget(self, action: #selector(continueButtonTapped), for: .touchUpInside)
        skipButton?.addTarget(self, action: #selector(skipButtonTapped), for: .touchUpInside)
    }
    
    // MARK: - WebView Setup
    
    private func setupWebView() {
        let webConfiguration = WKWebViewConfiguration()
        webConfiguration.allowsInlineMediaPlayback = true
        webConfiguration.mediaTypesRequiringUserActionForPlayback = []
        
        webView = WKWebView(frame: .zero, configuration: webConfiguration)
        webView.translatesAutoresizingMaskIntoConstraints = false
        webView.navigationDelegate = self
        
        guard let container = videoContainerView else { return }
        container.addSubview(webView)
        
        NSLayoutConstraint.activate([
            webView.topAnchor.constraint(equalTo: container.topAnchor),
            webView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            webView.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])
    }
    
    // MARK: - Video Configuration
    
    private func prepareForVideoPlayback() {
        let youtubeHTML = createYouTubeEmbedHTML()
        webView.loadHTMLString(youtubeHTML, baseURL: nil)
        updateProgress(0.0)
    }
    
    private func createYouTubeEmbedHTML() -> String {
        return """
        <!DOCTYPE html>
        <html>
        <head>
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <style>
                body { margin: 0; padding: 0; background: black; }
                .video-container { position: relative; width: 100%; height: 100vh; }
                iframe { position: absolute; top: 0; left: 0; width: 100%; height: 100%; }
            </style>
        </head>
        <body>
            <div class="video-container">
                <iframe src="https://www.youtube.com/embed/\(videoID)?autoplay=1&controls=1&showinfo=0&rel=0&iv_load_policy=3&modestbranding=1&enablejsapi=1"
                        frameborder="0" 
                        allow="autoplay; encrypted-media" 
                        allowfullscreen>
                </iframe>
            </div>
        </body>
        </html>
        """
    }
    
    // MARK: - Pupillometry Tracking
    
    private func configureVideoTracking() {
        print("🎬 YouTubeVideoViewController4: Configuring final video tracking for \(contentType.displayName)")
    }
    
    private func startVideoTracking() {
        videoStartTime = CACurrentMediaTime()
        isTrackingActive = true
        
        progressTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.updateVideoProgress()
        }
        
        logVideoEvent(.videoStart, data: [
            "video_id": videoID,
            "video_title": videoTitle,
            "content_type": contentType.rawValue,
            "video_category": "brand_summary",
            "is_final_video": true
        ])
        
        print("▶️ Final video tracking started: \\(videoTitle)")
    }
    
    private func stopVideoTracking() {
        isTrackingActive = false
        progressTimer?.invalidate()
        progressTimer = nil
        
        logVideoEvent(.videoEnd, data: [
            "video_id": videoID,
            "duration_watched": currentVideoTime,
            "completion_percentage": (currentVideoTime / videoDuration) * 100,
            "video_category": "brand_summary",
            "is_final_video": true,
            "session_completed": true
        ])
        
        print("⏹️ Final video tracking stopped - Session complete")
    }
    
    private func updateVideoProgress() {
        guard isTrackingActive else { return }
        
        currentVideoTime = CACurrentMediaTime() - videoStartTime
        let progress = min(currentVideoTime / videoDuration, 1.0)
        
        DispatchQueue.main.async { [weak self] in
            self?.updateProgress(Float(progress))
            
            if progress >= 1.0 {
                self?.enableContinueButton()
            }
        }
    }
    
    private func updateProgress(_ progress: Float) {
        if let progressView = programmaticProgressView {
            progressView.progress = progress
        } else {
            self.progressView?.progress = progress
        }
    }
    
    private func enableContinueButton() {
        let button = programmaticContinueButton ?? continueButton
        button?.isEnabled = true
        button?.alpha = 1.0
    }
    
    // MARK: - Event Logging
    
    private func logVideoEvent(_ eventType: TaskEvent.EventType, data: [String: Any]) {
        let event = TaskEvent(
            timestamp: CACurrentMediaTime(),
            type: eventType,
            data: data,
            contentType: contentType
        )
        
        pupillometryManager.recordEvent(event)
        print("📊 Final video event logged: \\(eventType.rawValue) - \\(contentType.rawValue)")
    }
    
    // MARK: - Button Actions
    
    @objc private func continueButtonTapped() {
        stopVideoTracking()
        
        // Log completion of video session
        logVideoEvent(.contentTypeChange, data: [
            "video_session_completed": true,
            "total_videos_watched": 4,
            "final_content_type": contentType.rawValue
        ])
        
        // Complete consumer pathway session and navigate to results
        print("🏁 YouTubeVideo4: Consumer pathway complete, navigating to results")
        completeConsumerSession()
        navigateToResults()
    }
    
    @objc private func skipButtonTapped() {
        stopVideoTracking()
        
        logVideoEvent(.videoEnd, data: [
            "video_id": videoID,
            "skipped": true,
            "duration_watched": currentVideoTime,
            "video_category": "brand_summary",
            "is_final_video": true,
            "session_completed_with_skip": true
        ])
        
        print("⏭️ YouTubeVideo4: Final video skipped, completing session")
        completeConsumerSession()
        navigateToResults()
    }
    
    // MARK: - Consumer Pathway Completion
    
    private func completeConsumerSession() {
        print("🏁 YouTubeVideo4: Completing consumer pathway session")
        
        // Stop pupillometry session
        pupillometryManager.stopSession()
        
        // Log session completion
        let completionEvent = TaskEvent(
            timestamp: CACurrentMediaTime(),
            type: .contentTypeChange,
            data: [
                "pathway_type": "consumer",
                "total_videos": 4,
                "session_completed": true,
                "session_duration": Date().timeIntervalSince(pupillometryManager.currentSession?.startTime ?? Date())
            ],
            contentType: .youtubeVideo4
        )
        pupillometryManager.recordEvent(completionEvent)
        
        print("✅ Consumer pathway session completed")
    }
    
    private func navigateToResults() {
        print("📊 YouTubeVideo4: Navigating to results")
        
        let storyboard = UIStoryboard(name: "MainClean", bundle: nil)
        
        do {
            let resultsVC = storyboard.instantiateViewController(withIdentifier: "ResultsViewController") as! ResultsViewController
            resultsVC.title = "Your Attention Analysis"
            navigationController?.pushViewController(resultsVC, animated: true)
            print("✅ Successfully navigated to ResultsViewController")
        } catch {
            print("❌ Error loading ResultsViewController: \\(error)")
            showErrorAlert("Failed to load results. Please try again.")
        }
    }
    
    private func showErrorAlert(_ message: String) {
        let alert = UIAlertController(title: "Navigation Error", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}

// MARK: - WKNavigationDelegate

extension YouTubeVideoViewController4: WKNavigationDelegate {
    
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        print("📺 Final YouTube video loaded successfully")
        startVideoTracking()
    }
    
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        print("❌ Final YouTube video failed to load: \\(error.localizedDescription)")
        
        DispatchQueue.main.async { [weak self] in
            let alert = UIAlertController(
                title: "Final Video Load Error",
                message: "Unable to load the final video. You can skip to complete the session or try again.",
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: "Complete Session", style: .default) { _ in
                self?.skipButtonTapped()
            })
            alert.addAction(UIAlertAction(title: "Retry", style: .default) { _ in
                self?.prepareForVideoPlayback()
            })
            self?.present(alert, animated: true)
        }
    }
}
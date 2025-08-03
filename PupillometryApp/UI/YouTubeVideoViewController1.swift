//
//  YouTubeVideoViewController1.swift
//  PupillometryApp
//
//  Created by Claude Code on 25/07/25.
//  YouTube Ad Video 1 - Content type tracking for dashboard analytics
//

import UIKit
import WebKit

class YouTubeVideoViewController1: UIViewController {
    
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
    
    // Consumer pathway tracking
    private var isConsumerPathway: Bool {
        return pupillometryManager.currentSession?.pathwayType == .consumer
    }
    
    // YouTube video configuration
    private let videoID = "XFNqN0q_i2A"  // Coca Cola advertisement
    private let videoTitle = "Coca Cola - Share a Coke"
    private let contentType: ContentType = .youtubeVideo1
    
    // Timing and progress tracking
    private var videoStartTime: TimeInterval = 0
    private var currentVideoTime: TimeInterval = 0
    private var videoDuration: TimeInterval = 30.0  // Expected ad duration
    private var progressTimer: Timer?
    
    // Pupillometry tracking
    private var isTrackingActive = false
    private var initialMeasurementCount = 0
    
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
        if isConsumerPathway {
            if pupillometryManager.currentSession == nil {
                print("🎞️ YouTubeVideo1: Starting new consumer pathway session")
                pupillometryManager.startSession()
            } else if !pupillometryManager.isCurrentlyRecording {
                print("🎞️ YouTubeVideo1: Resuming pupillometry recording for existing session")
                pupillometryManager.startSession()
            } else {
                print("🎞️ YouTubeVideo1: Pupillometry recording already active")
            }
        }
        
        prepareForVideoPlayback()
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        stopVideoTracking()
    }
    
    // MARK: - UI Setup
    
    private func setupUI() {
        title = "YouTube Ad Video 1"
        view.backgroundColor = .black
        
        // Use storyboard outlets if available, otherwise create programmatically
        if instructionLabel == nil {
            createProgrammaticUI()
        } else {
            configureStoryboardUI()
        }
    }
    
    private func createProgrammaticUI() {
        // Create instruction label
        let instructionLbl = UILabel()
        instructionLbl.translatesAutoresizingMaskIntoConstraints = false
        instructionLbl.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        instructionLbl.textAlignment = .center
        instructionLbl.numberOfLines = 0
        instructionLbl.text = "📺 Please watch this Coca Cola advertisement while we track your attention patterns.\\n\\nWe'll compare your response to different cola brands."
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
        progressVw.progressTintColor = .systemBlue
        view.addSubview(progressVw)
        programmaticProgressView = progressVw
        
        // Create continue button
        let continueBtn = UIButton(type: .system)
        continueBtn.translatesAutoresizingMaskIntoConstraints = false
        continueBtn.setTitle("Continue to Pepsi Ad", for: .normal)
        continueBtn.backgroundColor = .systemBlue
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
        skipBtn.setTitle("Skip Video", for: .normal)
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
            videoContainer.heightAnchor.constraint(equalTo: videoContainer.widthAnchor, multiplier: 9.0/16.0), // 16:9 aspect ratio
            
            // Progress view
            progressView.topAnchor.constraint(equalTo: videoContainer.bottomAnchor, constant: 20),
            progressView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            progressView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            
            // Continue button
            continueButton.topAnchor.constraint(equalTo: progressView.bottomAnchor, constant: 30),
            continueButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            continueButton.widthAnchor.constraint(equalToConstant: 200),
            continueButton.heightAnchor.constraint(equalToConstant: 44),
            
            // Skip button
            skipButton.topAnchor.constraint(equalTo: continueButton.bottomAnchor, constant: 10),
            skipButton.centerXAnchor.constraint(equalTo: view.centerXAnchor)
        ])
    }
    
    private func configureStoryboardUI() {
        instructionLabel?.text = "📺 Please watch this Coca Cola advertisement while we track your attention patterns.\\n\\nWe'll compare your response to different cola brands."
        continueButton?.setTitle("Continue to Pepsi Ad", for: .normal)
        continueButton?.isEnabled = false
        continueButton?.alpha = 0.5
        skipButton?.setTitle("Skip Video", for: .normal)
        
        // Add button targets
        continueButton?.addTarget(self, action: #selector(continueButtonTapped), for: .touchUpInside)
        skipButton?.addTarget(self, action: #selector(skipButtonTapped), for: .touchUpInside)
    }
    
    // MARK: - WebView Setup
    
    private func setupWebView() {
        // Configure WKWebView for YouTube embedding
        // Based on research: "WKWebView YouTube video embed Swift" best practices
        let webConfiguration = WKWebViewConfiguration()
        webConfiguration.allowsInlineMediaPlayback = true
        webConfiguration.mediaTypesRequiringUserActionForPlayback = []
        
        webView = WKWebView(frame: .zero, configuration: webConfiguration)
        webView.translatesAutoresizingMaskIntoConstraints = false
        webView.navigationDelegate = self
        
        // Add webView to container
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
        // Load YouTube video using iframe API
        // Research source: YouTube IFrame Player API documentation
        let youtubeHTML = createYouTubeEmbedHTML()
        webView.loadHTMLString(youtubeHTML, baseURL: nil)
        
        // Initialize progress tracking
        updateProgress(0.0)
    }
    
    private func createYouTubeEmbedHTML() -> String {
        // Create responsive YouTube embed with JavaScript API for tracking
        // Assumption: Using iframe API for better control over video events
        // Resource: Google Developers YouTube IFrame Player API
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
            <script>
                // Video event tracking
                window.addEventListener('message', function(event) {
                    if (event.data && event.data.event) {
                        window.webkit.messageHandlers.videoEvent.postMessage(event.data);
                    }
                });
            </script>
        </body>
        </html>
        """
    }
    
    // MARK: - Pupillometry Tracking
    
    private func configureVideoTracking() {
        // Configure pupillometry manager for video content tracking
        // Set content type for dashboard filtering
        print("🎬 YouTubeVideoViewController1: Configuring video tracking for \(contentType.displayName)")
    }
    
    private func startVideoTracking() {
        videoStartTime = CACurrentMediaTime()
        isTrackingActive = true
        
        // Verify pupillometry session is active
        if let session = pupillometryManager.currentSession {
            initialMeasurementCount = session.pupilMeasurements.count
            print("✅ YouTubeVideo1: Pupillometry session active - ID: \(session.sessionID)")
            print("📊 YouTubeVideo1: Initial measurements count: \(initialMeasurementCount)")
        } else {
            print("⚠️ YouTubeVideo1: No active pupillometry session!")
            // Try to start session if missing
            pupillometryManager.startSession()
            initialMeasurementCount = 0
        }
        
        // Start progress timer
        progressTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.updateVideoProgress()
        }
        
        // Log video start event
        logVideoEvent(.videoStart, data: [
            "video_id": videoID,
            "video_title": videoTitle,
            "content_type": contentType.rawValue
        ])
        
        print("▶️ Video tracking started: \(videoTitle)")
    }
    
    private func stopVideoTracking() {
        isTrackingActive = false
        progressTimer?.invalidate()
        progressTimer = nil
        
        // Log video end event
        logVideoEvent(.videoEnd, data: [
            "video_id": videoID,
            "duration_watched": currentVideoTime,
            "completion_percentage": (currentVideoTime / videoDuration) * 100
        ])
        
        print("⏹️ Video tracking stopped")
    }
    
    private func updateVideoProgress() {
        guard isTrackingActive else { return }
        
        currentVideoTime = CACurrentMediaTime() - videoStartTime
        let progress = min(currentVideoTime / videoDuration, 1.0)
        
        // Debug: Check if pupillometry data is being collected
        if let session = pupillometryManager.currentSession {
            let measurementCount = session.pupilMeasurements.count
            if Int(currentVideoTime) % 5 == 0 { // Log every 5 seconds
                print("📊 YouTubeVideo1: Video progress: \(String(format: "%.1f", progress*100))%, Measurements: \(measurementCount)")
                
                // Check if PupillometryManager is still actively recording
                print("🎥 YouTubeVideo1: PupillometryManager recording status: \(pupillometryManager.isCurrentlyRecording)")
                
                // Check if new measurements have been added since video started
                let measurementsSinceStart = measurementCount - initialMeasurementCount
                print("📈 YouTubeVideo1: New measurements since video start: \(measurementsSinceStart)")
            }
        }
        
        DispatchQueue.main.async { [weak self] in
            self?.updateProgress(Float(progress))
            
            // Enable continue button when video is complete
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
        // Create task event with content type tracking
        // This data will be used by the dashboard for video-specific analytics
        let event = TaskEvent(
            timestamp: CACurrentMediaTime(),
            type: eventType,
            data: data,
            contentType: contentType
        )
        
        // Add to session data
        pupillometryManager.recordEvent(event)
        
        print("📊 Video event logged: \(eventType.rawValue) - \(contentType.rawValue)")
    }
    
    // MARK: - Button Actions
    
    @objc private func continueButtonTapped() {
        stopVideoTracking()
        
        // Navigate to next video in consumer pathway
        print("➡️ YouTubeVideo1: Navigating to next video")
        navigateToNextVideo()
    }
    
    private func navigateToNextVideo() {
        let youtubeVC2 = YouTubeVideoViewController2()
        youtubeVC2.title = "Pepsi Advertisement"
        navigationController?.pushViewController(youtubeVC2, animated: true)
    }
    
    @objc private func skipButtonTapped() {
        stopVideoTracking()
        
        // Log skip event
        logVideoEvent(.videoEnd, data: [
            "video_id": videoID,
            "skipped": true,
            "duration_watched": currentVideoTime
        ])
        
        // Navigate to next video (skip current)
        print("⏭️ YouTubeVideo1: Skipping to next video")
        navigateToNextVideo()
    }
}

// MARK: - WKNavigationDelegate

extension YouTubeVideoViewController1: WKNavigationDelegate {
    
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        print("📺 YouTube video loaded successfully")
        startVideoTracking()
    }
    
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        print("❌ YouTube video failed to load: \\(error.localizedDescription)")
        
        // Show error message and enable skip
        DispatchQueue.main.async { [weak self] in
            let alert = UIAlertController(
                title: "Video Load Error",
                message: "Unable to load the video. Please check your internet connection.",
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: "Skip", style: .default) { _ in
                self?.skipButtonTapped()
            })
            alert.addAction(UIAlertAction(title: "Retry", style: .default) { _ in
                self?.prepareForVideoPlayback()
            })
            self?.present(alert, animated: true)
        }
    }
}
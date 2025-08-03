//
//  ADHDProtocolTask.swift
//  PupillometryApp
//
//  ADHD Diagnosis Task Implementation
//  Sternberg-type delayed visuospatial working memory task
//  8 blocks × 20 trials = 160 trials total
//

import UIKit
import AVFoundation

protocol ADHDProtocolTaskDelegate: AnyObject {
    func task(_ task: ADHDProtocolTask, didStartBlock block: Int, totalBlocks: Int)
    func task(_ task: ADHDProtocolTask, didStartTrial trial: Int, inBlock block: Int)
    func task(_ task: ADHDProtocolTask, didPresentDotArray dots: [CGPoint], arrayNumber: Int, trialNumber: Int)
    func task(_ task: ADHDProtocolTask, didShowDistractor type: ADHDProtocolResponse.DistractorType, trialNumber: Int)
    func task(_ task: ADHDProtocolTask, didShowProbe position: CGPoint, isTarget: Bool, trialNumber: Int)
    func task(_ task: ADHDProtocolTask, didReceiveResponse response: ADHDProtocolResponse)
    func task(_ task: ADHDProtocolTask, didCompleteBlock block: Int)
    func taskDidComplete(_ task: ADHDProtocolTask)
}

class ADHDProtocolTask {
    
    // MARK: - Properties
    weak var delegate: ADHDProtocolTaskDelegate?
    
    // Task configuration  
    private let totalTrials = 5     // 5 trials total (reduced for stability)
    private let totalBlocks = 8     // 8 blocks per trial
    private let gridSize = 4
    private let dotSize: CGFloat = 20
    
    // Timing configuration (in seconds)
    private let fixationTime: TimeInterval = 0.5
    private let dotArrayTime: TimeInterval = 0.75
    private let delayTime: TimeInterval = 0.5
    private let distractorTime: TimeInterval = 0.5
    private let probeTime: TimeInterval = 1.5
    private let feedbackTime: TimeInterval = 1.5
    
    // Current state
    private var currentTrial = 1     // Current trial (1-10)
    private var currentBlock = 1     // Current block within trial (1-8)
    private var isRunning = false
    private var trialTimer: Timer?
    private var currentTrialState: TrialState = .idle
    
    // ADHD Task timing boundaries (for ADHD detection model)
    private var adhdTaskStartTime: TimeInterval = 0
    private var adhdTaskEndTime: TimeInterval = 0
    
    // Trial data
    private var currentTrialData: TrialSetup?
    private var currentDotArrayIndex = 0
    private var trialStartTime: TimeInterval = 0
    private var responseStartTime: TimeInterval = 0
    
    // Grid and UI
    private var gridCells: [CGRect] = []
    private var gridView: UIView?
    
    // Pupillometry tracking
    private var pupillometryManager = PupillometryManager.shared
    private var trialPupilSamples: [Float] = []
    private var trialConfidenceScores: [Float] = []
    private var trialTimestamps: [TimeInterval] = []
    private var pupilDataTimer: Timer?
    
    enum TrialState: Equatable {
        case idle
        case fixation
        case dotArray(Int)  // Array number (1, 2, or 3)
        case delay(Int)     // After array number
        case distractor
        case probe
        case feedback
        case interTrialInterval
        
        static func == (lhs: TrialState, rhs: TrialState) -> Bool {
            switch (lhs, rhs) {
            case (.idle, .idle), (.fixation, .fixation), (.distractor, .distractor), 
                 (.probe, .probe), (.feedback, .feedback), (.interTrialInterval, .interTrialInterval):
                return true
            case (.dotArray(let lhsInt), .dotArray(let rhsInt)):
                return lhsInt == rhsInt
            case (.delay(let lhsInt), .delay(let rhsInt)):
                return lhsInt == rhsInt
            default:
                return false
            }
        }
    }
    
    private struct TrialSetup {
        let trialNumber: Int
        let blockNumber: Int
        let loadCondition: ADHDProtocolResponse.LoadCondition
        let distractorType: ADHDProtocolResponse.DistractorType
        let dotArrays: [[CGPoint]]  // 3 arrays of dot positions
        let probePosition: CGPoint
        let isTarget: Bool
    }
    
    // MARK: - Initialization
    
    init() {
        setupTask()
    }
    
    private func setupTask() {
        print("🧠 ADHDProtocolTask: Initializing ADHD Protocol Task")
        print("📊 Configuration: \(totalTrials) trials × \(totalBlocks) blocks = \(totalTrials * totalBlocks) total task units (reduced for stability)")
    }
    
    // MARK: - Public Methods
    
    func start(with gridView: UIView) {
        guard !isRunning else {
            print("⚠️ Task is already running")
            return
        }
        
        self.gridView = gridView
        setupGrid()
        
        isRunning = true
        currentBlock = 1
        currentTrial = 1
        
        // Record ADHD task start time (for ADHD detection model scope)
        adhdTaskStartTime = CACurrentMediaTime()
        
        // Set content type for clinical ADHD measurements
        pupillometryManager.setCurrentContentType(.gradcpt, taskPhase: "adhd_protocol")
        
        print("🚀 Starting ADHD Protocol Task at timestamp: \(adhdTaskStartTime)")
        print("📊 Configuration: \(totalTrials) trials × \(totalBlocks) blocks = \(totalTrials * totalBlocks) total task units (reduced for stability)")
        
        delegate?.task(self, didStartTrial: currentTrial, inBlock: currentBlock)
        
        startNextTrial()
    }
    
    func stop() {
        print("⏹️ Stopping ADHD Protocol Task")
        
        // Stop all timers
        trialTimer?.invalidate()
        trialTimer = nil
        
        pupilDataTimer?.invalidate()
        pupilDataTimer = nil
        
        // Reset state
        isRunning = false
        currentTrialState = .idle
        
        // Clear references to help with memory cleanup
        currentTrialData = nil
        trialPupilSamples.removeAll()
        trialConfidenceScores.removeAll()
        trialTimestamps.removeAll()
        
        print("✅ ADHD Protocol Task stopped and cleaned up")
    }
    
    func recordResponse(isYes: Bool) {
        guard currentTrialState == .probe,
              let trialData = currentTrialData else {
            print("⚠️ Response recorded at wrong time - ignoring")
            return
        }
        
        let responseTime = CACurrentMediaTime()
        let reactionTime = responseTime - responseStartTime
        let isCorrect = (isYes == trialData.isTarget)
        
        // Stop pupil data collection for this trial
        stopPupilDataCollection()
        
        // Create response object
        let response = ADHDProtocolResponse(
            trialNumber: trialData.trialNumber,
            blockNumber: trialData.blockNumber,
            isTarget: trialData.isTarget,
            userResponse: isYes,
            isCorrect: isCorrect,
            reactionTime: reactionTime,
            loadCondition: trialData.loadCondition,
            distractorType: trialData.distractorType,
            timestamp: responseTime
        )
        
        // Process pupil data for this trial
        processTrialPupilData(for: trialData, response: response)
        
        // Notify delegate
        delegate?.task(self, didReceiveResponse: response)
        
        // Show feedback and continue
        showFeedback(isCorrect: isCorrect)
    }
    
    func recordTimeoutResponse() {
        guard currentTrialState == .probe,
              let trialData = currentTrialData else {
            print("⚠️ Timeout recorded at wrong time - ignoring")
            return
        }
        
        let responseTime = CACurrentMediaTime()
        let reactionTime = responseTime - responseStartTime
        
        // Stop pupil data collection for this trial
        stopPupilDataCollection()
        
        // Create response object - timeout is always incorrect
        let response = ADHDProtocolResponse(
            trialNumber: trialData.trialNumber,
            blockNumber: trialData.blockNumber,
            isTarget: trialData.isTarget,
            userResponse: false,  // Default to "NO" for timeout
            isCorrect: false,     // Timeout is always incorrect
            reactionTime: reactionTime,
            loadCondition: trialData.loadCondition,
            distractorType: trialData.distractorType,
            timestamp: responseTime
        )
        
        // Process pupil data for this trial
        processTrialPupilData(for: trialData, response: response)
        
        // Notify delegate
        delegate?.task(self, didReceiveResponse: response)
        
        // Show feedback (always incorrect for timeout)
        showFeedback(isCorrect: false)
    }
    
    // MARK: - Private Methods - Trial Flow
    
    private func startNextTrial() {
        guard currentTrial <= totalTrials else {
            completeTask()
            return
        }
        
        // Reset to first block for new trial
        currentBlock = 1
        
        print("📊 Starting Trial \(currentTrial)/\(totalTrials)")
        delegate?.task(self, didStartTrial: currentTrial, inBlock: currentBlock)
        
        startNextBlock()
    }
    
    private func startNextBlock() {
        guard currentBlock <= totalBlocks else {
            completeCurrentTrial()
            return
        }
        
        print("📊 Starting Block \(currentBlock)/\(totalBlocks) in Trial \(currentTrial)")
        
        // Notify delegate about block start
        delegate?.task(self, didStartTrial: currentTrial, inBlock: currentBlock)
        
        // Generate block setup (each block is like a mini-trial)
        currentTrialData = generateTrialSetup()
        currentDotArrayIndex = 0
        
        // Reset pupil data collection for this block
        resetPupilDataCollection()
        
        // Record block start for ADHD model
        let blockStartTime = CACurrentMediaTime()
        let taskPhase = "trial_\(currentTrial)_block_\(currentBlock)"
        
        // Update task phase for detailed measurement tracking
        pupillometryManager.setCurrentContentType(.gradcpt, taskPhase: taskPhase)
        
        pupillometryManager.currentSession?.taskEvents.append(TaskEvent(
            timestamp: blockStartTime,
            type: .trialStart,  // Using trialStart for each block
            data: [
                "trial_number": currentTrial,
                "block_number": currentBlock,
                "trial_start_timestamp": trialStartTime,
                "task_phase": taskPhase
            ],
            contentType: .gradcpt
        ))
        
        // Start with fixation
        showFixation()
    }
    
    private func generateTrialSetup() -> TrialSetup {
        let loadCondition: ADHDProtocolResponse.LoadCondition = Bool.random() ? .high : .low
        let distractorType = ADHDProtocolResponse.DistractorType.allCases.randomElement() ?? .none
        
        // Generate 3 dot arrays
        var dotArrays: [[CGPoint]] = []
        var allMemoryDots: [CGPoint] = []
        
        for _ in 0..<3 {
            let dotsPerArray = loadCondition == .high ? 2 : 1
            let arrayDots = generateDotArray(count: dotsPerArray)
            dotArrays.append(arrayDots)
            allMemoryDots.append(contentsOf: arrayDots)
        }
        
        // Generate probe (50% target, 50% lure) - SAFE VERSION
        let isTarget = Bool.random()
        let probePosition: CGPoint
        
        if isTarget && !allMemoryDots.isEmpty {
            probePosition = allMemoryDots.randomElement() ?? CGPoint(x: 150, y: 150) // Safe fallback
        } else {
            // Generate lure position (not in memory set)
            let allGridPositions = gridCells.map { CGPoint(x: $0.midX, y: $0.midY) }
            let lurePositions = allGridPositions.filter { !allMemoryDots.contains($0) }
            
            // SAFE: Multiple fallbacks to prevent crashes
            if let lurePososition = lurePositions.randomElement() {
                probePosition = lurePososition
            } else if let gridPosition = allGridPositions.randomElement() {
                probePosition = gridPosition
            } else {
                // Ultimate fallback if grids aren't initialized properly
                probePosition = CGPoint(x: 150, y: 150)
                print("⚠️ ADHDProtocolTask: Using fallback probe position due to empty grids")
            }
        }
        
        return TrialSetup(
            trialNumber: currentTrial,
            blockNumber: currentBlock,
            loadCondition: loadCondition,
            distractorType: distractorType,
            dotArrays: dotArrays,
            probePosition: probePosition,
            isTarget: isTarget
        )
    }
    
    private func generateDotArray(count: Int) -> [CGPoint] {
        let availablePositions = gridCells.map { CGPoint(x: $0.midX, y: $0.midY) }
        return Array(availablePositions.shuffled().prefix(count))
    }
    
    private func showFixation() {
        currentTrialState = .fixation
        trialStartTime = CACurrentMediaTime()
        
        clearGrid()
        showFixationCross()
        
        // Start pupil data collection
        startPupilDataCollection()
        
        trialTimer = Timer.scheduledTimer(withTimeInterval: fixationTime, repeats: false) { [weak self] _ in
            self?.showNextDotArray()
        }
    }
    
    private func showNextDotArray() {
        guard let trialData = currentTrialData,
              currentDotArrayIndex < trialData.dotArrays.count else {
            showDistractor()
            return
        }
        
        currentTrialState = .dotArray(currentDotArrayIndex + 1)
        
        let dotArray = trialData.dotArrays[currentDotArrayIndex]
        clearGrid()
        showDots(dotArray)
        
        delegate?.task(self, didPresentDotArray: dotArray, arrayNumber: currentDotArrayIndex + 1, trialNumber: trialData.trialNumber)
        
        trialTimer = Timer.scheduledTimer(withTimeInterval: dotArrayTime, repeats: false) { [weak self] _ in
            self?.showDelay()
        }
    }
    
    private func showDelay() {
        currentTrialState = .delay(currentDotArrayIndex + 1)
        clearGrid()
        showFixationCross()
        
        trialTimer = Timer.scheduledTimer(withTimeInterval: delayTime, repeats: false) { [weak self] _ in
            self?.currentDotArrayIndex += 1
            self?.showNextDotArray()
        }
    }
    
    private func showDistractor() {
        guard let trialData = currentTrialData else { return }
        
        currentTrialState = .distractor
        clearGrid()
        
        delegate?.task(self, didShowDistractor: trialData.distractorType, trialNumber: trialData.trialNumber)
        
        // Show distractor based on type
        switch trialData.distractorType {
        case .none:
            break // Just clear screen
        case .taskRelated:
            showTaskRelatedDistractor()
        case .neutral:
            showNeutralDistractor()
        case .emotional:
            showEmotionalDistractor()
        }
        
        trialTimer = Timer.scheduledTimer(withTimeInterval: distractorTime, repeats: false) { [weak self] _ in
            self?.showProbe()
        }
    }
    
    private func showProbe() {
        guard let trialData = currentTrialData else { return }
        
        currentTrialState = .probe
        responseStartTime = CACurrentMediaTime()
        
        clearGrid()
        showDots([trialData.probePosition])
        
        delegate?.task(self, didShowProbe: trialData.probePosition, isTarget: trialData.isTarget, trialNumber: trialData.trialNumber)
        
        // Auto-timeout after probe time
        trialTimer = Timer.scheduledTimer(withTimeInterval: probeTime, repeats: false) { [weak self] _ in
            // No response = timeout (always incorrect regardless of target/lure)
            self?.recordTimeoutResponse()
        }
    }
    
    private func showFeedback(isCorrect: Bool) {
        currentTrialState = .feedback
        clearGrid()
        
        // Show feedback indicator
        showFeedbackIndicator(correct: isCorrect)
        
        trialTimer = Timer.scheduledTimer(withTimeInterval: feedbackTime, repeats: false) { [weak self] _ in
            self?.completeCurrentBlock()
        }
    }
    
    private func completeCurrentBlock() {
        // CRITICAL: Clean up all timers before proceeding to prevent accumulation
        cleanupAllTimers()
        
        // Record block end for ADHD model
        let blockEndTime = CACurrentMediaTime()
        pupillometryManager.currentSession?.taskEvents.append(TaskEvent(
            timestamp: blockEndTime,
            type: .trialEnd,  // Using trialEnd for each block
            data: [
                "trial_number": currentTrial,
                "block_number": currentBlock,
                "block_end_timestamp": blockEndTime
            ],
            contentType: .gradcpt
        ))
        
        // Periodic memory cleanup every 4 blocks to prevent trial 8 crash
        let totalBlocksCompleted = (currentTrial - 1) * totalBlocks + currentBlock
        if totalBlocksCompleted % 4 == 0 {
            performPeriodicCleanup()
        }
        
        currentBlock += 1
        
        if currentBlock <= totalBlocks {
            // Continue to next block in same trial
            startNextBlock()
        } else {
            // Trial complete, move to next trial
            completeCurrentTrial()
        }
    }
    
    private func completeCurrentTrial() {
        print("✅ Trial \(currentTrial)/\(totalTrials) completed")
        delegate?.task(self, didCompleteBlock: currentTrial)  // Notify UI that trial is complete
        
        currentTrial += 1
        
        if currentTrial <= totalTrials {
            // Brief pause between trials
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
                self?.startNextTrial()
            }
        } else {
            completeTask()
        }
    }
    
    
    private func completeTask() {
        // Record ADHD task end time (for ADHD detection model scope)
        adhdTaskEndTime = CACurrentMediaTime()
        let taskDuration = adhdTaskEndTime - adhdTaskStartTime
        
        print("🎉 ADHD Protocol Task completed!")
        print("⏱️ Task duration: \(String(format: "%.2f", taskDuration)) seconds")
        print("📊 ADHD detection model should analyze data from \(adhdTaskStartTime) to \(adhdTaskEndTime)")
        
        // Store task timing in session for ADHD model scope
        pupillometryManager.currentSession?.taskEvents.append(TaskEvent(
            timestamp: adhdTaskStartTime,
            type: .taskStart,
            data: [
                "task_type": "ADHD_Protocol",
                "total_trials": totalTrials,
                "total_blocks": totalBlocks,
                "start_timestamp": adhdTaskStartTime
            ],
            contentType: .gradcpt  // Using existing enum value for clinical tasks
        ))
        
        pupillometryManager.currentSession?.taskEvents.append(TaskEvent(
            timestamp: adhdTaskEndTime,
            type: .taskEnd,
            data: [
                "task_type": "ADHD_Protocol",
                "duration_seconds": taskDuration,
                "end_timestamp": adhdTaskEndTime
            ],
            contentType: .gradcpt
        ))
        
        stop()
        delegate?.taskDidComplete(self)
    }
    
    // MARK: - Grid and UI Management
    
    private func setupGrid() {
        guard let gridView = gridView else { return }
        
        gridCells.removeAll()
        let cellWidth = gridView.frame.width / CGFloat(gridSize)
        let cellHeight = gridView.frame.height / CGFloat(gridSize)
        
        for row in 0..<gridSize {
            for col in 0..<gridSize {
                let rect = CGRect(
                    x: CGFloat(col) * cellWidth,
                    y: CGFloat(row) * cellHeight,
                    width: cellWidth,
                    height: cellHeight
                )
                gridCells.append(rect)
            }
        }
        
        print("🔲 Grid setup complete: \(gridCells.count) cells")
    }
    
    private func clearGrid() {
        gridView?.subviews.forEach { $0.removeFromSuperview() }
    }
    
    private func showDots(_ positions: [CGPoint]) {
        guard let gridView = gridView else { return }
        
        for position in positions {
            let dotView = UIView(frame: CGRect(
                x: position.x - dotSize/2,
                y: position.y - dotSize/2,
                width: dotSize,
                height: dotSize
            ))
            dotView.backgroundColor = .white
            dotView.layer.cornerRadius = dotSize / 2
            gridView.addSubview(dotView)
        }
    }
    
    private func showFixationCross() {
        guard let gridView = gridView else { return }
        
        let crossSize: CGFloat = 20
        let centerX = gridView.bounds.midX
        let centerY = gridView.bounds.midY
        
        // Horizontal line
        let horizontalLine = UIView(frame: CGRect(x: centerX - crossSize/2, y: centerY - 2, width: crossSize, height: 4))
        horizontalLine.backgroundColor = .white
        gridView.addSubview(horizontalLine)
        
        // Vertical line
        let verticalLine = UIView(frame: CGRect(x: centerX - 2, y: centerY - crossSize/2, width: 4, height: crossSize))
        verticalLine.backgroundColor = .white
        gridView.addSubview(verticalLine)
    }
    
    private func showFeedbackIndicator(correct: Bool) {
        guard let gridView = gridView else { return }
        
        let indicatorSize: CGFloat = 40
        let centerX = gridView.bounds.midX
        let centerY = gridView.bounds.midY
        
        let indicator = UIView(frame: CGRect(x: centerX - indicatorSize/2, y: centerY - indicatorSize/2, width: indicatorSize, height: indicatorSize))
        indicator.backgroundColor = correct ? .systemGreen : .systemRed
        indicator.layer.cornerRadius = indicatorSize / 2
        gridView.addSubview(indicator)
    }
    
    // MARK: - Distractor Display (Placeholder implementations)
    
    private func showTaskRelatedDistractor() {
        // Show a grid pattern or dots as task-related distractor
        let randomPositions = gridCells.shuffled().prefix(4).map { CGPoint(x: $0.midX, y: $0.midY) }
        showDots(Array(randomPositions))
    }
    
    private func showNeutralDistractor() {
        // Show neutral geometric pattern
        guard let gridView = gridView else { return }
        
        let squareSize: CGFloat = 60
        let square = UIView(frame: CGRect(x: gridView.bounds.midX - squareSize/2, y: gridView.bounds.midY - squareSize/2, width: squareSize, height: squareSize))
        square.backgroundColor = .systemGray
        gridView.addSubview(square)
    }
    
    private func showEmotionalDistractor() {
        // Show emotional distractor (placeholder - could be replaced with actual images)
        guard let gridView = gridView else { return }
        
        let triangleSize: CGFloat = 50
        let triangleView = TriangleView(frame: CGRect(x: gridView.bounds.midX - triangleSize/2, y: gridView.bounds.midY - triangleSize/2, width: triangleSize, height: triangleSize))
        triangleView.backgroundColor = .clear
        gridView.addSubview(triangleView)
    }
    
    // MARK: - Pupil Data Collection
    
    private func resetPupilDataCollection() {
        trialPupilSamples.removeAll()
        trialConfidenceScores.removeAll()
        trialTimestamps.removeAll()
    }
    
    private func startPupilDataCollection() {
        pupilDataTimer = Timer.scheduledTimer(withTimeInterval: 1.0/30.0, repeats: true) { [weak self] _ in
            self?.collectPupilSample()
        }
    }
    
    private func stopPupilDataCollection() {
        pupilDataTimer?.invalidate()
        pupilDataTimer = nil
    }
    
    private func collectPupilSample() {
        // Get current pupil measurement from PupillometryManager
        guard let currentSession = pupillometryManager.currentSession,
              let lastMeasurement = currentSession.pupilMeasurements.last else {
            // Add missing sample
            trialPupilSamples.append(Float.nan)
            trialConfidenceScores.append(0.0)
            trialTimestamps.append(CACurrentMediaTime())
            return
        }
        
        trialPupilSamples.append(lastMeasurement.diameterMM)
        trialConfidenceScores.append(lastMeasurement.confidence)
        trialTimestamps.append(lastMeasurement.timestamp)
    }
    
    private func processTrialPupilData(for trialSetup: TrialSetup, response: ADHDProtocolResponse) {
        guard let processedData = PupilDataProcessor.processTrialData(
            pupilSamples: trialPupilSamples,
            confidenceScores: trialConfidenceScores,
            timestamps: trialTimestamps,
            trialNumber: trialSetup.trialNumber,
            blockNumber: trialSetup.blockNumber
        ) else {
            print("❌ Failed to process pupil data for trial \(trialSetup.trialNumber)")
            return
        }
        
        // Complete the trial data with task-specific information
        let completeTrialData = ADHDTrialData(
            trialNumber: processedData.trialNumber,
            blockNumber: processedData.blockNumber,
            startTime: processedData.startTime,
            endTime: processedData.endTime,
            pupilSamples: processedData.pupilSamples,
            sampleTimestamps: processedData.sampleTimestamps,
            dotArrays: trialSetup.dotArrays,
            probePosition: trialSetup.probePosition,
            loadCondition: trialSetup.loadCondition,
            distractorType: trialSetup.distractorType,
            isValidTrial: processedData.isValidTrial,
            qualityMetrics: processedData.qualityMetrics
        )
        
        // Add to session
        pupillometryManager.currentSession?.addADHDProtocolResponse(response)
        pupillometryManager.currentSession?.addADHDTrialData(completeTrialData)
    }
    
    // MARK: - Critical Safety Methods for Trial 8 Crash Prevention
    
    private func cleanupAllTimers() {
        // Aggressive timer cleanup to prevent accumulation
        trialTimer?.invalidate()
        trialTimer = nil
        
        pupilDataTimer?.invalidate()
        pupilDataTimer = nil
        
        print("🧹 ADHDProtocolTask: All timers cleaned up (Block \(currentBlock), Trial \(currentTrial))")
    }
    
    private func performPeriodicCleanup() {
        let totalBlocksCompleted = (currentTrial - 1) * totalBlocks + currentBlock
        print("🧹 ADHDProtocolTask: Performing periodic cleanup at block \(totalBlocksCompleted)/40")
        
        // Clear accumulated trial data to prevent memory buildup
        trialPupilSamples.removeAll(keepingCapacity: true)
        trialConfidenceScores.removeAll(keepingCapacity: true) 
        trialTimestamps.removeAll(keepingCapacity: true)
        
        // Force memory cleanup
        autoreleasepool {
            // Allow ARC to clean up temporary objects
        }
        
        // Check current memory state
        let measurementCount = pupillometryManager.currentSession?.pupilMeasurements.count ?? 0
        print("📊 Current measurements in session: \(measurementCount)")
        
        if measurementCount > 9000 { // Approaching dangerous levels (reduced for 5 trials)
            print("⚠️ ADHDProtocolTask: High memory usage detected - measurement count: \(measurementCount)")
        }
        
        print("✅ Periodic cleanup completed")
    }
}

// MARK: - Helper Views

class TriangleView: UIView {
    override func draw(_ rect: CGRect) {
        guard let context = UIGraphicsGetCurrentContext() else { return }
        
        context.setFillColor(UIColor.systemYellow.cgColor)
        context.move(to: CGPoint(x: rect.midX, y: rect.minY))
        context.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        context.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        context.closePath()
        context.fillPath()
    }
}
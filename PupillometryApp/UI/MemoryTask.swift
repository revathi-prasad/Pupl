//
//  MemoryTask.swift (Enhanced with ChangeLocalizationTask Logic)
//  PupillometryApp
//
//  Created by Revathi Prasad on 10/06/25.
//

import UIKit

protocol MemoryTaskDelegate: AnyObject {
    func memoryTask(_ task: MemoryTask, didStartTrial trial: Int, total: Int)
    func memoryTask(_ task: MemoryTask, didReceiveResponse correct: Bool, reactionTime: TimeInterval)
    func memoryTaskDidComplete(_ task: MemoryTask)
}

class MemoryTask: TaskProtocol {
    
    // Enhanced data structure based on ChangeLocalizationTask
    struct TrialArray {
        let colors: [UIColor]
        let changedIndex: Int
        let originalColor: UIColor
        let newColor: UIColor
        let setSize: Int
        let trialNumber: Int
    }
    
    weak var delegate: MemoryTaskDelegate?
    
    private var gridView: MemoryGridView?
    private var trials: [TrialArray] = []
    private var currentTrial = 0
    private var trialStartTime: TimeInterval = 0
    private var timer: Timer?
    
    // Research-based parameters (reduced for faster testing)
    private let totalTrials = 30 // Reduced from 240 for testing, but still substantial
    private let setSizes = [4, 6, 8] // Different working memory loads
    private let encodingDuration: TimeInterval = 0.5 // 500ms to view array
    private let retentionInterval: TimeInterval = 1.0 // 1000ms delay
    private let responseWindow: TimeInterval = 3.0 // 3 seconds to respond
    
    // Enhanced color palette
    private let availableColors: [UIColor] = [
        .systemRed, .systemGreen, .systemBlue, .systemYellow,
        .systemPurple, .systemOrange, .systemPink, .systemTeal,
        .systemIndigo, .systemBrown
    ]
    
    func generateTrials() {
        print("🎯 MemoryTask: Generating \(totalTrials) trials...")
        trials.removeAll()
        
        for trialNum in 1...totalTrials {
            // Cycle through set sizes for progressive difficulty
            let setSize = setSizes[(trialNum - 1) % setSizes.count]
            
            // Select random colors for this trial
            let shuffledColors = availableColors.shuffled()
            let trialColors = Array(shuffledColors.prefix(setSize))
            
            // Pick which item will change
            let changedIndex = Int.random(in: 0..<setSize)
            let originalColor = trialColors[changedIndex]
            
            // Pick a new color that's different from the original
            let remainingColors = availableColors.filter { $0 != originalColor }
            let newColor = remainingColors.randomElement() ?? .systemGray
            
            let trial = TrialArray(
                colors: trialColors,
                changedIndex: changedIndex,
                originalColor: originalColor,
                newColor: newColor,
                setSize: setSize,
                trialNumber: trialNum
            )
            
            trials.append(trial)
        }
        
        print("✅ MemoryTask: Generated \(trials.count) trials")
    }
    
    func start(with gridView: MemoryGridView) {
        print("🟦 MemoryTask: Starting with research-based protocol")
        self.gridView = gridView
        
        if trials.isEmpty {
            generateTrials()
        }
        
        currentTrial = 0
        presentNextTrial()
    }
    
    func start() {
        // Required by protocol but we use the version with gridView
    }
    
    func stop() {
        print("⏹️ MemoryTask: Stopping task")
        timer?.invalidate()
        timer = nil
    }
    
    private func presentNextTrial() {
        guard currentTrial < trials.count else {
            print("🎯 MemoryTask: All trials completed!")
            delegate?.memoryTaskDidComplete(self)
            return
        }
        
        let trial = trials[currentTrial]
        trialStartTime = CACurrentMediaTime()
        
        print("🔄 MemoryTask: Presenting trial \(trial.trialNumber), set size \(trial.setSize)")
        
        // Notify delegate about trial start
        delegate?.memoryTask(self, didStartTrial: trial.trialNumber, total: totalTrials)
        
        // Configure grid for this trial
        configureMemoryGrid(for: trial)
        
        // Phase 1: Encoding (show array for 500ms)
        print("🟦 MemoryTask: Phase 1 - Encoding (\(encodingDuration)s)")
        
        // Phase 2: Retention interval (blank/mask for 1000ms)
        DispatchQueue.main.asyncAfter(deadline: .now() + encodingDuration) { [weak self] in
            print("🟦 MemoryTask: Phase 2 - Retention interval (\(self?.retentionInterval ?? 1.0)s)")
            self?.showRetentionPhase()
            
            // Phase 3: Test phase (show changed array)
            DispatchQueue.main.asyncAfter(deadline: .now() + (self?.retentionInterval ?? 1.0)) { [weak self] in
                print("🟦 MemoryTask: Phase 3 - Test phase (\(self?.responseWindow ?? 3.0)s)")
                self?.showTestPhase(for: trial)
            }
        }
        
        // Auto-advance timer for the entire trial
        timer = Timer.scheduledTimer(withTimeInterval: encodingDuration + retentionInterval + responseWindow, repeats: false) { [weak self] _ in
            self?.advanceToNextTrial()
        }
    }
    
    private func configureMemoryGrid(for trial: TrialArray) {
        guard let gridView = gridView else { 
            print("❌ MemoryTask: No gridView available!")
            return 
        }
        
        print("🟦 MemoryTask: Configuring grid for trial \(trial.trialNumber) with setSize: \(trial.setSize)")
        
        // Configure grid with the trial's colors for encoding phase
        gridView.configure(with: trial.colors)
    }
    
    private func showRetentionPhase() {
        // Show blank/mask screen during retention interval
        gridView?.showRetentionPhase()
    }
    
    private func showTestPhase(for trial: TrialArray) {
        // Show test array with one color changed
        gridView?.showTestPhase(trial: trial) { [weak self] correct, reactionTime in
            guard let self = self else { return }
            
            print("🟦 MemoryTask: Received response - correct: \(correct), RT: \(reactionTime)")
            
            // Report response to delegate
            self.delegate?.memoryTask(self, didReceiveResponse: correct, reactionTime: reactionTime)
            
            // Advance to next trial
            self.advanceToNextTrial()
        }
    }
    
    private func advanceToNextTrial() {
        timer?.invalidate()
        currentTrial += 1
        
        // Small delay before next trial
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.presentNextTrial()
        }
    }
    
    func recordResponse(selectedIndex: Int) {
        guard currentTrial < trials.count else { return }
        
        let trial = trials[currentTrial]
        let isCorrect = selectedIndex == trial.changedIndex
        let reactionTime = CACurrentMediaTime() - trialStartTime - encodingDuration - retentionInterval
        
        print("👆 MemoryTask: Response - Selected: \(selectedIndex), Correct: \(trial.changedIndex), RT: \(String(format: "%.3f", reactionTime))s")
        
        delegate?.memoryTask(self, didReceiveResponse: isCorrect, reactionTime: reactionTime)
        
        // Immediately move to next trial on response
        advanceToNextTrial()
    }
    
}

class MemoryGridView: UIView {
    private var squares: [UIView] = []
    private var currentTrial: MemoryTask.TrialArray?
    private var responseCallback: ((Bool, TimeInterval) -> Void)?
    private var testPhaseStartTime: TimeInterval = 0
    private var maxSquares = 8 // Support up to 8 squares for different set sizes
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupGrid()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupGrid()
    }
    
    private func setupGrid() {
        // Create adaptive grid that can handle 4, 6, or 8 squares
        let squareSize: CGFloat = 70
        let spacing: CGFloat = 15
        
        // Create maximum of 8 squares arranged in optimal patterns
        for i in 0..<maxSquares {
            let square = UIView()
            square.backgroundColor = .lightGray
            square.layer.borderWidth = 2
            square.layer.borderColor = UIColor.darkGray.cgColor
            square.layer.cornerRadius = 8
            square.isHidden = true // Initially hidden
            
            // Add tap gesture
            let tapGesture = UITapGestureRecognizer(target: self, action: #selector(squareTapped(_:)))
            square.addGestureRecognizer(tapGesture)
            square.isUserInteractionEnabled = false
            square.tag = i
            
            addSubview(square)
            squares.append(square)
        }
    }
    
    private func layoutSquares(for setSize: Int) {
        let squareSize: CGFloat = 70
        let spacing: CGFloat = 15
        
        // Determine grid layout based on set size
        let layout = gridLayoutFor(setSize: setSize)
        
        let totalWidth = CGFloat(layout.columns) * squareSize + CGFloat(layout.columns - 1) * spacing
        let totalHeight = CGFloat(layout.rows) * squareSize + CGFloat(layout.rows - 1) * spacing
        
        let startX = (bounds.width - totalWidth) / 2
        let startY = (bounds.height - totalHeight) / 2
        
        for i in 0..<setSize {
            let row = i / layout.columns
            let col = i % layout.columns
            
            let x = startX + CGFloat(col) * (squareSize + spacing)
            let y = startY + CGFloat(row) * (squareSize + spacing)
            
            squares[i].frame = CGRect(x: x, y: y, width: squareSize, height: squareSize)
            squares[i].isHidden = false
        }
        
        // Hide unused squares
        for i in setSize..<maxSquares {
            squares[i].isHidden = true
        }
    }
    
    private func gridLayoutFor(setSize: Int) -> (rows: Int, columns: Int) {
        switch setSize {
        case 4: return (2, 2)
        case 6: return (2, 3)
        case 8: return (2, 4)
        default: return (2, 2)
        }
    }
    
    func configure(with colors: [UIColor]) {
        print("🔵 MemoryGridView: Encoding phase - showing \(colors.count) colors")
        
        // Layout squares for this set size
        layoutSquares(for: colors.count)
        
        // Show encoding array
        for (i, square) in squares.enumerated() {
            if i < colors.count {
                square.backgroundColor = colors[i]
                square.layer.borderColor = UIColor.darkGray.cgColor
                square.layer.borderWidth = 2
                square.isUserInteractionEnabled = false // No interaction during encoding
                square.transform = .identity
                print("🔵 MemoryGridView: Encoding square \(i) - \(colors[i])")
            }
        }
    }
    
    func showRetentionPhase() {
        print("🔵 MemoryGridView: Retention phase - masking display")
        
        // Hide all squares during retention (blank screen)
        squares.forEach { square in
            if !square.isHidden {
                square.backgroundColor = .darkGray
                square.isUserInteractionEnabled = false
            }
        }
    }
    
    func showTestPhase(trial: MemoryTask.TrialArray, completion: @escaping (Bool, TimeInterval) -> Void) {
        print("🔵 MemoryGridView: Test phase - showing changed array")
        
        currentTrial = trial
        responseCallback = completion
        testPhaseStartTime = CACurrentMediaTime()
        
        // Show test array with one color changed
        for (i, square) in squares.enumerated() {
            if i < trial.colors.count {
                if i == trial.changedIndex {
                    square.backgroundColor = trial.newColor
                    print("🔵 MemoryGridView: Changed square \(i) from \(trial.originalColor) to \(trial.newColor)")
                } else {
                    square.backgroundColor = trial.colors[i]
                }
                
                square.layer.borderColor = UIColor.darkGray.cgColor
                square.layer.borderWidth = 2
                square.isUserInteractionEnabled = true // Enable interaction for test phase
                square.transform = CGAffineTransform(scaleX: 1.05, y: 1.05) // Slight scale for visibility
            }
        }
        
        print("🔵 MemoryGridView: Test phase ready - waiting for user response")
    }
    
    
    @objc private func squareTapped(_ gesture: UITapGestureRecognizer) {
        guard let square = gesture.view,
              let index = squares.firstIndex(of: square),
              let trial = currentTrial,
              let callback = responseCallback else { 
            print("❌ MemoryGridView: Invalid tap state")
            return 
        }
        
        print("🔵 MemoryGridView: Square \(index) tapped!")
        
        // Calculate reaction time from test phase start
        let reactionTime = CACurrentMediaTime() - testPhaseStartTime
        
        // Check if correct square was tapped
        let correct = (index == trial.changedIndex)
        print("🔵 MemoryGridView: Tapped square \(index), changed square was \(trial.changedIndex), correct: \(correct)")
        
        // Visual feedback
        square.layer.borderColor = UIColor.white.cgColor
        square.layer.borderWidth = 4
        square.transform = CGAffineTransform(scaleX: 1.2, y: 1.2)
        
        // Show correct answer if wrong
        if !correct {
            squares[trial.changedIndex].layer.borderColor = UIColor.green.cgColor
            squares[trial.changedIndex].layer.borderWidth = 4
        }
        
        // Disable all interaction
        squares.forEach { $0.isUserInteractionEnabled = false }
        
        // Clear state
        responseCallback = nil
        currentTrial = nil
        
        print("🔵 MemoryGridView: Calling response callback - correct: \(correct), RT: \(String(format: "%.3f", reactionTime))s")
        
        // Brief animation then callback
        UIView.animate(withDuration: 0.2, animations: {
            square.transform = CGAffineTransform(scaleX: 1.05, y: 1.05)
        }) { _ in
            callback(correct, reactionTime)
        }
    }
    
}

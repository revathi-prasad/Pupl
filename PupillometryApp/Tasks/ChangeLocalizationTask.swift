//
//  ChangeLocalizationTask.swift
//  PupillometryApp
//
//  Created by Revathi Prasad on 25/06/25.
//

import UIKit

protocol ChangeLocalizationTaskDelegate: AnyObject {
    func task(_ task: ChangeLocalizationTask, didPresentArray array: ChangeLocalizationTask.TrialArray, at time: TimeInterval)
    func task(_ task: ChangeLocalizationTask, didReceiveResponse correct: Bool, reactionTime: TimeInterval, selectedIndex: Int)
    func taskDidComplete(_ task: ChangeLocalizationTask)
}

class ChangeLocalizationTask {
    
    struct TrialArray {
        let colors: [UIColor]
        let changedIndex: Int
        let originalColor: UIColor
        let newColor: UIColor
        let setSize: Int
        let trialNumber: Int
    }
    
    weak var delegate: ChangeLocalizationTaskDelegate?
    
    private var trials: [TrialArray] = []
    private var currentTrial = 0
    private var trialStartTime: TimeInterval = 0
    private var timer: Timer?
    
    // Task parameters based on change localization research
    private let totalTrials = 240 // 8 minutes at ~2 seconds per trial
    private let setSizes = [4, 6, 8] // Different working memory loads
    private let encodingDuration: TimeInterval = 0.5 // 500ms to view array
    private let retentionInterval: TimeInterval = 1.0 // 1000ms delay
    private let responseWindow: TimeInterval = 3.0 // 3 seconds to respond
    
    // Color palette for stimuli
    private let availableColors: [UIColor] = [
        .systemRed, .systemGreen, .systemBlue, .systemYellow,
        .systemPurple, .systemOrange, .systemPink, .systemTeal,
        .systemIndigo, .systemBrown
    ]
    
    func generateTrials() {
        print("🎯 ChangeLocalizationTask: Generating \(totalTrials) trials...")
        
        for trialNum in 1...totalTrials {
            // Cycle through set sizes
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
        
        print("✅ ChangeLocalizationTask: Generated \(trials.count) trials")
    }
    
    func start() {
        if trials.isEmpty {
            generateTrials()
        }
        
        print("🚀 ChangeLocalizationTask: Starting task with \(trials.count) trials")
        currentTrial = 0
        presentNextTrial()
    }
    
    private func presentNextTrial() {
        guard currentTrial < trials.count else {
            print("🎯 ChangeLocalizationTask: All trials completed!")
            delegate?.taskDidComplete(self)
            return
        }
        
        let trial = trials[currentTrial]
        trialStartTime = CACurrentMediaTime()
        
        print("🔄 ChangeLocalizationTask: Presenting trial \(trial.trialNumber), set size \(trial.setSize)")
        
        // Present the array to the delegate
        delegate?.task(self, didPresentArray: trial, at: trialStartTime)
        
        // Schedule next trial after response window
        timer = Timer.scheduledTimer(withTimeInterval: encodingDuration + retentionInterval + responseWindow, repeats: false) { [weak self] _ in
            self?.currentTrial += 1
            self?.presentNextTrial()
        }
    }
    
    func recordResponse(selectedIndex: Int) {
        guard currentTrial < trials.count else { return }
        
        let trial = trials[currentTrial]
        let isCorrect = selectedIndex == trial.changedIndex
        let reactionTime = CACurrentMediaTime() - trialStartTime - encodingDuration - retentionInterval
        
        print("👆 ChangeLocalizationTask: Response - Selected: \(selectedIndex), Correct: \(trial.changedIndex), RT: \(String(format: "%.3f", reactionTime))s")
        
        delegate?.task(self, didReceiveResponse: isCorrect, reactionTime: reactionTime, selectedIndex: selectedIndex)
        
        // Immediately move to next trial on response
        timer?.invalidate()
        currentTrial += 1
        
        // Small delay before next trial
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.presentNextTrial()
        }
    }
    
    func stop() {
        print("⏹️ ChangeLocalizationTask: Stopping task")
        timer?.invalidate()
        timer = nil
    }
    
    // Helper method to get current trial info
    func getCurrentTrialInfo() -> (trialNumber: Int, setSize: Int, totalTrials: Int)? {
        guard currentTrial < trials.count else { return nil }
        let trial = trials[currentTrial]
        return (trial.trialNumber, trial.setSize, totalTrials)
    }
}

// MARK: - TaskProtocol Conformance
extension ChangeLocalizationTask: TaskProtocol {
    // start() and stop() methods already implemented above
}
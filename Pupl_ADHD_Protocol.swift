// Pupl ADHD Diagnosis Task (iOS Swift Implementation)
// Includes CSV Export, Progress Tracking, Load Variation, Block Structure, Full Dot-Array Presentation, Probe Logic, and Haptic Feedback

import UIKit
import AVFoundation
import UniformTypeIdentifiers
import AudioToolbox

class ADHDMemoryTaskViewController: UIViewController {

    // === MARK: UI ELEMENTS ===
    var gridView: UIView!
    var fixationLabel: UILabel!
    var yesButton: UIButton!
    var noButton: UIButton!
    var feedbackLabel: UILabel!
    var distractorImageView: UIImageView!
    var instructionLabel: UILabel!
    var startButton: UIButton!
    var progressLabel: UILabel!
    var blockLabel: UILabel!
    var breakLabel: UILabel!
    var continueButton: UIButton!

    // === MARK: TASK VARIABLES ===
    let gridSize = 4
    let dotSize: CGFloat = 20
    var gridCells: [CGRect] = []
    var memoryDots: [CGPoint] = []
    var currentProbe: CGPoint = .zero
    var trialTimer: Timer?
    var trialStep = 0
    var dotArrays: [[CGPoint]] = []
    let trialsPerBlock = 20
    let totalBlocks = 8
    var currentBlock = 1
    var isHighLoad = false
    var probeIsTarget = false
    var currentDotArrayIndex = 0

    // === MARK: TIMING (in seconds) ===
    let fixationTime: TimeInterval = 0.5
    let dotTime: TimeInterval = 0.75
    let delayTime: TimeInterval = 0.5
    let distractorTime: TimeInterval = 0.5
    let probeTime: TimeInterval = 1.5
    let feedbackTime: TimeInterval = 1.5

    // === MARK: DISTRACTOR IMAGES ===
    var neutralImages: [UIImage] = []
    var emotionalImages: [UIImage] = []

    // === MARK: LOGGING ===
    var trialStartTime: Date?
    var responseTime: TimeInterval = 0.0
    var responseLog: [(block: Int, trial: Int, correct: Bool, rt: TimeInterval, probe: CGPoint, distractorType: String, load: String)] = []
    var trialCount = 0
    var currentDistractorType: String = "none"

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        loadDistractorImages()
        prepareGrid()
    }

    func prepareGrid() {
        gridCells.removeAll()
        let cellWidth = gridView.frame.width / CGFloat(gridSize)
        let cellHeight = gridView.frame.height / CGFloat(gridSize)
        for row in 0..<gridSize {
            for col in 0..<gridSize {
                let rect = CGRect(x: CGFloat(col) * cellWidth, y: CGFloat(row) * cellHeight, width: cellWidth, height: cellHeight)
                gridCells.append(rect)
            }
        }
    }

    func generateDotArray() -> [CGPoint] {
        let dotCount = isHighLoad ? 2 : 1
        return Array(gridCells.shuffled().prefix(dotCount)).map { CGPoint(x: $0.midX, y: $0.midY) }
    }

    func setupTrialLoad() {
        isHighLoad = Bool.random()
    }

    @objc func startTrial() {
        setupTrialLoad()
        trialCount += 1
        updateProgress()
        memoryDots.removeAll()
        dotArrays.removeAll()
        currentDotArrayIndex = 0

        for _ in 0..<3 {
            let dots = generateDotArray()
            dotArrays.append(dots)
            memoryDots.append(contentsOf: dots)
        }

        showFixationThenNextDotArray()
    }

    func showFixationThenNextDotArray() {
        clearGrid()
        fixationLabel.isHidden = false
        trialTimer = Timer.scheduledTimer(withTimeInterval: fixationTime, repeats: false) { _ in
            self.fixationLabel.isHidden = true
            self.showNextDotArray()
        }
    }

    func showNextDotArray() {
        guard currentDotArrayIndex < dotArrays.count else {
            self.showDistractorImage()
            return
        }

        showDots(dotArrays[currentDotArrayIndex])
        currentDotArrayIndex += 1
        trialTimer = Timer.scheduledTimer(withTimeInterval: dotTime, repeats: false) { _ in
            self.clearGrid()
            self.trialTimer = Timer.scheduledTimer(withTimeInterval: self.delayTime, repeats: false) { _ in
                self.showNextDotArray()
            }
        }
    }

    func showDots(_ dots: [CGPoint]) {
        for dot in dots {
            let dotView = UIView(frame: CGRect(x: dot.x - dotSize/2, y: dot.y - dotSize/2, width: dotSize, height: dotSize))
            dotView.backgroundColor = .white
            dotView.layer.cornerRadius = dotSize / 2
            gridView.addSubview(dotView)
        }
    }

    func clearGrid() {
        gridView.subviews.forEach { $0.removeFromSuperview() }
    }

    func showDistractorImage() {
        distractorImageView.isHidden = false
        currentDistractorType = ["task", "neutral", "emotional", "none"].randomElement() ?? "none"
        switch currentDistractorType {
        case "neutral": distractorImageView.image = neutralImages.randomElement()
        case "emotional": distractorImageView.image = emotionalImages.randomElement()
        default: distractorImageView.image = nil
        }
        trialTimer = Timer.scheduledTimer(withTimeInterval: distractorTime, repeats: false) { _ in
            self.distractorImageView.isHidden = true
            self.showProbe()
        }
    }

    func showProbe() {
        trialStartTime = Date()
        yesButton.isHidden = false
        noButton.isHidden = false

        probeIsTarget = Bool.random()
        if probeIsTarget, let match = memoryDots.randomElement() {
            currentProbe = match
        } else {
            let lure = gridCells.map { CGPoint(x: $0.midX, y: $0.midY) }.filter { !memoryDots.contains($0) }.randomElement() ?? .zero
            currentProbe = lure
        }

        showDots([currentProbe])
        trialTimer = Timer.scheduledTimer(withTimeInterval: probeTime, repeats: false) { _ in
            self.endTrial(correct: false) // No response = incorrect
        }
    }

    @objc func responseButtonTapped(_ sender: UIButton) {
        trialTimer?.invalidate()

        // ✅ Haptic feedback only
        let impact = UIImpactFeedbackGenerator(style: .light)
        impact.impactOccurred()

        let userSaidYes = (sender == yesButton)
        let correct = (userSaidYes == probeIsTarget)
        endTrial(correct: correct)
    }

    func endTrial(correct: Bool) {
        logTrial(correct: correct, probe: currentProbe)
        yesButton.isHidden = true
        noButton.isHidden = true
        clearGrid()

        trialTimer = Timer.scheduledTimer(withTimeInterval: feedbackTime, repeats: false) { _ in
            if self.trialCount >= self.trialsPerBlock {
                self.currentBlock += 1
                if self.currentBlock > self.totalBlocks {
                    self.instructionLabel.text = "Experiment Complete!"
                } else {
                    self.trialCount = 0
                    self.breakLabel.text = "Take a short break. Tap Continue to start next block."
                    self.breakLabel.isHidden = false
                    self.continueButton.isHidden = false
                }
            } else {
                self.startTrial()
            }
        }
    }

    func updateProgress() {
        progressLabel.text = "Trial \(trialCount) of \(trialsPerBlock)"
        blockLabel.text = "Block \(currentBlock) of \(totalBlocks) — \(isHighLoad ? "High Load" : "Low Load")"
    }

    func logTrial(correct: Bool, probe: CGPoint) {
        let rt = Date().timeIntervalSince(trialStartTime ?? Date())
        responseLog.append((block: currentBlock, trial: trialCount, correct: correct, rt: rt, probe: probe, distractorType: currentDistractorType, load: isHighLoad ? "high" : "low"))
    }

    @objc func exportCSV() {
        let header = "Block,Trial,Correct,RT,ProbeX,ProbeY,DistractorType,Load\n"
        let rows = responseLog.map { "\($0.block),\($0.trial),\($0.correct),\($0.rt),\($0.probe.x),\($0.probe.y),\($0.distractorType),\($0.load)" }
        let csv = header + rows.joined(separator: "\n")
        let fileName = "adhd_results.csv"
        let path = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        try? csv.write(to: path, atomically: true, encoding: .utf8)

        let activityVC = UIActivityViewController(activityItems: [path], applicationActivities: nil)
        present(activityVC, animated: true, completion: nil)
    }
}

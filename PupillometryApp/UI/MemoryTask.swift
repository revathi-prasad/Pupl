//
//  MemoryTask.swift
//  PupillometryApp
//
//  Created by Revathi Prasad on 10/06/25.
//

//import UIKit
//
//class MemoryTask: NSObject {
//
//}

// MemoryTask.swift
import UIKit

protocol MemoryTaskDelegate: AnyObject {
    func memoryTask(_ task: MemoryTask, didStartTrial trial: Int, total: Int)
    func memoryTask(_ task: MemoryTask, didReceiveResponse correct: Bool, reactionTime: TimeInterval)
    func memoryTaskDidComplete(_ task: MemoryTask)
}

protocol TaskProtocol {
    func start()
    func stop()
}

class MemoryTask: TaskProtocol {
    weak var delegate: MemoryTaskDelegate?
    
    private var gridView: MemoryGridView?
    private var currentTrial = 0
    private var totalTrials = 10 // Reduced for initial testing
    private var trialStartTime: TimeInterval = 0
    private var timer: Timer?
    
    private let colors: [UIColor] = [
        .systemRed, .systemGreen, .systemBlue,
        .systemYellow, .systemPurple, .systemCyan
    ]
    
    func start(with gridView: MemoryGridView) {
        print("🟦 MemoryTask: Starting with gridView")
        self.gridView = gridView
        currentTrial = 0
        
        // Add a small delay to ensure the view is properly set up
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            guard let self = self else { return }
            print("🟦 MemoryTask: Starting first trial after delay")
            self.startNextTrial()
        }
    }
    
    func start() {
        // Required by protocol but we use the version with gridView
    }
    
    func stop() {
        timer?.invalidate()
        timer = nil
    }
    
    private func startNextTrial() {
        print("🟦 MemoryTask: startNextTrial() - currentTrial: \(currentTrial), totalTrials: \(totalTrials)")
        
        guard currentTrial < totalTrials else {
            print("🟦 MemoryTask: All trials completed!")
            delegate?.memoryTaskDidComplete(self)
            return
        }
        
        currentTrial += 1
        print("🟦 MemoryTask: Starting trial \(currentTrial)/\(totalTrials)")
        delegate?.memoryTask(self, didStartTrial: currentTrial, total: totalTrials)
        
        // Configure grid for current trial
        configureMemoryGrid()
        
        // Show array briefly
        trialStartTime = CACurrentMediaTime()
        print("🟦 MemoryTask: Showing initial array for 1.5 seconds")
        
        // Schedule test phase
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            print("🟦 MemoryTask: Showing mask")
            self?.showMask()
            
            // After mask, show test array
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                print("🟦 MemoryTask: Showing test array - waiting for user response")
                self?.showTestArray()
            }
        }
    }
    
    private func configureMemoryGrid() {
        guard let gridView = gridView else { 
            print("❌ MemoryTask: No gridView available!")
            return 
        }
        
        // Determine set size based on trial progression
        var setSize = 6
        if currentTrial <= 60 {
            setSize = 2
        } else if currentTrial <= 120 {
            setSize = 4
        }
        
        print("🟦 MemoryTask: Configuring grid with setSize: \(setSize)")
        
        // Generate random colors for squares
        var squareColors: [UIColor] = []
        for i in 0..<setSize {
            if let color = colors.randomElement() {
                squareColors.append(color)
                print("🟦 MemoryTask: Square \(i): \(color)")
            }
        }
        
        print("🟦 MemoryTask: Calling gridView.configure() with \(squareColors.count) colors")
        gridView.configure(with: squareColors)
    }
    
    private func showMask() {
        // Show masking pattern
        gridView?.showMask()
    }
    
    private func showTestArray() {
        // Show test array with one changed color
        gridView?.showTestArray { [weak self] correct, reactionTime in
            guard let self = self else { 
                print("❌ MemoryTask: Self deallocated in showTestArray callback")
                return 
            }
            
            print("🟦 MemoryTask: Received response - correct: \(correct), RT: \(reactionTime)")
            
            // Report response
            self.delegate?.memoryTask(self, didReceiveResponse: correct, reactionTime: reactionTime)
            
            // Schedule next trial immediately - don't wait
            print("🟦 MemoryTask: Starting next trial immediately")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                guard let self = self else { return }
                print("🟦 MemoryTask: Starting next trial now")
                self.startNextTrial()
            }
        }
    }
}

class MemoryGridView: UIView {
    private var squares: [UIView] = []
    private var initialColors: [UIColor] = []
    private var testColors: [UIColor] = []
    private var changedIndex: Int = 0
    private var responseCallback: ((Bool, TimeInterval) -> Void)?
    private var presentationTime: TimeInterval = 0
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupGrid()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupGrid()
    }
    
    private func setupGrid() {
        // Create 3x2 grid of squares
        let squareSize: CGFloat = 80
        let spacing: CGFloat = 20
        
        for row in 0..<2 {
            for col in 0..<3 {
                let x = CGFloat(col) * (squareSize + spacing)
                let y = CGFloat(row) * (squareSize + spacing)
                
                let square = UIView(frame: CGRect(x: x, y: y, width: squareSize, height: squareSize))
                square.backgroundColor = .lightGray
                square.layer.borderWidth = 2
                square.layer.borderColor = UIColor.darkGray.cgColor
                
                // Add tap gesture
                let tapGesture = UITapGestureRecognizer(target: self, action: #selector(squareTapped(_:)))
                square.addGestureRecognizer(tapGesture)
                square.isUserInteractionEnabled = true
                
                addSubview(square)
                squares.append(square)
            }
        }
    }
    
    func configure(with colors: [UIColor]) {
        print("🔵 MemoryGridView: configure() called with \(colors.count) colors")
        initialColors = colors
        
        // Reset squares
        for (i, square) in squares.enumerated() {
            if i < colors.count {
                square.backgroundColor = colors[i]
                square.layer.borderColor = UIColor.darkGray.cgColor
                square.layer.borderWidth = 2
                square.isUserInteractionEnabled = false // Disabled during initial display
                square.isHidden = false
                print("🔵 MemoryGridView: Square \(i) set to color \(colors[i]), interaction disabled")
            } else {
                square.isHidden = true
                print("🔵 MemoryGridView: Square \(i) hidden")
            }
        }
    }
    
    func showMask() {
        print("🔵 MemoryGridView: showMask() called")
        // Show masking pattern
        for (i, square) in squares.enumerated() {
            if !square.isHidden {
                square.backgroundColor = .darkGray
                square.isUserInteractionEnabled = false
                print("🔵 MemoryGridView: Square \(i) masked")
            }
        }
    }
    
    func showTestArray(completion: @escaping (Bool, TimeInterval) -> Void) {
        print("🔵 MemoryGridView: showTestArray() called")
        
        // Create test colors with one change
        testColors = initialColors
        
        // Select random square to change
        changedIndex = Int.random(in: 0..<initialColors.count)
        print("🔵 MemoryGridView: Will change square \(changedIndex) from \(initialColors[changedIndex])")
        
        // Pick a different color - fix the potential infinite loop
        let availableColors = colors.filter { $0 != initialColors[changedIndex] }
        guard !availableColors.isEmpty else {
            print("❌ MemoryGridView: No available colors for change!")
            return
        }
        
        let newColor = availableColors.randomElement()!
        testColors[changedIndex] = newColor
        print("🔵 MemoryGridView: Changed square \(changedIndex) to \(newColor)")
        
        // Display test array
        for (i, square) in squares.enumerated() {
            if i < testColors.count {
                square.backgroundColor = testColors[i]
                square.isUserInteractionEnabled = true // ENABLE interaction for test phase!
                square.isHidden = false
                square.layer.borderColor = UIColor.darkGray.cgColor
                square.layer.borderWidth = 2
                print("🔵 MemoryGridView: Square \(i) enabled for interaction")
            } else {
                square.isHidden = true
            }
        }
        
        // Store callback and presentation time
        responseCallback = completion
        presentationTime = CACurrentMediaTime()
        print("🔵 MemoryGridView: Test array displayed, waiting for user tap")
    }
    
    @objc private func squareTapped(_ gesture: UITapGestureRecognizer) {
        guard let square = gesture.view, let index = squares.firstIndex(of: square) else { 
            print("❌ MemoryGridView: Invalid tap gesture")
            return 
        }
        
        print("🔵 MemoryGridView: Square \(index) tapped!")
        
        // Calculate reaction time
        let reactionTime = CACurrentMediaTime() - presentationTime
        
        // Check if correct square was tapped
        let correct = (index == changedIndex)
        print("🔵 MemoryGridView: Tapped square \(index), changed square was \(changedIndex), correct: \(correct)")
        
        // Highlight selected square
        square.layer.borderColor = UIColor.white.cgColor
        square.layer.borderWidth = 4
        
        // Show correct answer briefly
        if !correct {
            squares[changedIndex].layer.borderColor = UIColor.green.cgColor
            squares[changedIndex].layer.borderWidth = 4
        }
        
        // Disable interaction
        squares.forEach { $0.isUserInteractionEnabled = false }
        
        print("🔵 MemoryGridView: Calling response callback")
        
        // Store callback temporarily to avoid clearing it before calling
        let callback = responseCallback
        responseCallback = nil
        
        // Call completion on main queue
        DispatchQueue.main.async {
            callback?(correct, reactionTime)
        }
    }
    
    private let colors: [UIColor] = [
        .systemRed, .systemGreen, .systemBlue,
        .systemYellow, .systemPurple, .systemCyan
    ]
}

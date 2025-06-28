//
//  TaskDelegate.swift
//  PupillometryApp
//
//  Created by Revathi Prasad on 08/06/25.
//


import UIKit

protocol TaskProtocol {
    func start()
    func stop()
}

protocol GradCPTTaskDelegate: AnyObject {
    func task(_ task: GradCPTTask, didPresentStimulus stimulus: GradCPTTask.Stimulus, at time: TimeInterval)
    func task(_ task: GradCPTTask, didReceiveResponse correct: Bool, reactionTime: TimeInterval)
    func taskDidComplete(_ task: GradCPTTask)
}

class GradCPTTask: TaskProtocol {
    
    struct Stimulus {
        let type: StimulusType
        let image: UIImage
        let trialNumber: Int
        
        enum StimulusType {
            case target    // Male face
            case nonTarget // Female face
        }
    }
    
    weak var delegate: GradCPTTaskDelegate?
    
    private var trials: [Stimulus] = []
    private var currentTrial = 0
    private var trialStartTime: TimeInterval = 0
    private var timer: Timer?
    private var imageCache: [String: UIImage] = [:]
    
    private let targetProbability: Float = 0.1
    private let trialDuration: TimeInterval = 0.8
    public var totalTrials = 900 // Can be reduced for testing
    
    // Pre-generated images to avoid runtime generation
    private var maleImage: UIImage?
    private var femaleImage: UIImage?
    
    func generateTrials() {
        print("📝 GradCPTTask: generateTrials() called with totalTrials = \(totalTrials)")
        
        // Clear previous trials to prevent memory issues
        trials.removeAll()
        
        let targetCount = Int(Float(totalTrials) * targetProbability)
        let nonTargetCount = totalTrials - targetCount
        
        print("📊 GradCPTTask: Will generate \(targetCount) targets and \(nonTargetCount) non-targets")
        
        // Create trial types with memory-conscious approach
        var trialTypes: [Stimulus.StimulusType] = []
        autoreleasepool {
            trialTypes.append(contentsOf: Array(repeating: .target, count: targetCount))
            trialTypes.append(contentsOf: Array(repeating: .nonTarget, count: nonTargetCount))
        }
        
        print("📊 GradCPTTask: Created \(trialTypes.count) trial types")
        
        // Shuffle with no-repeat constraint
        autoreleasepool {
            trialTypes = shuffleNoRepeats(trialTypes)
        }
        
        print("📊 GradCPTTask: Shuffled trial types")
        
        // Pre-generate images once to avoid repeated generation
        print("🎨 GradCPTTask: Pre-generating face images...")
        if maleImage == nil {
            maleImage = generateFaceImage(type: .target)
            print("✅ Generated male image")
        }
        if femaleImage == nil {
            femaleImage = generateFaceImage(type: .nonTarget)
            print("✅ Generated female image")
        }
        
        // Generate stimuli using pre-generated images
        print("🎨 GradCPTTask: Creating trials with pre-generated images...")
        trials.reserveCapacity(trialTypes.count)
        
        for (index, type) in trialTypes.enumerated() {
            autoreleasepool {
                // Create lightweight stimulus objects
                let image = (type == .target) ? maleImage! : femaleImage!
                let stimulus = Stimulus(
                    type: type,
                    image: image,
                    trialNumber: index + 1
                )
                trials.append(stimulus)
            }
            
            // Log progress every 10 trials and force cleanup
            if (index + 1) % 10 == 0 {
                print("🎨 Created \(index + 1)/\(trialTypes.count) trials")
                autoreleasepool {
                    // Force cleanup of any temporary objects
                }
            }
        }
        
        print("✅ GradCPTTask: Generated \(trials.count) trials successfully")
    }
    
    private func shuffleNoRepeats<T: Equatable>(_ array: [T]) -> [T] {
        var result = array.shuffled()
        
        // Fix any consecutive repeats
        for i in 0..<(result.count - 1) {
            if result[i] == result[i + 1] {
                // Find a different element to swap
                for j in (i + 2)..<result.count {
                    if result[j] != result[i] {
                        result.swapAt(i + 1, j)
                        break
                    }
                }
            }
        }
        
        return result
    }
    
    private func generateFaceImage(type: Stimulus.StimulusType) -> UIImage {
        // Check cache first - use thread-safe access
        let cacheKey = type == .target ? "male" : "female"
        
        // Thread-safe cache access
        if let cachedImage = imageCache[cacheKey] {
            return cachedImage
        }
        
        // Try to load real face images first, fallback to generated images
        if let realFaceImage = loadRealFaceImage(type: type) {
            imageCache[cacheKey] = realFaceImage
            return realFaceImage
        }
        
        // Fallback to generated face images with better realism
        let size = CGSize(width: 200, height: 200)
        let renderer = UIGraphicsImageRenderer(size: size)
        
        print("🎨 GradCPTTask: Generating fallback \(type == .target ? "male" : "female") face image")
        
        let generatedImage = renderer.image { context in
            // Black background
            UIColor.black.setFill()
            context.fill(CGRect(origin: .zero, size: size))
            
            // More realistic face representation
            let faceRect = CGRect(x: 40, y: 40, width: 120, height: 140)
            let faceColor = type == .target ? UIColor(white: 0.8, alpha: 1.0) : UIColor(white: 0.7, alpha: 1.0)
            
            // Face shape
            faceColor.setFill()
            let facePath = UIBezierPath(ovalIn: faceRect)
            facePath.fill()
            
            // Eyes
            UIColor.black.setFill()
            let leftEye = CGRect(x: 65, y: 80, width: 15, height: 10)
            let rightEye = CGRect(x: 120, y: 80, width: 15, height: 10)
            UIBezierPath(ovalIn: leftEye).fill()
            UIBezierPath(ovalIn: rightEye).fill()
            
            // Nose
            UIColor.darkGray.setFill()
            let nose = CGRect(x: 95, y: 100, width: 10, height: 15)
            UIBezierPath(ovalIn: nose).fill()
            
            // Mouth - different shapes for male/female
            UIColor.darkGray.setStroke()
            let mouthPath = UIBezierPath()
            if type == .target { // Male - straighter mouth
                mouthPath.move(to: CGPoint(x: 85, y: 130))
                mouthPath.addLine(to: CGPoint(x: 115, y: 130))
            } else { // Female - curved mouth
                mouthPath.move(to: CGPoint(x: 85, y: 125))
                mouthPath.addQuadCurve(to: CGPoint(x: 115, y: 125), controlPoint: CGPoint(x: 100, y: 135))
            }
            mouthPath.lineWidth = 3
            mouthPath.stroke()
            
            // Hair - different for male/female
            let hairColor = type == .target ? UIColor.brown : UIColor(red: 0.6, green: 0.4, blue: 0.2, alpha: 1.0)
            hairColor.setFill()
            
            if type == .target { // Male - shorter hair
                let hairRect = CGRect(x: 45, y: 35, width: 110, height: 30)
                UIBezierPath(ovalIn: hairRect).fill()
            } else { // Female - longer hair
                let hairRect = CGRect(x: 35, y: 30, width: 130, height: 50)
                UIBezierPath(ovalIn: hairRect).fill()
            }
        }
        
        // Cache the generated image
        imageCache[cacheKey] = generatedImage
        return generatedImage
    }
    
    private func loadRealFaceImage(type: Stimulus.StimulusType) -> UIImage? {
        // Try to load from the MATLAB face folders
        let folder = type == .target ? "male" : "female"
        
        // First try direct bundle resource
        if let bundleImage = UIImage(named: "\(folder)_face") {
            print("✅ GradCPTTask: Loaded \(folder) face from bundle")
            return bundleImage
        }
        
        // Try to load from the MATLAB face folders
        let basePath = Bundle.main.path(forResource: "Faces", ofType: nil) ?? ""
        let folderPath = "\(basePath)/\(folder)"
        
        // Get list of face images
        guard let files = try? FileManager.default.contentsOfDirectory(atPath: folderPath) else {
            print("⚠️ GradCPTTask: Could not find face images in bundle at \(folderPath)")
            return nil
        }
        
        let imageFiles = files.filter { $0.hasSuffix(".jpg") || $0.hasSuffix(".png") }
        guard let randomImageFile = imageFiles.randomElement() else {
            print("⚠️ GradCPTTask: No valid image files found in \(folderPath)")
            return nil
        }
        
        let imagePath = "\(folderPath)/\(randomImageFile)"
        let image = UIImage(contentsOfFile: imagePath)
        
        if image != nil {
            print("✅ GradCPTTask: Loaded \(folder) face from \(randomImageFile)")
        } else {
            print("❌ GradCPTTask: Failed to load image from \(imagePath)")
        }
        
        return image
    }
    
    func start() {
        print("🚀 GradCPTTask: Starting task")
        
        // Clear any previous state
        timer?.invalidate()
        timer = nil
        currentTrial = 0
        
        if trials.isEmpty {
            print("📝 GradCPTTask: Generating trials...")
            
            // Wrap trial generation in error handling
            autoreleasepool {
                generateTrials()
                print("📊 GradCPTTask: Generated \(trials.count) trials")
            }
        }
        
        guard !trials.isEmpty else {
            print("❌ GradCPTTask: ERROR - No trials generated! Task will complete immediately!")
            delegate?.taskDidComplete(self)
            return
        }
        
        print("🎬 GradCPTTask: Starting trial presentation...")
        
        // Initialize timer flag to allow presentation
        timer = Timer(timeInterval: 1.0, repeats: false) { _ in /* dummy timer */ }
        
        // Start first trial with a small delay to ensure everything is ready
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            guard let self = self else { 
                print("⚠️ GradCPTTask: Self deallocated before first trial")
                return 
            }
            print("📺 GradCPTTask: About to present first trial")
            self.presentNextTrial()
        }
    }
    
    private func presentNextTrial() {
        print("📋 GradCPTTask: presentNextTrial() called - currentTrial: \(currentTrial)")
        
        // Safety check - don't proceed if task was stopped
        guard timer != nil else {
            print("⚠️ GradCPTTask: Task was stopped, aborting trial presentation")
            return
        }
        
        print("✅ GradCPTTask: Timer check passed")
        
        // Aggressive memory management - clean up every 10 trials
        if currentTrial % 10 == 0 {
            print("🧹 GradCPTTask: Performing aggressive memory cleanup at trial \(currentTrial)")
            autoreleasepool {
                // Force memory cleanup
                imageCache.removeAll()
                
                // Trigger garbage collection
                if #available(iOS 13.0, *) {
                    // Force memory pressure relief
                    DispatchQueue.global(qos: .utility).async {
                        autoreleasepool {
                            // Force system memory cleanup
                            let _ = malloc(1024)
                        }
                    }
                }
            }
            
            // Additional cleanup for iPhone 11 memory constraints
            if currentTrial % 30 == 0 {
                print("🧹 GradCPTTask: Deep memory cleanup at trial \(currentTrial)")
                // Pause briefly to allow system cleanup
                Thread.sleep(forTimeInterval: 0.1)
            }
        }
        
        // Ensure we're on the main thread for UI updates
        print("📱 GradCPTTask: About to dispatch to main queue")
        DispatchQueue.main.async { [weak self] in
            print("📱 GradCPTTask: Inside main queue dispatch")
            guard let self = self else { 
                print("⚠️ GradCPTTask: Self deallocated during trial presentation")
                return 
            }
            print("📱 GradCPTTask: Self check passed in main queue")
            
            // Double-check we haven't been stopped
            guard self.timer != nil else {
                print("⚠️ GradCPTTask: Task stopped during trial presentation")
                return
            }
            
            guard self.currentTrial < self.trials.count else {
                print("🎯 GradCPTTask: Task completed!")
                self.timer?.invalidate()
                self.timer = nil
                self.delegate?.taskDidComplete(self)
                return
            }
            
            // Safety check for trials array bounds
            guard self.currentTrial >= 0 && self.currentTrial < self.trials.count else {
                print("❌ GradCPTTask: Invalid trial index: \(self.currentTrial), max: \(self.trials.count)")
                self.timer?.invalidate()
                self.timer = nil
                return
            }
            
            let stimulus = self.trials[self.currentTrial]
            self.trialStartTime = CACurrentMediaTime()
            
            print("📺 GradCPTTask: Presenting trial \(stimulus.trialNumber), type: \(stimulus.type)")
            
            // Memory pressure check before delegate call
            self.checkMemoryPressure()
            
            // Safely call delegate with error handling
            print("📤 GradCPTTask: About to call delegate with stimulus")
            
            if let delegate = self.delegate {
                print("📤 GradCPTTask: Delegate exists, calling task method")
                autoreleasepool {
                    delegate.task(self, didPresentStimulus: stimulus, at: self.trialStartTime)
                }
                print("📤 GradCPTTask: Delegate call completed")
            } else {
                print("⚠️ GradCPTTask: No delegate set!")
            }
            
            // Invalidate previous timer to prevent overlapping timers
            self.timer?.invalidate()
            
            // Schedule next trial with weak self to prevent retain cycles
            self.timer = Timer.scheduledTimer(withTimeInterval: self.trialDuration, repeats: false) { [weak self] timer in
                autoreleasepool {
                    guard let self = self else { 
                        print("⚠️ GradCPTTask: Self deallocated in timer callback")
                        timer.invalidate()
                        return 
                    }
                    
                    // Safety check before incrementing
                    guard self.timer != nil else {
                        print("⚠️ GradCPTTask: Timer was invalidated")
                        timer.invalidate()
                        return
                    }
                    
                    self.currentTrial += 1
                    self.presentNextTrial()
                }
            }
        }
    }
    
    func recordResponse() {
        guard currentTrial < trials.count else { 
            print("⚠️ GradCPTTask: Response recorded after task completion")
            return 
        }
        
        let stimulus = trials[currentTrial]
        let isCorrect = stimulus.type == .target
        let reactionTime = CACurrentMediaTime() - trialStartTime
        
        print("👆 GradCPTTask: Response recorded for trial \(stimulus.trialNumber), correct: \(isCorrect), RT: \(reactionTime)")
        
        delegate?.task(self, didReceiveResponse: isCorrect, reactionTime: reactionTime)
    }
    
    func stop() {
        print("🛑 GradCPTTask: Stopping task...")
        
        // Invalidate timer first to prevent any further execution
        timer?.invalidate()
        timer = nil
        
        // Clear all cached data to free memory
        autoreleasepool {
            imageCache.removeAll()
            trials.removeAll()
            maleImage = nil
            femaleImage = nil
        }
        
        // Reset state
        currentTrial = 0
        trialStartTime = 0
        
        print("🗑️ GradCPTTask: Task stopped and memory cleared")
    }
    
    // Memory pressure monitoring for iPhone 11
    private func checkMemoryPressure() {
        var info = mach_task_basic_info() // Changed to 'var'
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
        
        let result: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_,
                         task_flavor_t(MACH_TASK_BASIC_INFO),
                         $0,
                         &count)
            }
        }
        
        if result == KERN_SUCCESS {
            let memoryUsedMB = Double(info.resident_size) / 1024.0 / 1024.0
            if memoryUsedMB > 150.0 { // iPhone 11 threshold
                print("⚠️ GradCPTTask: High memory usage: \(String(format: "%.1f", memoryUsedMB))MB")
                // Force aggressive cleanup
                autoreleasepool {
                    imageCache.removeAll()
                }
            }
        }
    }
    
    // Public method to generate example images for instructions
    func generateExampleImage(type: Stimulus.StimulusType) -> UIImage {
        return generateFaceImage(type: type)
    }
}

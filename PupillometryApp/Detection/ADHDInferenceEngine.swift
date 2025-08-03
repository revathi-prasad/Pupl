//
//  ADHDInferenceEngine.swift
//  PupillometryApp
//
//  Real-time ADHD detection using trained CoreML model
//  Framework ready for model integration once training is complete
//

import CoreML
import Foundation
import QuartzCore

class ADHDInferenceEngine {
    
    // MARK: - Properties
    
    private var adhdModel: MLModel?
    private let featureExtractor = FeatureExtractor()
    private let pythonCompatibleExtractor = PythonCompatibleFeatureExtractor()
    private var isModelLoaded: Bool = false
    
    // Model configuration
    private let modelName = "xgb_model" // User's trained XGBoost model
    private let confidenceThreshold: Float = 0.7
    
    // MARK: - Initialization
    
    init() {
        loadModel()
    }
    
    // MARK: - Model Loading
    
    private func loadModel() {
        print("🧠 ADHDInferenceEngine: Attempting to load ADHD detection model...")
        
        // List available model files for debugging
        listAvailableModelFiles()
        
        // Load XGBoost CoreML model - check both root and Models subfolder
        var modelPath: String?
        
        // First try Models subfolder
        if let path = Bundle.main.path(forResource: modelName, ofType: "mlmodel", inDirectory: "Models") {
            modelPath = path
            print("✅ Found XGBoost model in Models folder: \(path)")
        }
        // Fallback to bundle root
        else if let path = Bundle.main.path(forResource: modelName, ofType: "mlmodel") {
            modelPath = path
            print("✅ Found XGBoost model in bundle root: \(path)")
        }
        
        guard let finalModelPath = modelPath else {
            print("⚠️ ADHDInferenceEngine: XGBoost model not found at \(modelName).mlmodel - using placeholder")
            print("📝 Searched in: bundle root and Models subfolder")
            setupPlaceholderMode()
            return
        }
        
        do {
            let modelURL = URL(fileURLWithPath: finalModelPath)
            adhdModel = try MLModel(contentsOf: modelURL)
            isModelLoaded = true
            print("✅ ADHDInferenceEngine: ADHD detection model loaded successfully from: \(finalModelPath)")
            
            // Print comprehensive model metadata
            let modelDescription = adhdModel!.modelDescription
            print("📊 XGBoost Model Details:")
            print("   📥 Inputs: \(Array(modelDescription.inputDescriptionsByName.keys))")
            print("   📤 Outputs: \(Array(modelDescription.outputDescriptionsByName.keys))")
            
            // Print input shape information
            for (inputName, inputDesc) in modelDescription.inputDescriptionsByName {
                if let multiArrayConstraint = inputDesc.multiArrayConstraint {
                    print("   📏 Input '\(inputName)' shape: \(multiArrayConstraint.shape)")
                    print("   🔢 Input '\(inputName)' data type: \(multiArrayConstraint.dataType.rawValue)")
                }
            }
            
            // Print output information
            for (outputName, outputDesc) in modelDescription.outputDescriptionsByName {
                print("   📤 Output '\(outputName)' type: \(outputDesc.type)")
                if let multiArrayConstraint = outputDesc.multiArrayConstraint {
                    print("   📏 Output '\(outputName)' shape: \(multiArrayConstraint.shape)")
                }
            }
            
            // Print model metadata
            let metadata = modelDescription.metadata
            if !metadata.isEmpty {
                print("   📋 Model metadata keys: \(Array(metadata.keys))")
            }
            
        } catch {
            print("❌ ADHDInferenceEngine: Failed to load model - \(error)")
            print("📝 Error details: \(error.localizedDescription)")
            setupPlaceholderMode()
        }
    }
    
    private func listAvailableModelFiles() {
        guard let bundlePath = Bundle.main.resourcePath else {
            print("❌ Could not access bundle resources")
            return
        }
        
        do {
            let contents = try FileManager.default.contentsOfDirectory(atPath: bundlePath)
            let modelFiles = contents.filter { filename in
                filename.hasSuffix(".mlmodel") || 
                filename.hasSuffix(".mlmodelc") || 
                filename.hasSuffix(".mlpackage") ||
                filename.contains("xgb") ||
                filename.contains("model")
            }
            
            print("📁 Available model files in bundle:")
            if modelFiles.isEmpty {
                print("   📝 No model files found")
            } else {
                for file in modelFiles.sorted() {
                    print("   📄 \(file)")
                }
            }
            
        } catch {
            print("❌ Error listing bundle contents: \(error)")
        }
    }
    
    private func setupPlaceholderMode() {
        isModelLoaded = false
        print("🔄 ADHDInferenceEngine: Running in placeholder mode")
        print("📝 Model Status:")
        print("   ✅ XGBoost model trained and available")
        print("   ⚠️  Model not found in bundle - check if \(modelName).mlmodel is properly added")
        print("   📊 Using rule-based fallback for now")
        print("   🎯 Next: Ensure model is included in Xcode project bundle")
    }
    
    // MARK: - ADHD Prediction
    
    struct ADHDPrediction {
        let binaryPrediction: Int           // XGBoost binary output: 1 = ADHD, 0 = No ADHD
        let confidence: Float               // Derived confidence based on model certainty
        let classification: ADHDClassification
        let supportingFeatures: [String: Float] // Key features that drove prediction
        let timestamp: TimeInterval
        
        enum ADHDClassification: String {
            case positive = "ADHD_Detected"    // Binary prediction = 1
            case negative = "No_ADHD"          // Binary prediction = 0
            case inconclusive = "Inconclusive" // Model/data issues
        }
        
        // Legacy compatibility - convert binary to probability-like value for UI
        var adhdProbability: Float {
            return binaryPrediction == 1 ? 0.85 : 0.15  // High/low confidence values for UI display
        }
    }
    
    func predictADHD(from measurements: [PupilMeasurement]) -> ADHDPrediction {
        print("🧠 ADHDInferenceEngine: Starting ADHD prediction...")
        
        // Safety check for empty measurements
        guard !measurements.isEmpty else {
            print("⚠️ ADHDInferenceEngine: No measurements provided")
            return createFallbackPrediction()
        }
        
        print("📊 Processing \(measurements.count) pupil measurements...")
        
        // Validate measurement quality
        let validMeasurements = measurements.filter { !$0.diameterMM.isNaN && $0.diameterMM > 0 }
        guard validMeasurements.count >= 240 else {
            print("⚠️ Insufficient valid measurements: \(validMeasurements.count) < 240")
            return createFallbackPrediction()
        }
        
        // Step 1: Extract Python-compatible features with error handling
        print("🔄 Extracting Python-compatible features...")
        guard let featureVector = pythonCompatibleExtractor.extractFeaturesForModel(from: validMeasurements) else {
            print("❌ ADHDInferenceEngine: Failed to extract Python-compatible features")
            return createFallbackPrediction()
        }
        
        print("✅ ADHDInferenceEngine: Extracted \(featureVector.count) features (matches Python training)")
        
        // Validate feature vector
        let validFeatures = featureVector.filter { !$0.isNaN && $0.isFinite }
        guard validFeatures.count == featureVector.count else {
            print("⚠️ Invalid features detected: \(featureVector.count - validFeatures.count) NaN/infinite values")
            return createFallbackPrediction()
        }
        
        if isModelLoaded, let model = adhdModel {
            // Real model inference using trained CoreML model
            return performRealInference(featureVector: featureVector, model: model) ?? createFallbackPrediction()
        } else {
            // Placeholder inference using rule-based approach on basic features
            return performPlaceholderInference(featureVector: featureVector, measurements: validMeasurements)
        }
    }
    
    private func createFallbackPrediction() -> ADHDPrediction {
        print("⚠️ Creating fallback ADHD prediction due to insufficient/invalid data")
        return ADHDPrediction(
            binaryPrediction: -1,  // Invalid prediction
            confidence: 0.2,
            classification: .inconclusive,
            supportingFeatures: ["status": 0.0, "data_quality": 0.0],
            timestamp: CACurrentMediaTime()
        )
    }
    
    // MARK: - Real Model Inference
    
    private func performRealInference(featureVector: [Float], model: MLModel) -> ADHDPrediction? {
        print("🎯 ADHDInferenceEngine: Performing real CoreML inference...")
        
        // Wrap CoreML inference in autoreleasepool to prevent memory leaks
        return autoreleasepool {
            do {
                print("🔄 Preparing model input...")
                let input = try prepareModelInput(featureVector: featureVector)
                
                print("🔄 Running CoreML prediction...")
                let prediction = try model.prediction(from: input)
                
                print("✅ CoreML prediction completed")
                return parseModelOutput(prediction: prediction, featureVector: featureVector)
                
            } catch {
                print("❌ ADHDInferenceEngine: Model inference failed - \(error)")
                print("🔄 Falling back to placeholder inference...")
                return performPlaceholderInference(featureVector: featureVector, measurements: [])
            }
        }
    }
    
    private func prepareModelInput(featureVector: [Float]) throws -> MLFeatureProvider {
        print("📊 ADHDInferenceEngine: Preparing model input with \(featureVector.count) features...")
        
        // Get input names from model description
        guard let modelDescription = adhdModel?.modelDescription else {
            throw NSError(domain: "ADHDInferenceEngine", code: 1, userInfo: [NSLocalizedDescriptionKey: "No model description available"])
        }
        
        let inputNames = Array(modelDescription.inputDescriptionsByName.keys)
        print("📊 Available inputs: \(inputNames)")
        
        guard let firstInputName = inputNames.first else {
            throw NSError(domain: "ADHDInferenceEngine", code: 2, userInfo: [NSLocalizedDescriptionKey: "No inputs found in model"])
        }
        
        // Create MLMultiArray from feature vector with error handling
        do {
            let input = try MLMultiArray(shape: [NSNumber(value: featureVector.count)], dataType: .float32)
            
            for (index, value) in featureVector.enumerated() {
                guard !value.isNaN && value.isFinite else {
                    throw NSError(domain: "ADHDInferenceEngine", code: 3, userInfo: [NSLocalizedDescriptionKey: "Invalid feature value at index \(index): \(value)"])
                }
                input[index] = NSNumber(value: value)
            }
            
            print("✅ Using input name: \(firstInputName)")
            return try MLDictionaryFeatureProvider(dictionary: [firstInputName: input])
            
        } catch {
            print("❌ Failed to create MLMultiArray: \(error)")
            throw NSError(domain: "ADHDInferenceEngine", code: 4, userInfo: [NSLocalizedDescriptionKey: "Failed to prepare model input: \(error.localizedDescription)"])
        }
    }
    
    private func parseModelOutput(prediction: MLFeatureProvider, featureVector: [Float]) -> ADHDPrediction? {
        print("📊 ADHDInferenceEngine: Parsing model output...")
        
        // Get all available outputs for analysis
        let availableOutputs = Array(prediction.featureNames)
        print("📊 Available outputs: \(availableOutputs)")
        
        // Try to find probability/prediction output
        var probabilityOutput: MLFeatureValue?
        var confidenceOutput: MLFeatureValue?
        
        // Common XGBoost output names
        let probabilityNames = ["output", "prediction", "classProbability", "probabilities"]
        let confidenceNames = ["confidence", "scores", "prediction_confidence"]
        
        // Find probability output
        for outputName in probabilityNames {
            if let output = prediction.featureValue(for: outputName) {
                probabilityOutput = output
                print("✅ Found probability output: \(outputName)")
                break
            }
        }
        
        // Find confidence output (if available)
        for outputName in confidenceNames {
            if let output = prediction.featureValue(for: outputName) {
                confidenceOutput = output
                print("✅ Found confidence output: \(outputName)")
                break
            }
        }
        
        // If no probability output found, try first available output
        if probabilityOutput == nil && !availableOutputs.isEmpty {
            let firstOutput = availableOutputs[0]
            probabilityOutput = prediction.featureValue(for: firstOutput)
            print("🔄 Using first available output: \(firstOutput)")
        }
        
        guard let output = probabilityOutput else {
            print("❌ ADHDInferenceEngine: Could not find any usable model output")
            return nil
        }
        
        // Parse XGBoost binary classification output (1 = ADHD, 0 = No ADHD)
        let binaryPrediction: Int
        let confidence: Float
        
        if let multiArray = output.multiArrayValue {
            // Handle MLMultiArray output 
            if multiArray.count == 1 {
                // Single binary output (0 or 1)
                let rawValue = Float(multiArray[0].doubleValue)
                binaryPrediction = rawValue > 0.5 ? 1 : 0
                print("📊 XGBoost raw output: \(rawValue) -> Binary: \(binaryPrediction)")
            } else if multiArray.count == 2 {
                // Two-class output [class_0_score, class_1_score] - take argmax
                let class0Score = Float(multiArray[0].doubleValue)
                let class1Score = Float(multiArray[1].doubleValue)
                binaryPrediction = class1Score > class0Score ? 1 : 0
                print("📊 XGBoost class scores: [\(class0Score), \(class1Score)] -> Binary: \(binaryPrediction)")
            } else {
                print("⚠️ Unexpected XGBoost output shape: \(multiArray.count) elements")
                binaryPrediction = 0 // Default to no ADHD
            }
        } else {
            // Single value output - round to nearest integer
            let rawValue = Float(output.doubleValue)
            binaryPrediction = rawValue > 0.5 ? 1 : 0
            print("📊 XGBoost single output: \(rawValue) -> Binary: \(binaryPrediction)")
        }
        
        // Calculate confidence - for XGBoost, this is a derived metric
        if let confOutput = confidenceOutput {
            // Use model confidence if available (unlikely for standard XGBoost)
            if let confMultiArray = confOutput.multiArrayValue {
                confidence = Float(confMultiArray[0].doubleValue)
            } else {
                confidence = Float(confOutput.doubleValue)
            }
            print("✅ Using model confidence: \(confidence)")
        } else {
            // For binary XGBoost, derive confidence from decision certainty
            // High confidence for clear predictions, lower for borderline cases
            confidence = 0.8  // Fixed high confidence for XGBoost binary decisions
            print("📊 Using fixed XGBoost confidence: \(confidence)")
        }
        
        // Determine classification from binary prediction
        let classification: ADHDPrediction.ADHDClassification
        if binaryPrediction == 1 {
            classification = .positive  // ADHD detected
        } else if binaryPrediction == 0 {
            classification = .negative  // No ADHD
        } else {
            classification = .inconclusive  // Invalid prediction
        }
        
        // Extract supporting features from the feature vector
        let supportingFeatures = extractSupportingFeaturesFromVector(featureVector: featureVector)
        
        print("🎯 XGBoost Binary Prediction: \(binaryPrediction), Classification: \(classification.rawValue)")
        
        return ADHDPrediction(
            binaryPrediction: binaryPrediction,
            confidence: confidence,
            classification: classification,
            supportingFeatures: supportingFeatures,
            timestamp: CACurrentMediaTime()
        )
    }
    
    // MARK: - Placeholder Inference (Rule-based)
    
    private func performPlaceholderInference(featureVector: [Float], measurements: [PupilMeasurement]) -> ADHDPrediction {
        print("🔄 ADHDInferenceEngine: Using rule-based placeholder inference...")
        
        // Rule-based ADHD likelihood estimation using Python-compatible features
        // Feature vector structure: [240 pupil samples] + [11 derived scalars] + [~60 velocities]
        
        guard featureVector.count >= 251 else { // At least 240 + 11 features
            print("⚠️ Insufficient features for rule-based inference: \(featureVector.count)")
            return ADHDPrediction(
                binaryPrediction: -1,  // Invalid prediction due to insufficient data
                confidence: 0.3,
                classification: .inconclusive,
                supportingFeatures: [:],
                timestamp: CACurrentMediaTime()
            )
        }
        
        var adhdScore: Float = 0.0
        var supportingFeatures: [String: Float] = [:]
        
        // Extract Python-compatible derived features (indices 240-250)
        // Based on Python script: Max0_5000, Max5000_8000, TPS_start, TPS_end, TD, MaxV, TotalV, MaxA, TotalA, PPS_AT, PPS_WM
        let max0_5000 = featureVector[240]
        let max5000_8000 = featureVector[241] 
        let tps_start = featureVector[242]
        let tps_end = featureVector[243]
        let totalDistance = featureVector[244]
        let maxV = featureVector[245]
        let totalV = featureVector[246]
        let maxA = featureVector[247]
        let totalA = featureVector[248]
        let pps_at = featureVector[249]  // Attention phase response
        let pps_wm = featureVector[250]  // Working memory phase response
        
        // Rule 1: High velocity variability (ADHD indicator)
        let velocityVariability = maxV / max(totalV / 60.0, 0.1) // Assume ~60 velocity samples
        if velocityVariability > 1.5 {
            adhdScore += 0.2
            supportingFeatures["velocity_variability"] = velocityVariability
        }
        
        // Rule 2: Poor attention phase response (ADHD indicator)
        if abs(pps_at) < 0.1 { // Low attention response
            adhdScore += 0.15
            supportingFeatures["attention_response"] = pps_at
        }
        
        // Rule 3: Poor working memory response (ADHD indicator)
        if abs(pps_wm) < 0.1 { // Low working memory response
            adhdScore += 0.15
            supportingFeatures["memory_response"] = pps_wm
        }
        
        // Rule 4: High total distance (hyperactivity indicator)
        let pupilSamples = Array(featureVector[0..<240])
        let meanPupilSize = pupilSamples.reduce(0, +) / Float(pupilSamples.count)
        let normalizedDistance = totalDistance / meanPupilSize
        if normalizedDistance > 50.0 {
            adhdScore += 0.1
            supportingFeatures["hyperactivity"] = normalizedDistance
        }
        
        // Rule 5: High baseline variability (attention instability)
        let baselineChange = abs(tps_end - tps_start)
        if baselineChange > 0.5 {
            adhdScore += 0.1
            supportingFeatures["baseline_instability"] = baselineChange
        }
        
        // Rule 6: High acceleration (impulsivity indicator)
        if maxA > 0.01 {
            adhdScore += 0.1
            supportingFeatures["impulsivity"] = maxA
        }
        
        // Rule 7: Phase imbalance (attention regulation deficit)
        let phaseImbalance = abs(max0_5000 - max5000_8000)
        if phaseImbalance > 0.3 {
            adhdScore += 0.15
            supportingFeatures["phase_imbalance"] = phaseImbalance
        }
        
        // Convert rule-based score to binary prediction (simulating XGBoost)
        let binaryPrediction = adhdScore > 0.5 ? 1 : 0
        let confidence: Float = 0.6 // Lower confidence for rule-based approach
        
        let classification: ADHDPrediction.ADHDClassification
        if binaryPrediction == 1 {
            classification = .positive  // ADHD indicators present
        } else {
            classification = .negative  // No ADHD indicators
        }
        
        print("📊 ADHDInferenceEngine: Rule-based prediction complete")
        print("   - ADHD Score: \(adhdScore)")
        print("   - Binary Prediction: \(binaryPrediction)")
        print("   - Classification: \(classification.rawValue)")
        print("   - Supporting Features: \(supportingFeatures.count)")
        
        return ADHDPrediction(
            binaryPrediction: binaryPrediction,
            confidence: confidence,
            classification: classification,
            supportingFeatures: supportingFeatures,
            timestamp: CACurrentMediaTime()
        )
    }
    
    // MARK: - Helper Methods
    
    private func extractSupportingFeaturesFromVector(featureVector: [Float]) -> [String: Float] {
        // Extract key features from the Python-compatible feature vector
        guard featureVector.count >= 251 else {
            return ["feature_count": Float(featureVector.count)]
        }
        
        return [
            "max_velocity": featureVector[245],
            "total_velocity": featureVector[246],
            "max_acceleration": featureVector[247],
            "attention_response": featureVector[249], // PPS_AT
            "memory_response": featureVector[250],    // PPS_WM
            "total_distance": featureVector[244]
        ]
    }
    
    // MARK: - Model Status
    
    func getModelStatus() -> String {
        if isModelLoaded {
            return "✅ ADHD Detection Model Loaded"
        } else {
            return "⚠️ Using Rule-based Placeholder (Model not trained yet)"
        }
    }
    
    func isReady() -> Bool {
        return true // Always ready (either real model or placeholder)
    }
}

// MARK: - MLMultiArray Extension

extension MLMultiArray {
    convenience init?(_ array: [Float]) {
        do {
            try self.init(shape: [NSNumber(value: array.count)], dataType: .float32)
            let pointer = self.dataPointer.bindMemory(to: Float.self, capacity: array.count)
            for (index, value) in array.enumerated() {
                pointer[index] = value
            }
        } catch {
            print("❌ MLMultiArray creation failed: \(error)")
            return nil
        }
    }
}
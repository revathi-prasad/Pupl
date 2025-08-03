//
//  CloudStorageManager.swift
//  PupillometryApp
//
//  Created by Revathi Prasad on 10/06/25.
//

// FirebaseStorageManager.swift
import Foundation
//import Firebase
import FirebaseStorage

class FirebaseStorageManager {
    private let storage = Storage.storage()
    // Note: Firebase automatically uses bucket from GoogleService-Info.plist: pupl-73e6b.firebasestorage.app
    
    // Get pathway-specific folder path
    private func getFolderPath(for session: SessionData) -> String {
        switch session.pathwayType {
        case .clinical:
            return "clinical_sessions/"
        case .consumer:
            return "consumer_sessions/"
        }
    }
    
    // Check if authenticated
    var isAuthorized: Bool {
        return true  // Firebase is always available once configured
    }
    
    func setup() {
        // Configure with credentials from GoogleService-Info.plist
        // This happens automatically when Firebase is initialized in AppDelegate
    }
    
    func uploadSessionData(_ session: SessionData, completion: @escaping (Bool, String?) -> Void) {
        let folderPath = getFolderPath(for: session)
        let sessionFolder = folderPath + "session_\(session.sessionID)/"
        
        print("🔥 FirebaseStorageManager: Starting upload to bucket: \(storage.reference().bucket)")
        print("🎯 Pathway: \(session.pathwayType.displayName) (\(session.pathwayType.rawValue))")
        print("📁 Session folder: \(sessionFolder)")
        print("📊 Session data: \(session.pupilMeasurements.count) measurements, \(session.taskEvents.count) events")
        
        // Calculate performance metrics before upload
        session.calculatePerformanceMetrics()
        
        // Upload each data file in parallel
        let group = DispatchGroup()
        var errors: [Error] = []
        
        // Upload measurements CSV
        group.enter()
        uploadMeasurementsCSV(session: session, path: sessionFolder + "measurements.csv") { success, error in
            if !success, let error = error {
                errors.append(error)
            }
            group.leave()
        }
        
        // Upload events CSV
        group.enter()
        uploadEventsCSV(session: session, path: sessionFolder + "events.csv") { success, error in
            if !success, let error = error {
                errors.append(error)
            }
            group.leave()
        }
        
        // Upload demographics JSON
        group.enter()
        uploadDemographicsJSON(session: session, path: sessionFolder + "demographics.json") { success, error in
            if !success, let error = error {
                errors.append(error)
            }
            group.leave()
        }
        
        // Upload performance metrics JSON
        group.enter()
        uploadPerformanceMetricsJSON(session: session, path: sessionFolder + "performance_metrics.json") { success, error in
            if !success, let error = error {
                errors.append(error)
            }
            group.leave()
        }
        
        // Upload detailed performance report
        group.enter()
        uploadPerformanceReport(session: session, path: sessionFolder + "performance_report.md") { success, error in
            if !success, let error = error {
                errors.append(error)
            }
            group.leave()
        }
        
        // Upload GradCPT response data CSV
        if !session.gradCPTResponses.isEmpty {
            group.enter()
            uploadGradCPTResponsesCSV(session: session, path: sessionFolder + "gradcpt_responses.csv") { success, error in
                if !success, let error = error {
                    errors.append(error)
                }
                group.leave()
            }
        }
        
        // Upload Memory Task response data CSV
        if !session.memoryTaskResponses.isEmpty {
            group.enter()
            uploadMemoryTaskResponsesCSV(session: session, path: sessionFolder + "memory_responses.csv") { success, error in
                if !success, let error = error {
                    errors.append(error)
                }
                group.leave()
            }
        }
        
        // Upload ADHD Protocol data (pprep.csv format)
        if !session.adhdProtocolResponses.isEmpty {
            group.enter()
            uploadADHDProtocolCSV(session: session, path: sessionFolder + "ADHD-Diagnostic.csv") { success, error in
                if !success, let error = error {
                    errors.append(error)
                }
                group.leave()
            }
        }
        
        // NEW: Upload facial landmarks CSV
        if !session.facialLandmarksData.isEmpty {
            group.enter()
            uploadFacialLandmarksCSV(session: session, path: sessionFolder + "facial_landmarks.csv") { success, error in
                if !success, let error = error {
                    errors.append(error)
                }
                group.leave()
            }
        }
        
        // NEW: Upload captured images and eye regions
        if !session.capturedImages.isEmpty {
            print("📸 FirebaseStorageManager: Uploading \(session.capturedImages.count) images...")
            for capturedImage in session.capturedImages {
                // Upload full image
                group.enter()
                uploadImage(capturedImage, to: sessionFolder + "images/") { success, error in
                    if !success, let error = error {
                        errors.append(error)
                    }
                    group.leave()
                }
                
                // Upload eye region if available
                if let eyeRegionData = capturedImage.eyeRegionData {
                    group.enter()
                    uploadEyeRegion(capturedImage, to: sessionFolder + "eye_regions/") { success, error in
                        if !success, let error = error {
                            errors.append(error)
                        }
                        group.leave()
                    }
                }
            }
        }
        
        // Handle completion with enhanced validation
        group.notify(queue: .main) {
            // ENHANCED ERROR REPORTING: Validate data integrity before reporting success
            let validationResult = self.validateSessionDataIntegrity(session: session)
            
            if errors.isEmpty && validationResult.isValid {
                print("✅ FirebaseStorageManager: All files uploaded successfully to \(sessionFolder)")
                print("📊 Data integrity check passed: \(validationResult.summary)")
                completion(true, sessionFolder)
            } else {
                var errorMessage = "Upload issues detected: "
                
                if !errors.isEmpty {
                    errorMessage += "\(errors.count) upload errors. "
                    for error in errors {
                        print("❌ Upload error: \(error.localizedDescription)")
                    }
                }
                
                if !validationResult.isValid {
                    errorMessage += "Data integrity issues: \(validationResult.issues.joined(separator: ", "))"
                    print("⚠️ Data validation warnings: \(validationResult.issues)")
                }
                
                print("❌ FirebaseStorageManager: \(errorMessage)")
                completion(false, errorMessage)
            }
        }
    }
    
    private func uploadMeasurementsCSV(session: SessionData, path: String, completion: @escaping (Bool, Error?) -> Void) {
        // ENHANCED CSV FORMAT: Convert measurements to CSV with content type tracking
        // Updated format includes contentType, taskPhase, videoTimestamp for dashboard filtering
        var csv = "timestamp,centerX,centerY,radiusPixels,diameterMM,confidence,eye,contentType,taskPhase,videoTimestamp,associatedImageFilename,faceConfidence,headPitch,headYaw,headRoll,leftEyeLandmarkCount,rightEyeLandmarkCount\n"
        
        for measurement in session.pupilMeasurements {
            // Basic measurement data
            csv += "\(measurement.timestamp),\(measurement.center.x),\(measurement.center.y),"
            csv += "\(measurement.radiusPixels),\(measurement.diameterMM),\(measurement.confidence),\(measurement.eye.rawValue),"
            
            // NEW: Content type tracking for dashboard
            csv += "\(measurement.contentType.rawValue),"
            
            // NEW: Task phase information (escaped for CSV)
            let taskPhase = measurement.taskPhase ?? ""
            let escapedTaskPhase = taskPhase.replacingOccurrences(of: "\"", with: "\"\"")
            csv += "\"\(escapedTaskPhase)\","
            
            // NEW: Video timestamp for YouTube correlation
            let videoTimestamp = measurement.videoTimestamp ?? 0.0
            csv += "\(videoTimestamp),"
            
            // Image reference (properly escaped for CSV)
            let filename = measurement.associatedImageFilename ?? ""
            let escapedFilename = filename.replacingOccurrences(of: "\"", with: "\"\"")
            csv += "\"\(escapedFilename)\","
            
            // Facial landmark data
            if let landmarks = measurement.facialLandmarks {
                csv += "\(landmarks.faceConfidence),\(landmarks.headPose.pitch),\(landmarks.headPose.yaw),\(landmarks.headPose.roll),"
                csv += "\(landmarks.leftEyeLandmarks.count),\(landmarks.rightEyeLandmarks.count)\n"
            } else {
                csv += ",,,,,\n"  // Empty values for missing landmark data
            }
        }
        
        guard let csvData = csv.data(using: .utf8) else {
            completion(false, NSError(domain: "FirebaseStorageManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "Could not encode measurements CSV"]))
            return
        }
        
        uploadData(csvData, path: path, contentType: "text/csv", completion: completion)
    }
    
    private func uploadEventsCSV(session: SessionData, path: String, completion: @escaping (Bool, Error?) -> Void) {
        // ENHANCED EVENTS CSV: Convert events to CSV with content type tracking
        var csv = "timestamp,type,contentType,data\n"
        
        for event in session.taskEvents {
            let dataString = event.data.map { "\($0.key):\($0.value)" }.joined(separator: ";")
            let escapedDataString = dataString.replacingOccurrences(of: "\"", with: "\"\"") // Escape quotes
            csv += "\(event.timestamp),\(event.type.rawValue),\(event.contentType.rawValue),\"\(escapedDataString)\"\n"
        }
        
        guard let csvData = csv.data(using: .utf8) else {
            completion(false, NSError(domain: "FirebaseStorageManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "Could not encode events CSV"]))
            return
        }
        
        uploadData(csvData, path: path, contentType: "text/csv", completion: completion)
    }
    
    // MARK: - Data Validation
    
    private struct ValidationResult {
        let isValid: Bool
        let issues: [String]
        let summary: String
    }
    
    private func validateSessionDataIntegrity(session: SessionData) -> ValidationResult {
        // Data integrity validation to prevent "Save Results" format errors
        // Assumption: Based on user feedback about "data couldn't be written because it isn't in correct format"
        // Resource: iOS app debugging feedback from user
        
        var issues: [String] = []
        var validCount = 0
        
        print("🔍 FirebaseStorageManager: Validating session data integrity...")
        
        // 1. Validate measurements data
        let totalMeasurements = session.pupilMeasurements.count
        if totalMeasurements == 0 {
            issues.append("No pupil measurements recorded")
        } else {
            // Check for valid diameter values (not fixed 2.0mm)
            let validDiameters = session.pupilMeasurements.filter { $0.diameterMM > 1.0 && $0.diameterMM < 8.0 && $0.diameterMM != 2.0 }
            let validDiameterPercent = Double(validDiameters.count) / Double(totalMeasurements) * 100
            
            if validDiameterPercent < 50 {
                issues.append("Only \(Int(validDiameterPercent))% of measurements have valid diameter calculations")
            }
            
            // Check for associated image filenames
            let withImages = session.pupilMeasurements.filter { $0.associatedImageFilename != nil && !$0.associatedImageFilename!.isEmpty }
            let imageAssociationPercent = Double(withImages.count) / Double(totalMeasurements) * 100
            
            if imageAssociationPercent < 30 {
                issues.append("Only \(Int(imageAssociationPercent))% of measurements have associated image filenames")
            }
            
            // Check for content type distribution
            let contentTypes = Set(session.pupilMeasurements.map { $0.contentType })
            if contentTypes.count < 2 {
                issues.append("Limited content type diversity (only \(contentTypes.count) type(s))")
            }
            
            validCount = totalMeasurements
        }
        
        // 2. Validate captured images data
        let totalImages = session.capturedImages.count
        if totalImages > 0 {
            let validImages = session.capturedImages.filter { !$0.imageData.isEmpty }
            let validImagePercent = Double(validImages.count) / Double(totalImages) * 100
            
            if validImagePercent < 80 {
                issues.append("Only \(Int(validImagePercent))% of captured images have valid data")
            }
        }
        
        // 3. Validate task events
        if session.taskEvents.isEmpty {
            issues.append("No task events recorded")
        }
        
        // 4. Overall assessment
        let isValid = issues.count <= 2  // Allow minor issues but flag major problems
        let summary = "\(validCount) measurements, \(totalImages) images, \(session.taskEvents.count) events validated"
        
        print("📊 Validation complete: \(isValid ? "PASSED" : "FAILED") - \(summary)")
        if !issues.isEmpty {
            print("⚠️ Issues found: \(issues.joined(separator: "; "))")
        }
        
        return ValidationResult(isValid: isValid, issues: issues, summary: summary)
    }
    
    private func uploadDemographicsJSON(session: SessionData, path: String, completion: @escaping (Bool, Error?) -> Void) {
        guard let demographics = session.demographicData else {
            completion(true, nil) // No demographics to upload
            return
        }
        
        do {
            let jsonData = try JSONEncoder().encode(demographics)
            uploadData(jsonData, path: path, contentType: "application/json", completion: completion)
        } catch {
            completion(false, error)
        }
    }
    
    private func uploadData(_ data: Data, path: String, contentType: String, completion: @escaping (Bool, Error?) -> Void) {
        // Create a storage reference
        let storageRef = storage.reference().child(path)
        
        // Create metadata
        let metadata = StorageMetadata()
        metadata.contentType = contentType
        
        // Upload file
        print("🔥 FirebaseStorageManager: Uploading \(data.count) bytes to \(path) with content type \(contentType)")
        
        storageRef.putData(data, metadata: metadata) { metadata, error in
            if let error = error {
                print("❌ FirebaseStorageManager: Upload failed for \(path) - \(error.localizedDescription)")
                print("📊 Data info: \(data.count) bytes, content type: \(contentType)")
                completion(false, error)
                return
            }
            
            print("✅ FirebaseStorageManager: Successfully uploaded \(path)")
            completion(true, nil)
        }
    }
    
    // MARK: - Enhanced Export Methods
    
    private func uploadPerformanceMetricsJSON(session: SessionData, path: String, completion: @escaping (Bool, Error?) -> Void) {
        guard let performanceMetrics = session.performanceMetrics else {
            print("⚠️ FirebaseStorageManager: No performance metrics available")
            completion(true, nil) // Not an error, just no data
            return
        }
        
        do {
            let jsonData = try JSONEncoder().encode(performanceMetrics)
            uploadData(jsonData, path: path, contentType: "application/json", completion: completion)
        } catch {
            completion(false, error)
        }
    }
    
    private func uploadPerformanceReport(session: SessionData, path: String, completion: @escaping (Bool, Error?) -> Void) {
        let report = session.generatePerformanceReport()
        
        guard let reportData = report.data(using: .utf8) else {
            completion(false, NSError(domain: "FirebaseStorageManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "Could not encode performance report"]))
            return
        }
        
        uploadData(reportData, path: path, contentType: "text/markdown", completion: completion)
    }
    
    private func uploadGradCPTResponsesCSV(session: SessionData, path: String, completion: @escaping (Bool, Error?) -> Void) {
        var csv = "trialNumber,isTarget,responded,correct,reactionTime,timestamp\n"
        
        for response in session.gradCPTResponses {
            let rtString = response.reactionTime.map { String($0) } ?? ""
            csv += "\(response.trialNumber),\(response.isTarget),\(response.responded),\(response.correct),\(rtString),\(response.timestamp)\n"
        }
        
        guard let csvData = csv.data(using: .utf8) else {
            completion(false, NSError(domain: "FirebaseStorageManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "Could not encode GradCPT responses"]))
            return
        }
        
        uploadData(csvData, path: path, contentType: "text/csv", completion: completion)
    }
    
    private func uploadMemoryTaskResponsesCSV(session: SessionData, path: String, completion: @escaping (Bool, Error?) -> Void) {
        var csv = "trialNumber,setSize,correct,reactionTime\n"
        
        for response in session.memoryTaskResponses {
            csv += "\(response.trialNumber),\(response.setSize),\(response.correct),\(response.reactionTime)\n"
        }
        
        guard let csvData = csv.data(using: .utf8) else {
            completion(false, NSError(domain: "FirebaseStorageManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "Could not encode Memory Task responses"]))
            return
        }
        
        uploadData(csvData, path: path, contentType: "text/csv", completion: completion)
    }
    
    private func uploadADHDProtocolCSV(session: SessionData, path: String, completion: @escaping (Bool, Error?) -> Void) {
        // Generate a unique subject ID based on session
        let subjectID = abs(session.sessionID.hashValue) % 10000
        // Convert previousDiagnosis to ADHD identifier (1 = ADHD, 0 = Control)
        let adhdIdentifier: String
        if let diagnosis = session.demographicData?.previousDiagnosis?.lowercased() {
            if diagnosis.contains("adhd") || diagnosis.contains("attention") || diagnosis.contains("hyperactivity") {
                adhdIdentifier = "1"  // ADHD positive
            } else {
                adhdIdentifier = "0"  // Control/No ADHD
            }
        } else {
            adhdIdentifier = "Unknown"  // No diagnosis provided
        }
        
        // Create CSV header matching training data format (final_data_v3.csv)
        var csv = "Subject,ADHD_Identifier,Trial,Perform,Rtime,Age,Gender"
        
        // Add sparse pupil sample columns (using exact indices from training data)
        let sparseSampleIndices = [
            0, 3, 4, 7, 9, 10, 13, 14, 17, 19, 21, 24, 26, 28, 30, 32, 33, 35, 38, 40,
            41, 43, 45, 47, 50, 53, 54, 56, 58, 61, 63, 65, 67, 69, 70, 72, 76, 78, 79, 81,
            84, 85, 87, 89, 91, 94, 95, 97, 101, 103, 104, 106, 108, 110, 113, 115, 117, 118, 120, 122,
            125, 127, 129, 131, 133, 136, 138, 139, 142, 144, 146, 149, 150, 152, 154, 157, 159, 160, 162, 165,
            166, 168, 170, 172, 176, 177, 179, 182, 184, 186, 187, 189, 192, 194, 195, 198, 200, 202, 204, 206,
            208, 210, 213, 215, 216, 218, 220, 224, 226, 228, 230, 232, 233, 235, 238, 240, 241, 243, 245, 248,
            250, 252, 254, 256, 258, 261, 263, 265, 266, 268, 271, 274, 275, 278, 280, 281, 283, 285, 288, 289,
            292, 294, 296, 297, 301, 303, 305, 306, 308, 311, 313, 315, 316, 318, 320, 322, 326, 328, 330, 332,
            334, 335, 337, 340, 342, 343, 345, 347, 350, 352, 354, 356, 358, 360, 362, 364, 367, 368, 371, 374,
            375, 378, 380, 381, 383, 385, 387, 389, 391, 394, 396, 398, 400, 403, 404, 407, 408, 410, 412, 415,
            417, 419, 421, 424, 426, 428, 429, 431, 433, 436, 438, 439, 441, 443, 445, 447, 450, 452, 454, 456,
            458, 460, 462, 464, 466, 468, 471, 474, 475, 478, 479, 482, 483, 485, 488, 489, 492, 494, 496, 499
        ]
        
        for index in sparseSampleIndices {
            csv += ",\(index)"
        }
        
        // Add computed features (11 columns)
        csv += ",Max0_5000,Max5000_8000,TPS_start,TPS_end,TD,MaxV,TotalV,MaxA,TotalA,PPS_AT,PPS_WM"
        
        // Add velocity features (60 columns)
        for i in 0..<60 {
            csv += ",velocity_\(i)"
        }
        csv += "\n"
        
        // Group blocks by trial number (each trial contains 8 blocks)
        let groupedByTrial = Dictionary(grouping: session.adhdTrialData) { $0.trialNumber }
        let totalTrials = groupedByTrial.keys.count
        
        print("📊 FirebaseStorageManager: Processing \(totalTrials) trials with \(session.adhdTrialData.count) total blocks")
        
        // Process each trial separately (1 CSV row per trial) - Reduced to 5 trials for stability
        for trialNumber in 1...5 {
            guard let trialBlocks = groupedByTrial[trialNumber], !trialBlocks.isEmpty else {
                print("⚠️ No blocks found for trial \(trialNumber) - skipping")
                continue
            }
            
            // Get responses for this trial
            let trialResponses = session.adhdProtocolResponses.filter { $0.trialNumber == trialNumber }
            
            // Aggregate blocks within this trial
            guard let exportData = PupilDataProcessor.aggregateBlocksIntoTrial(
                blocks: trialBlocks,
                responses: trialResponses,
                subject: subjectID,
                adhdIdentifier: adhdIdentifier
            ) else {
                print("❌ FirebaseStorageManager: Failed to aggregate trial \(trialNumber)")
                continue
            }
        
            // Build CSV row for this trial - include Age and Gender from demographics
            let age = session.demographicData?.age ?? 0
            let gender = session.demographicData?.gender ?? "Unknown"
            
            print("📊 FirebaseStorageManager: Trial \(trialNumber) demographics - Age: \(age), Gender: \(gender)")
            if session.demographicData == nil {
                print("⚠️ FirebaseStorageManager: No demographic data found in session!")
            }
            
            var row = ""
            row += "\(exportData["Subject"] ?? subjectID),"
            row += "\(exportData["ADHD_Identifier"] ?? adhdIdentifier),"
            row += "\(exportData["Trial"] ?? trialNumber),"
            row += "\(exportData["Perform"] ?? 0),"
            row += "\(exportData["Rtime"] ?? 0.0),"
            row += "\(age),"
            row += "\(gender)"
            
            // Add sparse pupil samples (240 columns using specific indices)
            for index in sparseSampleIndices {
                let sampleValue = exportData["\(index)"] ?? 0.0
                row += ",\(sampleValue)"
            }
            
            // Add computed features (11 columns)
            row += ",\(exportData["Max0_5000"] ?? 0.0)"
            row += ",\(exportData["Max5000_8000"] ?? 0.0)"
            row += ",\(exportData["TPS_start"] ?? 0.0)"
            row += ",\(exportData["TPS_end"] ?? 0.0)"
            row += ",\(exportData["TD"] ?? 0.0)"
            row += ",\(exportData["MaxV"] ?? 0.0)"
            row += ",\(exportData["TotalV"] ?? 0.0)"
            row += ",\(exportData["MaxA"] ?? 0.0)"
            row += ",\(exportData["TotalA"] ?? 0.0)"
            row += ",\(exportData["PPS_AT"] ?? 0.0)"
            row += ",\(exportData["PPS_WM"] ?? 0.0)"
            
            // Add velocity features (60 columns)
            for i in 0..<60 {
                let velocityValue = exportData["velocity_\(i)"] ?? 0.0
                row += ",\(velocityValue)"
            }
            
            csv += row + "\n"
        }
        
        guard let csvData = csv.data(using: .utf8) else {
            completion(false, NSError(domain: "FirebaseStorageManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "Could not encode ADHD Protocol data"]))
            return
        }
        
        print("✅ FirebaseStorageManager: Generated pprep.csv with \(totalTrials) trial rows, \(csvData.count) bytes")
        uploadData(csvData, path: path, contentType: "text/csv", completion: completion)
    }
    
    // MARK: - Data Retrieval Methods
    
    func listAvailableSessions(pathwayType: PathwayType = .consumer, completion: @escaping ([String], Error?) -> Void) {
        let folderPath = pathwayType == .clinical ? "clinical_sessions/" : "consumer_sessions/"
        let storageRef = storage.reference().child(folderPath)
        
        storageRef.listAll { result, error in
            if let error = error {
                completion([], error)
                return
            }
            
            let sessionFolders = result?.prefixes.map { $0.name } ?? []
            completion(sessionFolders, nil)
        }
    }
    
    func downloadSessionFile(sessionID: String, fileName: String, pathwayType: PathwayType = .consumer, completion: @escaping (Data?, Error?) -> Void) {
        let folderPath = pathwayType == .clinical ? "clinical_sessions/" : "consumer_sessions/"
        let filePath = folderPath + "session_\(sessionID)/\(fileName)"
        let storageRef = storage.reference().child(filePath)
        
        storageRef.getData(maxSize: 10 * 1024 * 1024) { data, error in // 10MB limit
            completion(data, error)
        }
    }
    
    // NEW: Upload facial landmarks data as CSV
    private func uploadFacialLandmarksCSV(session: SessionData, path: String, completion: @escaping (Bool, Error?) -> Void) {
        // Create comprehensive landmark CSV
        var csv = "timestamp,faceConfidence,faceRectX,faceRectY,faceRectWidth,faceRectHeight,headPitch,headYaw,headRoll,"
        csv += "leftEyeLandmarks,rightEyeLandmarks,leftIrisLandmarks,rightIrisLandmarks,"
        csv += "noseLandmarks,mouthLandmarks,jawlineLandmarks,eyebrowLandmarks\n"
        
        for landmarks in session.facialLandmarksData {
            csv += "\(landmarks.timestamp),\(landmarks.faceConfidence),"
            csv += "\(landmarks.faceRect.origin.x),\(landmarks.faceRect.origin.y),\(landmarks.faceRect.size.width),\(landmarks.faceRect.size.height),"
            csv += "\(landmarks.headPose.pitch),\(landmarks.headPose.yaw),\(landmarks.headPose.roll),"
            
            // Convert landmark arrays to semicolon-separated coordinates
            csv += "\"\(landmarksToString(landmarks.leftEyeLandmarks))\","
            csv += "\"\(landmarksToString(landmarks.rightEyeLandmarks))\","
            csv += "\"\(landmarksToString(landmarks.leftIrisLandmarks))\","
            csv += "\"\(landmarksToString(landmarks.rightIrisLandmarks))\","
            csv += "\"\(landmarksToString(landmarks.noseLandmarks))\","
            csv += "\"\(landmarksToString(landmarks.mouthLandmarks))\","
            csv += "\"\(landmarksToString(landmarks.jawlineLandmarks))\","
            csv += "\"\(landmarksToString(landmarks.eyebrowLandmarks))\"\n"
        }
        
        guard let csvData = csv.data(using: .utf8) else {
            completion(false, NSError(domain: "FirebaseStorageManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "Could not encode facial landmarks CSV"]))
            return
        }
        
        uploadData(csvData, path: path, contentType: "text/csv", completion: completion)
    }
    
    // Helper function to convert landmark arrays to string format
    private func landmarksToString(_ landmarks: [CGPoint]) -> String {
        return landmarks.map { "\($0.x),\($0.y)" }.joined(separator: ";")
    }
    
    // NEW: Upload individual images
    private func uploadImage(_ capturedImage: SessionData.CapturedImage, to folderPath: String, completion: @escaping (Bool, Error?) -> Void) {
        let imagePath = folderPath + capturedImage.filename
        
        // Validate image data is not empty
        guard !capturedImage.imageData.isEmpty else {
            print("⚠️ FirebaseStorageManager: Empty image data for \(capturedImage.filename)")
            completion(false, NSError(domain: "FirebaseStorageManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "Empty image data"]))
            return
        }
        
        print("📸 FirebaseStorageManager: Uploading image \(capturedImage.filename) (\(capturedImage.imageData.count / 1024)KB)")
        
        uploadData(capturedImage.imageData, path: imagePath, contentType: "image/jpeg", completion: completion)
    }
    
    // NEW: Upload eye region images
    private func uploadEyeRegion(_ capturedImage: SessionData.CapturedImage, to folderPath: String, completion: @escaping (Bool, Error?) -> Void) {
        guard let eyeRegionData = capturedImage.eyeRegionData, !eyeRegionData.isEmpty else {
            print("⚠️ FirebaseStorageManager: No eye region data available for \(capturedImage.filename)")
            completion(false, NSError(domain: "FirebaseStorageManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "No eye region data available"]))
            return
        }
        
        // Create eye region filename with same timestamp as full image
        // Handle both rgb_ and nir_ prefixes correctly
        let eyeRegionFilename: String
        if capturedImage.filename.hasPrefix("rgb_") {
            eyeRegionFilename = capturedImage.filename.replacingOccurrences(of: "rgb_", with: "eye_")
        } else if capturedImage.filename.hasPrefix("nir_") {
            eyeRegionFilename = capturedImage.filename.replacingOccurrences(of: "nir_", with: "eye_")
        } else {
            eyeRegionFilename = "eye_" + capturedImage.filename // Fallback
        }
        let eyeRegionPath = folderPath + eyeRegionFilename
        
        print("👁️ FirebaseStorageManager: Uploading eye region \(eyeRegionFilename) (\(eyeRegionData.count / 1024)KB)")
        
        uploadData(eyeRegionData, path: eyeRegionPath, contentType: "image/jpeg", completion: completion)
    }
}

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
    private let bucketName = "YOUR_BUCKET_NAME"
    private let folderPath = "pupillometry_data/"
    
    // Check if authenticated
    var isAuthorized: Bool {
        return true  // Firebase is always available once configured
    }
    
    func setup() {
        // Configure with credentials from GoogleService-Info.plist
        // This happens automatically when Firebase is initialized in AppDelegate
    }
    
    func uploadSessionData(_ session: SessionData, completion: @escaping (Bool, String?) -> Void) {
        let sessionFolder = folderPath + "session_\(session.sessionID)/"
        
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
        
        // Handle completion
        group.notify(queue: .main) {
            if errors.isEmpty {
                completion(true, sessionFolder)
            } else {
                completion(false, "Upload errors: \(errors.first?.localizedDescription ?? "Unknown error")")
            }
        }
    }
    
    private func uploadMeasurementsCSV(session: SessionData, path: String, completion: @escaping (Bool, Error?) -> Void) {
        // Convert measurements to CSV string
        var csv = "timestamp,centerX,centerY,radiusPixels,diameterMM,confidence,eye\n"
        
        for measurement in session.pupilMeasurements {
            csv += "\(measurement.timestamp),\(measurement.center.x),\(measurement.center.y),"
            csv += "\(measurement.radiusPixels),\(measurement.diameterMM),\(measurement.confidence),\(measurement.eye.rawValue)\n"
        }
        
        uploadData(csv.data(using: .utf8)!, path: path, contentType: "text/csv", completion: completion)
    }
    
    private func uploadEventsCSV(session: SessionData, path: String, completion: @escaping (Bool, Error?) -> Void) {
        // Convert events to CSV string
        var csv = "timestamp,type,data\n"
        
        for event in session.taskEvents {
            let dataString = event.data.map { "\($0.key):\($0.value)" }.joined(separator: ";")
            csv += "\(event.timestamp),\(event.type.rawValue),\"\(dataString)\"\n"
        }
        
        uploadData(csv.data(using: .utf8)!, path: path, contentType: "text/csv", completion: completion)
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
        storageRef.putData(data, metadata: metadata) { metadata, error in
            if let error = error {
                completion(false, error)
                return
            }
            
            completion(true, nil)
        }
    }
}

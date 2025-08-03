//
//  SimpleMediaPipeTest.swift
//  PupillometryApp
//
//  Created by Claude on 15/07/25.
//  Simple test to verify MediaPipe integration works
//

import Foundation
import UIKit
import MediaPipeTasksVision

class SimpleMediaPipeTest {
    
    func testMediaPipeImport() {
        print("✅ MediaPipe import successful")
        
        // Test basic MediaPipe types
        let options = FaceLandmarkerOptions()
        options.runningMode = .image
        options.numFaces = 1
        
        print("✅ MediaPipe FaceLandmarkerOptions created successfully")
        print("   - Running mode: \(options.runningMode.rawValue)")
        print("   - Number of faces: \(options.numFaces)")
        
        // Test if we can create a basic landmark
        let landmark = NormalizedLandmark(x: 0.5, y: 0.5, z: 0.0, visibility: nil, presence: nil)
        print("✅ MediaPipe NormalizedLandmark created successfully")
        print("   - Position: (\(landmark.x), \(landmark.y), \(landmark.z))")
        
        print("🎉 MediaPipe basic integration test completed successfully!")
    }
    
    // Call this method to run the test
    static func runTest() {
        let test = SimpleMediaPipeTest()
        test.testMediaPipeImport()
    }
}
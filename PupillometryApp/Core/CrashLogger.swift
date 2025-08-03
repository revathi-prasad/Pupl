//
//  CrashLogger.swift
//  PupillometryApp
//
//  Created by Claude on 03/08/25.
//  Crash logging for non-debug mode app terminations
//

import Foundation
import UIKit

class CrashLogger {
    
    private let userDefaults = UserDefaults.standard
    private let crashLogKey = "PupillometryApp_CrashLog"
    private let lastLaunchKey = "PupillometryApp_LastLaunch"
    private let memoryWarningKey = "PupillometryApp_MemoryWarnings"
    
    init() {
        // Record successful app launch
        recordLaunchTime()
    }
    
    // MARK: - Crash Detection
    
    func checkForPreviousCrash() {
        let lastLaunchTime = userDefaults.double(forKey: lastLaunchKey)
        let currentTime = Date().timeIntervalSince1970
        
        // If less than 30 seconds passed since last launch, likely a crash
        if lastLaunchTime > 0 && (currentTime - lastLaunchTime) < 30 {
            print("🚨 CrashLogger: Potential crash detected - app lasted only \(Int(currentTime - lastLaunchTime)) seconds")
            
            // Log crash details
            let crashInfo = [
                "timestamp": Date().description,
                "type": "Potential App Termination",
                "duration": "\(Int(currentTime - lastLaunchTime)) seconds",
                "memory_warnings": "\(getMemoryWarningCount())"
            ]
            
            logCrashInternal(type: "Quick Termination", details: crashInfo)
            
            // Clear memory warning count for new session
            userDefaults.removeObject(forKey: memoryWarningKey)
        }
        
        // Check for existing crash logs
        if let existingCrashLogs = userDefaults.array(forKey: crashLogKey) as? [[String: String]] {
            print("📋 CrashLogger: Found \(existingCrashLogs.count) previous crash logs")
            for (index, crashLog) in existingCrashLogs.enumerated() {
                print("   Crash \(index + 1): \(crashLog["type"] ?? "Unknown") at \(crashLog["timestamp"] ?? "Unknown time")")
            }
        }
    }
    
    // MARK: - Logging Methods
    
    static func logCrash(type: String, details: [String: String]) {
        let instance = CrashLogger()
        instance.logCrashInternal(type: type, details: details)
    }
    
    private func logCrashInternal(type: String, details: [String: String]) {
        print("💥 CrashLogger: Logging crash - Type: \(type)")
        
        var crashLog = details
        crashLog["crash_type"] = type
        crashLog["timestamp"] = Date().description
        crashLog["app_version"] = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
        crashLog["device_model"] = UIDevice.current.model
        crashLog["ios_version"] = UIDevice.current.systemVersion
        crashLog["memory_usage"] = "\(getCurrentMemoryUsage())MB"
        
        // Get existing crash logs
        var crashLogs = userDefaults.array(forKey: crashLogKey) as? [[String: String]] ?? []
        crashLogs.append(crashLog)
        
        // Keep only last 10 crash logs
        if crashLogs.count > 10 {
            crashLogs = Array(crashLogs.suffix(10))
        }
        
        // Save to persistent storage
        userDefaults.set(crashLogs, forKey: crashLogKey)
        userDefaults.synchronize()
        
        print("✅ CrashLogger: Crash logged and persisted")
    }
    
    func logMemoryWarning() {
        let warningCount = getMemoryWarningCount() + 1
        userDefaults.set(warningCount, forKey: memoryWarningKey)
        
        let memoryUsage = getCurrentMemoryUsage()
        print("⚠️ CrashLogger: Memory warning #\(warningCount) - Current usage: \(memoryUsage)MB")
        
        // Log memory warning details
        let warningDetails = [
            "warning_number": "\(warningCount)",
            "memory_usage_mb": "\(memoryUsage)",
            "timestamp": Date().description
        ]
        
        logCrashInternal(type: "Memory Warning", details: warningDetails)
    }
    
    func logAppTermination() {
        let terminationDetails = [
            "termination_type": "Normal",
            "session_duration": "\(Int(Date().timeIntervalSince1970 - userDefaults.double(forKey: lastLaunchKey))) seconds",
            "memory_warnings": "\(getMemoryWarningCount())",
            "final_memory_usage": "\(getCurrentMemoryUsage())MB"
        ]
        
        logCrashInternal(type: "App Termination", details: terminationDetails)
    }
    
    // MARK: - Helper Methods
    
    private func recordLaunchTime() {
        userDefaults.set(Date().timeIntervalSince1970, forKey: lastLaunchKey)
        print("🚀 CrashLogger: App launch recorded at \(Date())")
    }
    
    private func getMemoryWarningCount() -> Int {
        return userDefaults.integer(forKey: memoryWarningKey)
    }
    
    private func getCurrentMemoryUsage() -> Int {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
        
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_,
                         task_flavor_t(MACH_TASK_BASIC_INFO),
                         $0,
                         &count)
            }
        }
        
        if kerr == KERN_SUCCESS {
            return Int(info.resident_size) / 1024 / 1024 // Convert to MB
        } else {
            return -1
        }
    }
    
    // MARK: - Public Access Methods
    
    func getCrashLogs() -> [[String: String]] {
        return userDefaults.array(forKey: crashLogKey) as? [[String: String]] ?? []
    }
    
    func clearCrashLogs() {
        userDefaults.removeObject(forKey: crashLogKey)
        userDefaults.removeObject(forKey: memoryWarningKey)
        print("🧹 CrashLogger: All crash logs cleared")
    }
}
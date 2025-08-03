//
//  MemoryPressureMonitor.swift
//  PupillometryApp
//
//  Created by Claude on 03/08/25.
//  Monitor memory pressure and prevent iOS app termination
//

import Foundation
import UIKit

class MemoryPressureMonitor {
    
    private var memoryPressureSource: DispatchSourceMemoryPressure?
    private var isMonitoring = false
    private var lastMemoryCheck: TimeInterval = 0
    private let memoryCheckInterval: TimeInterval = 5.0 // Check every 5 seconds
    private var timer: Timer?
    
    // Emergency pressure loop detection
    private var emergencyCount = 0
    private var lastEmergencyTime: TimeInterval = 0
    private let emergencyResetInterval: TimeInterval = 60.0 // Reset count after 60 seconds
    
    // Memory thresholds (in MB) - RAISED to prevent breaking core functionality
    private let warningThreshold: Int = 300  // Start warnings at 300MB (was 150MB)
    private let criticalThreshold: Int = 400 // Critical cleanup at 400MB (was 200MB)  
    private let emergencyThreshold: Int = 500 // Emergency termination prevention at 500MB (was 250MB)
    
    init() {
        setupMemoryPressureSource()
    }
    
    deinit {
        stopMonitoring()
    }
    
    // MARK: - Monitoring Control
    
    func startMonitoring() {
        guard !isMonitoring else {
            print("⚠️ MemoryPressureMonitor: Already monitoring")
            return
        }
        
        isMonitoring = true
        memoryPressureSource?.resume()
        
        // Start periodic memory checks
        timer = Timer.scheduledTimer(withTimeInterval: memoryCheckInterval, repeats: true) { [weak self] _ in
            self?.checkMemoryUsage()
        }
        
        print("👁️ MemoryPressureMonitor: Started monitoring memory pressure")
    }
    
    func stopMonitoring() {
        guard isMonitoring else { return }
        
        isMonitoring = false
        memoryPressureSource?.suspend()
        timer?.invalidate()
        timer = nil
        
        print("🛑 MemoryPressureMonitor: Stopped monitoring")
    }
    
    // MARK: - Memory Pressure Source Setup
    
    private func setupMemoryPressureSource() {
        memoryPressureSource = DispatchSource.makeMemoryPressureSource(eventMask: [.warning, .critical], queue: .main)
        
        memoryPressureSource?.setEventHandler { [weak self] in
            guard let self = self else { return }
            
            let event = self.memoryPressureSource?.mask
            
            if event?.contains(.warning) == true {
                print("⚠️ MemoryPressureMonitor: System memory pressure WARNING")
                self.handleMemoryWarning()
            }
            
            if event?.contains(.critical) == true {
                print("🚨 MemoryPressureMonitor: System memory pressure CRITICAL")
                self.handleCriticalMemoryPressure()
            }
        }
        
        memoryPressureSource?.setCancelHandler {
            print("🛑 MemoryPressureMonitor: Memory pressure source cancelled")
        }
    }
    
    // MARK: - Memory Usage Checking
    
    private func checkMemoryUsage() {
        let currentTime = CACurrentMediaTime()
        guard currentTime - lastMemoryCheck >= memoryCheckInterval else { return }
        
        lastMemoryCheck = currentTime
        let memoryUsage = getCurrentMemoryUsage()
        
        // Log periodic memory usage (less verbose)
        if Int(currentTime) % 30 == 0 { // Every 30 seconds
            print("📊 MemoryMonitor: Current usage \(memoryUsage)MB")
        }
        
        // Check against thresholds
        if memoryUsage >= emergencyThreshold {
            print("🚨 MemoryMonitor: EMERGENCY threshold reached (\(memoryUsage)MB)")
            handleEmergencyMemoryPressure()
        } else if memoryUsage >= criticalThreshold {
            print("⚠️ MemoryMonitor: CRITICAL threshold reached (\(memoryUsage)MB)")
            handleCriticalMemoryPressure()
        } else if memoryUsage >= warningThreshold {
            print("⚠️ MemoryMonitor: WARNING threshold reached (\(memoryUsage)MB)")
            handleMemoryWarning()
        }
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
    
    // MARK: - Memory Pressure Handlers
    
    private func handleMemoryWarning() {
        print("🧹 MemoryMonitor: Performing standard cleanup")
        
        // Standard cleanup
        PupillometryManager.shared.performStandardMemoryCleanup()
        
        // Force garbage collection
        autoreleasepool {
            // Let ARC clean up temporary objects
        }
        
        // Post memory warning notification
        NotificationCenter.default.post(name: UIApplication.didReceiveMemoryWarningNotification, object: nil)
    }
    
    private func handleCriticalMemoryPressure() {
        print("🚨 MemoryMonitor: Performing aggressive cleanup")
        
        // Aggressive cleanup
        PupillometryManager.shared.performAggressiveMemoryCleanup()
        
        // Stop non-essential services
        stopNonEssentialServices()
        
        // Force multiple garbage collection cycles
        for _ in 0..<3 {
            autoreleasepool {
                // Force ARC cleanup
            }
        }
    }
    
    private func handleEmergencyMemoryPressure() {
        let currentTime = CACurrentMediaTime()
        
        // Reset emergency count if enough time has passed
        if currentTime - lastEmergencyTime > emergencyResetInterval {
            emergencyCount = 0
        }
        
        emergencyCount += 1
        lastEmergencyTime = currentTime
        
        print("🆘 MemoryMonitor: EMERGENCY #\(emergencyCount) - Preventing app termination")
        
        // If we're in an emergency loop (3+ emergencies in 60 seconds), be more conservative
        if emergencyCount >= 3 {
            print("🚨 MemoryMonitor: Emergency loop detected - temporarily disabling monitoring")
            
            // Temporarily stop monitoring to let app recover
            stopMonitoring()
            
            // Restart monitoring after 30 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 30.0) { [weak self] in
                print("🔄 MemoryMonitor: Restarting monitoring after emergency loop")
                self?.emergencyCount = 0
                self?.startMonitoring()
            }
            
            // Do minimal cleanup only
            URLCache.shared.removeAllCachedResponses()
            
        } else {
            // Normal emergency response
            PupillometryManager.shared.emergencyMemoryCleanup()
            stopAllBackgroundTasks()
            URLCache.shared.removeAllCachedResponses()
            showMemoryPressureAlert()
        }
        
        // Log emergency state
        CrashLogger.logCrash(type: "Emergency Memory Pressure", details: [
            "memory_usage": "\(getCurrentMemoryUsage())MB",
            "threshold": "\(emergencyThreshold)MB",
            "emergency_count": "\(emergencyCount)",
            "action": emergencyCount >= 3 ? "Emergency loop - disabled monitoring" : "Emergency cleanup performed"
        ])
    }
    
    // MARK: - Cleanup Helpers
    
    private func stopNonEssentialServices() {
        // Stop background MediaPipe test
        // Stop any running timers in view controllers
        NotificationCenter.default.post(name: Notification.Name("StopNonEssentialServices"), object: nil)
    }
    
    private func stopAllBackgroundTasks() {
        // Stop any background processing
        NotificationCenter.default.post(name: Notification.Name("StopAllBackgroundTasks"), object: nil)
    }
    
    private var isShowingAlert = false  // Prevent alert stacking
    
    private func showMemoryPressureAlert() {
        // Prevent multiple alerts from stacking
        guard !isShowingAlert else {
            print("⚠️ MemoryPressureMonitor: Alert already showing, skipping duplicate")
            return
        }
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            guard let topViewController = UIApplication.shared.windows.first?.rootViewController else { return }
            
            // Double-check alert isn't already presented
            if topViewController.presentedViewController is UIAlertController {
                print("⚠️ MemoryPressureMonitor: Another alert already presented, skipping")
                return
            }
            
            self.isShowingAlert = true
            
            let alert = UIAlertController(
                title: "High Memory Usage",
                message: "The app is using significant memory but will continue functioning normally.",
                preferredStyle: .alert
            )
            
            alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in
                self.isShowingAlert = false
            })
            
            topViewController.present(alert, animated: true)
        }
    }
}
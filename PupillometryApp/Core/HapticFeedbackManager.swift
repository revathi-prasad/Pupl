//
//  HapticFeedbackManager.swift
//  PupillometryApp
//
//  Created by Revathi Prasad on 01/07/25.
//

import UIKit

class HapticFeedbackManager {
    static let shared = HapticFeedbackManager()
    
    private let lightImpact = UIImpactFeedbackGenerator(style: .light)
    private let mediumImpact = UIImpactFeedbackGenerator(style: .medium)
    private let heavyImpact = UIImpactFeedbackGenerator(style: .heavy)
    private let selectionFeedback = UISelectionFeedbackGenerator()
    private let notificationFeedback = UINotificationFeedbackGenerator()
    
    private var isEnabled = true
    
    private init() {
        // Pre-prepare generators for better performance
        lightImpact.prepare()
        mediumImpact.prepare()
        heavyImpact.prepare()
        selectionFeedback.prepare()
        notificationFeedback.prepare()
    }
    
    // MARK: - Settings
    
    func setEnabled(_ enabled: Bool) {
        isEnabled = enabled
        print("🔸 HapticFeedbackManager: Haptic feedback \(enabled ? "enabled" : "disabled")")
    }
    
    // MARK: - Response Feedback
    
    func correctResponse() {
        guard isEnabled else { 
            print("⚠️ HapticFeedbackManager: Haptics disabled")
            return 
        }
        print("✅ HapticFeedbackManager: Triggering correct response feedback")
        lightImpact.impactOccurred()
        print("✅ HapticFeedbackManager: Correct response feedback completed")
    }
    
    func incorrectResponse() {
        guard isEnabled else { 
            print("⚠️ HapticFeedbackManager: Haptics disabled")
            return 
        }
        print("❌ HapticFeedbackManager: Triggering incorrect response feedback")
        notificationFeedback.notificationOccurred(.error)
        print("❌ HapticFeedbackManager: Incorrect response feedback completed")
    }
    
    func neutralResponse() {
        guard isEnabled else { 
            print("⚠️ HapticFeedbackManager: Haptics disabled for neutral response")
            return 
        }
        print("🔘 HapticFeedbackManager: Triggering neutral response feedback")
        // Use light impact instead of selection for more noticeable feedback
        lightImpact.impactOccurred()
        print("🔘 HapticFeedbackManager: Neutral response feedback completed")
    }
    
    // MARK: - Task Navigation
    
    func taskStart() {
        guard isEnabled else { return }
        mediumImpact.impactOccurred()
        print("🚀 HapticFeedbackManager: Task start feedback")
    }
    
    func taskComplete() {
        guard isEnabled else { return }
        notificationFeedback.notificationOccurred(.success)
        print("🎯 HapticFeedbackManager: Task completion feedback")
    }
    
    func phaseTransition() {
        guard isEnabled else { return }
        lightImpact.impactOccurred()
        print("🔄 HapticFeedbackManager: Phase transition feedback")
    }
    
    // MARK: - Memory Task Specific
    
    func memoryEncodingStart() {
        guard isEnabled else { return }
        lightImpact.impactOccurred()
        print("🧠 HapticFeedbackManager: Memory encoding start")
    }
    
    func memoryRetentionPhase() {
        guard isEnabled else { return }
        // Very subtle pulse during retention
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.selectionFeedback.selectionChanged()
        }
        print("⏳ HapticFeedbackManager: Memory retention phase")
    }
    
    func memoryTestStart() {
        guard isEnabled else { return }
        mediumImpact.impactOccurred()
        print("🎯 HapticFeedbackManager: Memory test start")
    }
    
    // MARK: - GradCPT Specific
    
    func stimulusTransition() {
        guard isEnabled else { return }
        // Very light feedback for stimulus changes
        selectionFeedback.selectionChanged()
        print("🔄 HapticFeedbackManager: Stimulus transition")
    }
    
    func targetDetected() {
        guard isEnabled else { return }
        lightImpact.impactOccurred()
        print("🎯 HapticFeedbackManager: Target detected")
    }
    
    // MARK: - General UI
    
    func buttonTap() {
        guard isEnabled else { return }
        selectionFeedback.selectionChanged()
        print("👆 HapticFeedbackManager: Button tap")
    }
    
    func warning() {
        guard isEnabled else { return }
        notificationFeedback.notificationOccurred(.warning)
        print("⚠️ HapticFeedbackManager: Warning feedback")
    }
    
    func error() {
        guard isEnabled else { return }
        notificationFeedback.notificationOccurred(.error)
        print("🚨 HapticFeedbackManager: Error feedback")
    }
    
    // MARK: - Advanced Patterns
    
    func trialBlockComplete() {
        guard isEnabled else { return }
        // Double tap pattern
        mediumImpact.impactOccurred()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.mediumImpact.impactOccurred()
        }
        print("📊 HapticFeedbackManager: Trial block completion")
    }
    
    func sessionSaved() {
        guard isEnabled else { return }
        // Success pattern: light, medium, light
        lightImpact.impactOccurred()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.mediumImpact.impactOccurred()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                self?.lightImpact.impactOccurred()
            }
        }
        print("💾 HapticFeedbackManager: Session saved pattern")
    }
}
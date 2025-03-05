import AudioToolbox
import UIKit

// Manages haptic and audio feedback patterns
final class FeedbackManager: ObservableObject {
    private var hapticWarningTimer: Timer?
    private var hapticCriticalTimer: Timer?
    private var warningSoundTimer: Timer?
    private var criticalSoundTimer: Timer?
    
    // Starts warning haptic feedback
    func startWarningHapticFeedback() {
        setupTimer(&hapticWarningTimer, interval: 0.3, style: .medium)
    }
    
    // Starts critical haptic feedback
    func startCriticalHapticFeedback() {
        setupTimer(&hapticCriticalTimer, interval: 0.1, style: .heavy)
    }
    
    // Starts warning sound feedback
    func startWarningSound() {
        setupSoundTimer(&warningSoundTimer, interval: 1.0, soundID: 1255)
    }
    
    // Starts critical sound feedback
    func startCriticalSound() {
        setupSoundTimer(&criticalSoundTimer, interval: 0.5, soundID: 1256)
    }
    
    // Stops warning haptic feedback
    func stopWarningHapticFeedback() {
        hapticWarningTimer?.invalidate()
        hapticWarningTimer = nil
    }
    
    // Stops critical haptic feedback
    func stopCriticalHapticFeedback() {
        hapticCriticalTimer?.invalidate()
        hapticCriticalTimer = nil
    }
    
    // Stops warning sound feedback
    func stopWarningSound() {
        warningSoundTimer?.invalidate()
        warningSoundTimer = nil
    }
    
    // Stops critical sound feedback
    func stopCriticalSound() {
        criticalSoundTimer?.invalidate()
        criticalSoundTimer = nil
    }
    
    // Stops all feedback
    func stopAll() {
        stopWarningHapticFeedback()
        stopCriticalHapticFeedback()
        stopWarningSound()
        stopCriticalSound()
    }
    
    // Handles the warning state feedback
    func handleWarningState(soundEnabled: Bool) {
        stopCriticalHapticFeedback()
        startWarningHapticFeedback()
        stopCriticalSound()
        
        if soundEnabled {
            startWarningSound()
        } else {
            stopWarningSound()
        }
    }
    
    // Handles the critical state feedback
    func handleCriticalState(soundEnabled: Bool) {
        stopWarningHapticFeedback()
        startCriticalHapticFeedback()
        stopWarningSound()
        
        if soundEnabled {
            startCriticalSound()
        } else {
            stopCriticalSound()
        }
    }
    
    // Helper to set up a haptic feedback timer
    private func setupTimer(_ timer: inout Timer?, interval: TimeInterval, style: UIImpactFeedbackGenerator.FeedbackStyle) {
        guard timer == nil else { return }
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { _ in
            UIImpactFeedbackGenerator(style: style).impactOccurred()
        }
    }
    
    // Helper to set up a sound feedback timer
    private func setupSoundTimer(_ timer: inout Timer?, interval: TimeInterval, soundID: SystemSoundID) {
        guard timer == nil else { return }
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { _ in
            AudioServicesPlaySystemSound(soundID)
        }
    }
}

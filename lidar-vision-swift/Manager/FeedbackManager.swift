import AudioToolbox
import UIKit

final class FeedbackManager: ObservableObject {
    private var hapticWarningTimer: Timer?
    private var hapticCriticalTimer: Timer?
    private var warningSoundTimer: Timer?
    private var criticalSoundTimer: Timer?
    
    private enum Sound {
        static let warning: SystemSoundID = 1255
        static let critical: SystemSoundID = 1256
    }
    
    // MARK: - Haptic Feedback
    
    func startWarningHapticFeedback() {
        setupTimer(&hapticWarningTimer, interval: 0.3, style: .medium)
    }
    
    func startCriticalHapticFeedback() {
        setupTimer(&hapticCriticalTimer, interval: 0.1, style: .heavy)
    }
    
    func stopWarningHapticFeedback() {
        hapticWarningTimer?.invalidate()
        hapticWarningTimer = nil
    }
    
    func stopCriticalHapticFeedback() {
        hapticCriticalTimer?.invalidate()
        hapticCriticalTimer = nil
    }
    
    // MARK: - Sound Feedback
    
    func startWarningSound() {
        setupSoundTimer(&warningSoundTimer, interval: 1.0, soundID: Sound.warning)
    }
    
    func startCriticalSound() {
        setupSoundTimer(&criticalSoundTimer, interval: 0.5, soundID: Sound.critical)
    }
    
    func stopWarningSound() {
        warningSoundTimer?.invalidate()
        warningSoundTimer = nil
    }
    
    func stopCriticalSound() {
        criticalSoundTimer?.invalidate()
        criticalSoundTimer = nil
    }
    
    func stopAll() {
        stopWarningHapticFeedback()
        stopCriticalHapticFeedback()
        stopWarningSound()
        stopCriticalSound()
    }
    
    // MARK: - Feedback Handling
    
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
    
    // MARK: - Timer Setup
    
    private func setupTimer(_ timer: inout Timer?, interval: TimeInterval, style: UIImpactFeedbackGenerator.FeedbackStyle) {
        guard timer == nil else { return }
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { _ in
            UIImpactFeedbackGenerator(style: style).impactOccurred()
        }
    }
    
    private func setupSoundTimer(_ timer: inout Timer?, interval: TimeInterval, soundID: SystemSoundID) {
        guard timer == nil else { return }
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { _ in
            AudioServicesPlaySystemSound(soundID)
        }
    }
}

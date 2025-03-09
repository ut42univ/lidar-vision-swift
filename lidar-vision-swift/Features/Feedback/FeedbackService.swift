import AudioToolbox
import UIKit

/// 触覚フィードバックを管理するサービス（音響フィードバックは空間オーディオに統一）
final class FeedbackService {
    private var hapticWarningTimer: Timer?
    private var hapticCriticalTimer: Timer?
    
    // MARK: - 触覚フィードバック
    
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
    
    func stopAll() {
        stopWarningHapticFeedback()
        stopCriticalHapticFeedback()
    }
    
    // MARK: - フィードバック状態ハンドラー
    
    func handleWarningState() {
        stopCriticalHapticFeedback()
        startWarningHapticFeedback()
    }
    
    func handleCriticalState() {
        stopWarningHapticFeedback()
        startCriticalHapticFeedback()
    }
    
    // MARK: - タイマー設定ヘルパー
    
    private func setupTimer(_ timer: inout Timer?, interval: TimeInterval, style: UIImpactFeedbackGenerator.FeedbackStyle) {
        guard timer == nil else { return }
        
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { _ in
            UIImpactFeedbackGenerator(style: style).impactOccurred()
        }
    }
}

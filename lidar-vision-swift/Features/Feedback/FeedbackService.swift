import AudioToolbox
import UIKit

/// 触覚フィードバックを管理するサービス
final class FeedbackService {
    private var hapticWarningTimer: Timer?
    private var hapticCriticalTimer: Timer?
    private var settings: AppSettings
    
    init(settings: AppSettings = AppSettings()) {
        self.settings = settings
    }
    
    // MARK: - 触覚フィードバック
    
    func startWarningHapticFeedback() {
        guard settings.hapticFeedback.isEnabled else { return }
        setupTimer(
            &hapticWarningTimer,
            interval: settings.hapticFeedback.mediumInterval,
            style: settings.hapticFeedback.mediumIntensity.uiStyle
        )
    }
    
    func startCriticalHapticFeedback() {
        guard settings.hapticFeedback.isEnabled else { return }
        setupTimer(
            &hapticCriticalTimer,
            interval: settings.hapticFeedback.nearInterval,
            style: settings.hapticFeedback.nearIntensity.uiStyle
        )
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
    
    /// 設定を更新
    func updateSettings(_ newSettings: AppSettings) {
        // 設定変更があった場合、現在動作中のフィードバックも更新
        let wasEnabled = settings.hapticFeedback.isEnabled
        settings = newSettings
        
        // 有効状態が変更された場合
        if wasEnabled != settings.hapticFeedback.isEnabled {
            if !settings.hapticFeedback.isEnabled {
                stopAll()
            }
            // 有効になった場合は次のフィードバックイベントで再開
        }
    }
    
    // MARK: - タイマー設定ヘルパー
    
    private func setupTimer(_ timer: inout Timer?, interval: TimeInterval, style: UIImpactFeedbackGenerator.FeedbackStyle) {
        guard timer == nil else { return }
        
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { _ in
            UIImpactFeedbackGenerator(style: style).impactOccurred()
        }
    }
}

import AudioToolbox
import UIKit
import CoreHaptics

/// 触覚フィードバックを管理するサービス
final class FeedbackService {
    private var hapticWarningTimer: Timer?
    private var hapticCriticalTimer: Timer?
    private var settings: AppSettings
    
    // CoreHaptics関連
    private var engine: CHHapticEngine?
    private var supportsHaptics: Bool = false
    private var continuousPlayer: CHHapticAdvancedPatternPlayer?
    private var intensityParameter: CHHapticDynamicParameter?
    private var sharpnessParameter: CHHapticDynamicParameter?
    private var currentDepth: Float = 10.0 // 初期値は十分に遠い
    
    init(settings: AppSettings = AppSettings()) {
        self.settings = settings
        
        // デバイスがHapticsをサポートしているか確認
        checkDeviceCapabilities()
        
        // CoreHapticsをサポートしている場合はエンジンを初期化
        if supportsHaptics {
            setupHapticEngine()
        }
    }
    
    // MARK: - デバイス機能チェック
    
    private func checkDeviceCapabilities() {
        // CoreHapticsのサポート状況チェック
        supportsHaptics = CHHapticEngine.capabilitiesForHardware().supportsHaptics
        print("Device supports CoreHaptics: \(supportsHaptics)")
    }
    
    // MARK: - CoreHapticsエンジンのセットアップ
    
    private func setupHapticEngine() {
        guard supportsHaptics else { return }
        
        do {
            engine = try CHHapticEngine()
            try engine?.start()
            
            // エンジンの停止時に自動的に再起動するように設定
            engine?.stoppedHandler = { [weak self] reason in
                print("Haptic engine stopped with reason: \(reason.rawValue)")
                guard let self = self else { return }
                
                // エンジンを再起動
                do {
                    try self.engine?.start()
                } catch {
                    print("Failed to restart haptic engine: \(error)")
                }
            }
            
            // アプリがバックグラウンドになった時にエンジンを一時停止
            engine?.resetHandler = { [weak self] in
                print("Haptic engine reset")
                guard let self = self else { return }
                
                do {
                    try self.engine?.start()
                    
                    // 連続フィードバックを再開（必要な場合）
                    self.restartContinuousFeedbackIfNeeded()
                } catch {
                    print("Failed to restart haptic engine after reset: \(error)")
                }
            }
            
            // 連続パターン用のパラメータを初期化
            intensityParameter = CHHapticDynamicParameter(
                parameterID: .hapticIntensityControl,
                value: 0.0,
                relativeTime: 0
            )
            
            sharpnessParameter = CHHapticDynamicParameter(
                parameterID: .hapticSharpnessControl,
                value: 0.0,
                relativeTime: 0
            )
            
        } catch {
            print("Failed to initialize haptic engine: \(error)")
            supportsHaptics = false
        }
    }
    
    // 連続フィードバックの再開（必要な場合）
    private func restartContinuousFeedbackIfNeeded() {
        // フィードバック開始距離を超えたら再開
        if currentDepth < settings.hapticFeedback.startDistance {
            updateContinuousFeedback(for: currentDepth)
        }
    }
    
    // MARK: - パブリックインターフェース
    
    /// 深度に基づいてハプティックフィードバックを更新
    func updateFeedbackForDepth(_ depth: Float) {
        guard settings.hapticFeedback.isEnabled else { return }
        
        // 現在の深度を保存
        currentDepth = depth
        
        // コアハプティックをサポートしている場合は連続フィードバックを更新
        if supportsHaptics {
            updateContinuousFeedback(for: depth)
        } else {
            // 従来のタイマーベースフィードバック
            updateLegacyFeedback(for: depth)
        }
    }
    
    // MARK: - 従来のシンプルな触覚フィードバック（レガシーサポート）
    
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
        
        // CoreHapticsのフィードバックも停止
        stopContinuousFeedback()
    }
    
    // レガシーフィードバックの更新
    private func updateLegacyFeedback(for depth: Float) {
        // フィードバック開始距離より遠い場合はフィードバックなし
        if depth >= settings.hapticFeedback.startDistance {
            stopAll()
            return
        }
        
        // 距離に応じて指数関数的にフィードバック間隔を短くする
        let normalizedDepth = depth / settings.hapticFeedback.startDistance
        let progress = 1.0 - normalizedDepth // 1.0に近いほど近距離
        
        // 冪乗則（べき乗則）を適用 - スティーブンスの法則に基づく変化
        // 冪指数0.5は平方根と同等で、人間の知覚に自然な変化を生み出す
        let naturalProgress = pow(progress, 0.5)
        
        if naturalProgress > 0.7 { // 非常に近い
            stopWarningHapticFeedback()
            
            // 間隔を距離に応じて動的に調整
            let adjustedInterval = max(0.05, settings.hapticFeedback.nearInterval * (1 - Double(naturalProgress)))
            setupTimer(
                &hapticCriticalTimer,
                interval: adjustedInterval,
                style: settings.hapticFeedback.nearIntensity.uiStyle
            )
        } else if naturalProgress > 0.3 { // 中距離
            stopCriticalHapticFeedback()
            
            // 間隔を距離に応じて動的に調整
            let adjustedInterval = max(0.2, settings.hapticFeedback.mediumInterval * (1 - Double(naturalProgress)))
            setupTimer(
                &hapticWarningTimer,
                interval: adjustedInterval,
                style: settings.hapticFeedback.mediumIntensity.uiStyle
            )
        } else {
            // 遠い距離の場合は間欠的なフィードバック
            stopCriticalHapticFeedback()
            setupTimer(
                &hapticWarningTimer,
                interval: settings.hapticFeedback.mediumInterval * 2,
                style: .light
            )
        }
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
            } else {
                // 現在の深度に基づいてフィードバックを更新
                updateFeedbackForDepth(currentDepth)
            }
        } else if settings.hapticFeedback.isEnabled {
            // 設定が変更された場合はフィードバックを更新
            updateFeedbackForDepth(currentDepth)
        }
    }
    
    // MARK: - タイマー設定ヘルパー
    
    private func setupTimer(_ timer: inout Timer?, interval: TimeInterval, style: UIImpactFeedbackGenerator.FeedbackStyle) {
        guard timer == nil else { return }
        
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { _ in
            UIImpactFeedbackGenerator(style: style).impactOccurred()
        }
    }
    
    // MARK: - コアハプティックスによる高度なフィードバック
    
    private func updateContinuousFeedback(for depth: Float) {
        guard supportsHaptics,
              settings.hapticFeedback.isEnabled,
              let _ = engine else {
            return
        }
        
        // フィードバック開始距離を超えたら停止
        if depth >= settings.hapticFeedback.startDistance {
            stopContinuousFeedback()
            return
        }
        
        do {
            // 正規化された距離 (0.0 - 1.0)
            let normalizedDepth = depth / settings.hapticFeedback.startDistance
            let progress = 1.0 - normalizedDepth // 1.0に近いほど近距離
            
            // 冪乗則（べき乗則）を適用 - 人間の知覚に沿った自然な変化を実現
            // スティーブンスの冪法則に基づき、0.5程度の指数を使用
            // これにより線形よりも緩やかで、指数関数ほど急激でない、より自然な感覚変化が得られる
            let naturalProgress = pow(progress, 0.5)
            
            // シャープネスも距離によって調整（より自然な変化）
            let sharpness = 0.2 + (naturalProgress * 0.8) // 0.2-1.0の範囲
            
            // 強度を計算 (高い値ほど強い振動、0.0-1.0の範囲に制限)
            let intensity = min(1.0, max(0.1, naturalProgress))
            
            // 連続フィードバックが既に実行中の場合はパラメータを更新、そうでなければ新規作成
            if let player = continuousPlayer {
                try player.sendParameters([
                    CHHapticDynamicParameter(parameterID: .hapticIntensityControl, value: Float(intensity), relativeTime: 0),
                    CHHapticDynamicParameter(parameterID: .hapticSharpnessControl, value: Float(sharpness), relativeTime: 0)
                ], atTime: CHHapticTimeImmediate)
            } else {
                // 新しいパターンを作成して再生開始
                try startContinuousFeedback(intensity: intensity, sharpness: sharpness)
            }
            
        } catch {
            print("Failed to update haptic feedback: \(error)")
            
            // エラーが発生した場合は連続フィードバックを止めて再作成を試みる
            stopContinuousFeedback()
            
            do {
                // 一定の初期値で再開を試みる
                try startContinuousFeedback(intensity: 0.5, sharpness: 0.5)
            } catch {
                print("Failed to restart haptic feedback: \(error)")
            }
        }
    }

    
    private func startContinuousFeedback(intensity: Float, sharpness: Float) throws {
        guard supportsHaptics, let engine = engine else { return }
        
        // 既存のプレイヤーを停止
        stopContinuousFeedback()
        
        // 連続的な触覚パターンの作成
        let continuousEvent = CHHapticEvent(
            eventType: .hapticContinuous,
            parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: sharpness)
            ],
            relativeTime: 0,
            duration: 100.0 // 長い持続時間（実際には更新または停止されるまで）
        )
        
        let pattern = try CHHapticPattern(events: [continuousEvent], parameters: [])
        continuousPlayer = try engine.makeAdvancedPlayer(with: pattern)
        
        // タイミングに関するコールバックを設定（複雑なパターンの場合）
        continuousPlayer?.completionHandler = { [weak self] _ in
            print("Continuous haptic pattern playback completed")
            self?.continuousPlayer = nil
        }
        
        // 再生開始
        try continuousPlayer?.start(atTime: CHHapticTimeImmediate)
    }
    
    private func stopContinuousFeedback() {
        guard let player = continuousPlayer else { return }
        
        do {
            try player.stop(atTime: CHHapticTimeImmediate)
        } catch {
            print("Failed to stop continuous haptic feedback: \(error)")
        }
        continuousPlayer = nil
    }

    deinit {
        stopAll()
        
        // CoreHapticsエンジンを停止
        if let engine = engine {
            engine.stop()
        }
    }
}

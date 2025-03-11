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
        // 連続フィードバックが有効だった場合は再開
        if currentDepth < settings.spatialAudio.mediumThreshold {
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
        if depth < settings.spatialAudio.nearThreshold {
            handleCriticalState()
        } else if depth < settings.spatialAudio.mediumThreshold {
            handleWarningState()
        } else {
            stopAll()
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
        
        // 連続フィードバックが不要な距離の場合は停止
        if depth >= settings.spatialAudio.mediumThreshold {
            stopContinuousFeedback()
            return
        }
        
        do {
            // 距離に応じてパラメータを調整
            let normalizedDistance: Float
            let sharpness: Float
            
            if depth < settings.spatialAudio.nearThreshold {
                // 近距離: 強い振動と高いシャープネス
                normalizedDistance = 1.0 - (depth / settings.spatialAudio.nearThreshold)
                sharpness = 0.8 + (normalizedDistance * 0.2) // 0.8-1.0
            } else {
                // 中距離: 中程度の振動と中程度のシャープネス
                normalizedDistance = 1.0 - ((depth - settings.spatialAudio.nearThreshold) /
                                         (settings.spatialAudio.mediumThreshold - settings.spatialAudio.nearThreshold))
                sharpness = 0.5 + (normalizedDistance * 0.3) // 0.5-0.8
            }
            
            // 強度は距離から計算（近いほど強い）
            let intensity = min(1.0, max(0.3, normalizedDistance))
            
            // 連続フィードバックが既に実行中の場合はパラメータを更新、そうでなければ新規作成
            if let player = continuousPlayer {
                try player.sendParameters([
                    CHHapticDynamicParameter(parameterID: .hapticIntensityControl, value: Float(intensity), relativeTime: 0),
                    CHHapticDynamicParameter(parameterID: .hapticSharpnessControl, value: Float(sharpness), relativeTime: 0)
                ], atTime: CHHapticTimeImmediate) // atTimeパラメータを追加
            } else {
                // 新しいパターンを作成して再生開始
                try startContinuousFeedback(intensity: intensity, sharpness: sharpness) // tryを追加
            }
            
        } catch {
            print("Failed to update haptic feedback: \(error)")
            
            // エラーが発生した場合は連続フィードバックを止めて再作成を試みる
            stopContinuousFeedback()
            
            do {
                // 一定の初期値で再開を試みる
                try startContinuousFeedback(intensity: 0.5, sharpness: 0.5) // tryを追加
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

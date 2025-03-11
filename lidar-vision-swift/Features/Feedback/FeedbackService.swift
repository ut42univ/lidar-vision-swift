import AudioToolbox
import UIKit
import CoreHaptics

/// 触覚フィードバックを管理するサービス - CoreHapticsのみを使用
final class FeedbackService {
    private var settings: AppSettings
    
    // CoreHaptics関連
    private var engine: CHHapticEngine?
    private var supportsHaptics: Bool = false
    private var continuousPlayer: CHHapticAdvancedPatternPlayer?
    private var intensityParameter: CHHapticDynamicParameter?
    private var sharpnessParameter: CHHapticDynamicParameter?
    private var currentDepth: Float = 10.0 // 初期値は十分に遠い
    
    // 状態管理用
    private var isActive = false
    
    init(settings: AppSettings = AppSettings()) {
        self.settings = settings
        
        // デバイスがHapticsをサポートしているか確認
        checkDeviceCapabilities()
        
        // CoreHapticsをサポートしている場合はエンジンを初期化
        if supportsHaptics {
            setupHapticEngine()
        } else {
            print("Device does not support CoreHaptics - no haptic feedback will be available")
        }
        
        print("FeedbackService initialized")
    }
    
    // MARK: - デバイス機能チェック
    
    private func checkDeviceCapabilities() {
        // CoreHapticsのサポート状況チェック
        supportsHaptics = CHHapticEngine.capabilitiesForHardware().supportsHaptics
        print("Device supports CoreHaptics: \(supportsHaptics)")
    }
    
    // MARK: - CoreHapticsエンジンのセットアップ
    
    private func setupHapticEngine() {
        guard supportsHaptics, engine == nil else { return }
        
        do {
            engine = try CHHapticEngine()
            try engine?.start()
            
            print("Haptic engine started successfully")
            
            // エンジンの停止時に自動的に再起動するように設定
            engine?.stoppedHandler = { [weak self] reason in
                print("Haptic engine stopped with reason: \(reason.rawValue)")
                guard let self = self, self.isActive else { return }
                
                // エンジンを再起動
                do {
                    try self.engine?.start()
                    print("Haptic engine restarted")
                } catch {
                    print("Failed to restart haptic engine: \(error)")
                }
            }
            
            // アプリがバックグラウンドになった時にエンジンを一時停止
            engine?.resetHandler = { [weak self] in
                print("Haptic engine reset")
                guard let self = self, self.isActive else { return }
                
                do {
                    try self.engine?.start()
                    print("Haptic engine started after reset")
                    
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
        if isActive && currentDepth < settings.hapticFeedback.startDistance {
            updateContinuousFeedback(for: currentDepth)
        }
    }
    
    // MARK: - パブリックインターフェース
    
    /// フィードバックの有効化 - 設定画面から戻るときに呼び出す
    func activateFeedback() {
        print("Activating feedback service")
        isActive = true
        
        // CoreHapticsが使用できない場合は処理を行わない
        guard supportsHaptics else { return }
        
        // エンジンが停止している場合は再開
        if engine == nil {
            setupHapticEngine()
        } else {
            do {
                try engine?.start()
                print("Restarted haptic engine on activation")
            } catch {
                print("Failed to restart haptic engine: \(error)")
            }
        }
        
        // 最新の深度情報に基づいてフィードバックを更新
        if currentDepth < settings.hapticFeedback.startDistance {
            updateContinuousFeedback(for: currentDepth)
        }
    }
    
    /// フィードバックの無効化 - 設定画面に移行する前に呼び出す
    func deactivateFeedback() {
        print("Deactivating feedback service")
        isActive = false
        stopAll()
        
        // CoreHapticsエンジンを停止
        if let engine = self.engine {
            engine.stop()
            continuousPlayer = nil
            print("Stopped haptic engine on deactivation")
        }
    }
    
    /// 深度に基づいてハプティックフィードバックを更新
    func updateFeedbackForDepth(_ depth: Float) {
        guard isActive && settings.hapticFeedback.isEnabled && supportsHaptics else { return }
        
        // 現在の深度を保存
        currentDepth = depth
        
        // CoreHapticsによるフィードバック更新
        updateContinuousFeedback(for: depth)
    }
    
    /// すべてのフィードバックを停止
    func stopAll() {
        print("Stopping all haptic feedback")
        stopContinuousFeedback()
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
            } else if isActive && supportsHaptics {
                // 現在の深度に基づいてフィードバックを更新
                updateFeedbackForDepth(currentDepth)
            }
        } else if settings.hapticFeedback.isEnabled && isActive && supportsHaptics {
            // 設定が変更された場合はフィードバックを更新
            updateFeedbackForDepth(currentDepth)
        }
    }
    
    // MARK: - コアハプティックスによるフィードバック
    
    private func updateContinuousFeedback(for depth: Float) {
        guard supportsHaptics,
              isActive,
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
            
            // エンジンが正常に機能していない可能性があるため、再起動を試みる
            print("Attempting to restart the haptic engine")
            do {
                try engine?.start()
            } catch {
                print("Failed to restart engine: \(error)")
            }
            
            do {
                // 一定の初期値で再開を試みる
                try startContinuousFeedback(intensity: 0.5, sharpness: 0.5)
            } catch {
                print("Failed to restart haptic feedback: \(error)")
            }
        }
    }

    
    private func startContinuousFeedback(intensity: Float, sharpness: Float) throws {
        guard supportsHaptics, let engine = engine, isActive else { return }
        
        // 既存のプレイヤーを停止
        stopContinuousFeedback()
        
        print("Starting continuous feedback with intensity: \(intensity), sharpness: \(sharpness)")
        
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
            print("Stopped continuous haptic feedback")
        } catch {
            print("Failed to stop continuous haptic feedback: \(error)")
        }
        continuousPlayer = nil
    }

    deinit {
        print("FeedbackService deinitializing")
        stopAll()
        
        // CoreHapticsエンジンを停止
        if let engine = engine {
            engine.stop()
        }
    }
}

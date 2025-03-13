import AudioToolbox
import UIKit
import CoreHaptics

/// 触覚フィードバックを管理するサービス - CoreHapticsを効率的に使用
final class FeedbackService {
    private var settings: AppSettings
    
    // CoreHaptics関連
    private var engine: CHHapticEngine?
    private var continuousPlayer: CHHapticAdvancedPatternPlayer?
    private var currentDepth: Float = 10.0 // 初期値は十分に遠い
    
    // 状態管理用
    private var isActive = false
    private var supportsHaptics = false
    private var engineRunning = false
    
    init(settings: AppSettings = AppSettings()) {
        self.settings = settings
        
        // デバイス機能チェックとセットアップを実行
        setupHaptics()
    }
    
    // MARK: - セットアップ
    
    private func setupHaptics() {
        // デバイスがHapticsをサポートしているか確認
        supportsHaptics = CHHapticEngine.capabilitiesForHardware().supportsHaptics
        
        // サポートしている場合のみエンジンをセットアップ
        if supportsHaptics {
            setupHapticEngine()
        } else {
            print("Device does not support CoreHaptics - no haptic feedback will be available")
        }
    }
    
    private func setupHapticEngine() {
        guard supportsHaptics, engine == nil else { return }
        
        do {
            // エンジンの作成と初期設定
            engine = try CHHapticEngine()
            
            try engine?.start()
            engineRunning = true
            print("Haptic engine started successfully")
            
            // イベントハンドラを設定
            setupEngineHandlers()
            
        } catch {
            print("Failed to initialize haptic engine: \(error)")
            supportsHaptics = false
            engineRunning = false
        }
    }

    
    private func setupEngineHandlers() {
        // 必要なエラーハンドラをすべて設定
        setupStoppedHandler()
        setupResetHandler()
    }
    
    private func setupStoppedHandler() {
        engine?.stoppedHandler = { [weak self] reason in
            print("Haptic engine stopped with reason: \(reason.rawValue)")
            guard let self = self, self.isActive else { return }
            
            self.engineRunning = false
            
            // エンジンを再起動
            do {
                try self.engine?.start()
                self.engineRunning = true
                print("Haptic engine restarted")
            } catch {
                print("Failed to restart haptic engine: \(error)")
            }
        }
    }
    
    private func setupResetHandler() {
        engine?.resetHandler = { [weak self] in
            print("Haptic engine reset")
            guard let self = self, self.isActive else { return }
            
            self.engineRunning = false
            
            do {
                try self.engine?.start()
                self.engineRunning = true
                print("Haptic engine started after reset")
                
                // 連続フィードバックを再開（必要な場合）
                self.restartContinuousFeedbackIfNeeded()
            } catch {
                print("Failed to restart haptic engine after reset: \(error)")
            }
        }
    }
    
    // 連続フィードバックの再開（必要な場合）
    private func restartContinuousFeedbackIfNeeded() {
        // フィードバック開始距離を超えたら再開
        if isActive && currentDepth < settings.hapticFeedback.startDistance && settings.hapticFeedback.isEnabled {
            updateContinuousFeedback(for: currentDepth)
        }
    }
    
    // MARK: - パブリックインターフェース
    
    /// フィードバックの有効化
    func activateFeedback() {
        print("Activating feedback service")
        isActive = true
        
        // CoreHapticsが使用できない場合は処理を行わない
        guard supportsHaptics else { return }
        
        // エンジンが停止している場合は再開
        if engine == nil {
            setupHapticEngine()
        } else if !engineRunning {
            do {
                try engine?.start()
                engineRunning = true
                print("Restarted haptic engine on activation")
            } catch {
                print("Failed to restart haptic engine: \(error)")
            }
        }
        
        // 最新の深度情報に基づいてフィードバックを更新
        restartContinuousFeedbackIfNeeded()
    }
    
    /// フィードバックの無効化
    func deactivateFeedback() {
        print("Deactivating feedback service")
        isActive = false
        stopAll()
        
        // CoreHapticsエンジンを停止
        if let engine = engine, engineRunning {
            engine.stop()
            engineRunning = false
            print("Stopped haptic engine on deactivation")
        }
    }
    
    /// 深度に基づいてハプティックフィードバックを更新
    func updateFeedbackForDepth(_ depth: Float) {
        // 必要条件のチェックを効率化
        guard
            isActive &&
            settings.hapticFeedback.isEnabled &&
            supportsHaptics
        else {
            return
        }
        
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
        
        // 有効状態が変更された場合の処理
        handleSettingsChange(previouslyEnabled: wasEnabled)
    }
    
    // 設定変更に対応
    private func handleSettingsChange(previouslyEnabled: Bool) {
        // 有効状態が変更された場合
        if previouslyEnabled != settings.hapticFeedback.isEnabled {
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
    
    // MARK: - CoreHapticsによるフィードバック
    
    private func updateContinuousFeedback(for depth: Float) {
        guard supportsHaptics,
              isActive,
              settings.hapticFeedback.isEnabled,
              engineRunning else {
            return
        }
        
        // フィードバック開始距離を超えたら停止
        if depth >= settings.hapticFeedback.startDistance {
            stopContinuousFeedback()
            return
        }
        
        do {
            // 正規化された距離に基づくパラメータ計算
            let (intensity, sharpness) = calculateHapticParameters(for: depth)
            
            // 既存のプレイヤーがあればパラメータを更新、なければ新規作成
            if let player = continuousPlayer {
                try updateExistingPlayer(player, intensity: intensity, sharpness: sharpness)
            } else {
                try createNewPlayer(intensity: intensity, sharpness: sharpness)
            }
            
        } catch {
            print("Failed to update haptic feedback: \(error)")
            handleHapticError()
        }
    }
    
    // 振動強度と鋭さを計算
    private func calculateHapticParameters(for depth: Float) -> (intensity: Float, sharpness: Float) {
        // 正規化された距離 (0.0 - 1.0)
        let normalizedDepth = depth / settings.hapticFeedback.startDistance
        let progress = 1.0 - normalizedDepth // 1.0に近いほど近距離
        
        // 冪乗則（べき乗則）を適用 - 人間の知覚に沿った自然な変化を実現
        // スティーブンスの冪法則に基づき、0.5程度の指数を使用
        let naturalProgress = pow(progress, 0.5)
        
        // シャープネスも距離によって調整（より自然な変化）
        let sharpness = 0.2 + (naturalProgress * 0.8) // 0.2-1.0の範囲
        
        // 強度を計算 (高い値ほど強い振動、0.0-1.0の範囲に制限)
        let intensity = min(1.0, max(0.1, naturalProgress))
        
        return (intensity, sharpness)
    }
    
    // 既存プレイヤーのパラメータを更新
    private func updateExistingPlayer(_ player: CHHapticAdvancedPatternPlayer, intensity: Float, sharpness: Float) throws {
        try player.sendParameters([
            CHHapticDynamicParameter(parameterID: .hapticIntensityControl, value: intensity, relativeTime: 0),
            CHHapticDynamicParameter(parameterID: .hapticSharpnessControl, value: sharpness, relativeTime: 0)
        ], atTime: CHHapticTimeImmediate)
    }
    
    // 新しいプレイヤーを作成
    private func createNewPlayer(intensity: Float, sharpness: Float) throws {
        guard let engine = engine else { return }
        
        // 連続的な触覚パターンの作成
        let continuousEvent = CHHapticEvent(
            eventType: .hapticContinuous,
            parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: sharpness)
            ],
            relativeTime: 0,
            duration: 100.0 // 十分長い持続時間
        )
        
        let pattern = try CHHapticPattern(events: [continuousEvent], parameters: [])
        continuousPlayer = try engine.makeAdvancedPlayer(with: pattern)
        
        // 再生完了時のコールバック
        continuousPlayer?.completionHandler = { [weak self] _ in
            self?.continuousPlayer = nil
        }
        
        // 再生開始
        try continuousPlayer?.start(atTime: CHHapticTimeImmediate)
    }
    
    // エラー発生時の処理
    private func handleHapticError() {
        // 既存のプレイヤーをクリーンアップ
        stopContinuousFeedback()
        
        // エンジンの再起動を試みる
        do {
            if let engine = engine {
                try engine.start()
                
                // 数値を初期値に戻して再開を試みる
                try startContinuousFeedback(intensity: 0.5, sharpness: 0.5)
            }
        } catch {
            print("Failed to recover from haptic error: \(error)")
        }
    }
    
    // シンプルな連続フィードバック開始
    private func startContinuousFeedback(intensity: Float, sharpness: Float) throws {
        guard let engine = engine, isActive else { return }
        
        stopContinuousFeedback()
        
        // 連続的な触覚パターンの作成
        let continuousEvent = CHHapticEvent(
            eventType: .hapticContinuous,
            parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: sharpness)
            ],
            relativeTime: 0,
            duration: 100.0
        )
        
        let pattern = try CHHapticPattern(events: [continuousEvent], parameters: [])
        continuousPlayer = try engine.makeAdvancedPlayer(with: pattern)
        
        try continuousPlayer?.start(atTime: CHHapticTimeImmediate)
    }
    
    // 連続フィードバックの停止
    private func stopContinuousFeedback() {
        guard let player = continuousPlayer else { return }
        
        do {
            try player.stop(atTime: CHHapticTimeImmediate)
        } catch {
            print("Failed to stop continuous haptic feedback: \(error)")
        }
        continuousPlayer = nil
    }
    
    /// 近すぎる場合のフィードバックをトリガー
    func triggerTooCloseFeedback() {
        guard supportsHaptics, isActive, settings.hapticFeedback.isEnabled, engineRunning else {
            return
        }
        
        do {
            let pattern = try createTooClosePattern()
            let player = try engine?.makePlayer(with: pattern)
            try player?.start(atTime: CHHapticTimeImmediate)
        } catch {
            print("Failed to trigger too close haptic feedback: \(error)")
        }
    }

    private func createTooClosePattern() throws -> CHHapticPattern {
        let sharpness = CHHapticEventParameter(parameterID: .hapticSharpness, value: 1.0)
        let intensity = CHHapticEventParameter(parameterID: .hapticIntensity, value: 1.0)
        
        let event = CHHapticEvent(eventType: .hapticTransient, parameters: [sharpness, intensity], relativeTime: 0)
        
        return try CHHapticPattern(events: [event], parameters: [])
    }
    
    deinit {
        print("FeedbackService deinitializing")
        stopAll()
        
        if let engine = engine {
            engine.stop()
        }
    }
}

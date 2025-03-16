import SwiftUI
import CoreHaptics
import Combine

/// 触覚フィードバックを管理する、SwiftUIフレンドリーなサービス
final class HapticFeedbackService: ObservableObject {
    // MARK: - Published Properties
    
    @Published private(set) var isActive = false
    @Published private(set) var currentDepth: Float = 10.0
    @Published private(set) var isHapticAvailable = false
    
    // MARK: - Settings
    
    private var settings: AppSettings
    
    // MARK: - CoreHaptics
    
    private var engine: CHHapticEngine?
    private var continuousPlayer: CHHapticAdvancedPatternPlayer?
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    init(settings: AppSettings) {
        self.settings = settings
        setupHaptics()
        setupSettingsObserver()
    }
    
    private func setupSettingsObserver() {
        // ハプティック設定の変更を監視
        settings.$hapticFeedback
            .sink { [weak self] newSettings in
                self?.handleSettingsUpdate(newSettings)
            }
            .store(in: &cancellables)
    }
    
    private func handleSettingsUpdate(_ hapticSettings: AppSettings.HapticFeedback) {
        // 実行中の場合は更新された設定を適用
        if isActive {
            updateFeedbackForCurrentDepth()
        }
    }
    
    // MARK: - Haptics Setup
    
    private func setupHaptics() {
        // ハプティック機能のサポートをチェック
        isHapticAvailable = CHHapticEngine.capabilitiesForHardware().supportsHaptics
        
        guard isHapticAvailable else {
            print("設備はCoreHapticsをサポートしていません")
            return
        }
        
        do {
            engine = try CHHapticEngine()
            try setupHapticEngine()
        } catch {
            print("ハプティックエンジンの初期化に失敗しました: \(error.localizedDescription)")
            isHapticAvailable = false
        }
    }
    
    private func setupHapticEngine() throws {
        guard let engine = engine else { return }
        
        try engine.start()
        
        // エンジンが停止した場合のハンドラを設定
        engine.stoppedHandler = { [weak self] reason in
            print("ハプティックエンジンが停止しました: \(reason)")
            self?.handleEngineStop()
        }
        
        // エンジンがリセットされた場合のハンドラを設定
        engine.resetHandler = { [weak self] in
            print("ハプティックエンジンがリセットされました")
            self?.handleEngineReset()
        }
    }
    
    private func handleEngineStop() {
        guard isActive else { return }
        
        DispatchQueue.main.async {
            do {
                try self.engine?.start()
                print("ハプティックエンジンを再起動しました")
                self.restartFeedbackIfNeeded()
            } catch {
                print("ハプティックエンジンの再起動に失敗しました: \(error.localizedDescription)")
            }
        }
    }
    
    private func handleEngineReset() {
        guard isActive else { return }
        
        DispatchQueue.main.async {
            do {
                try self.engine?.start()
                print("リセット後にハプティックエンジンを開始しました")
                self.restartFeedbackIfNeeded()
            } catch {
                print("リセット後のハプティックエンジンの開始に失敗しました: \(error.localizedDescription)")
            }
        }
    }
    
    private func restartFeedbackIfNeeded() {
        // 現在の深度に基づいてフィードバックを再開
        let shouldRestart = isActive &&
                            settings.hapticFeedback.isEnabled &&
                            currentDepth < settings.hapticFeedback.startDistance
        
        if shouldRestart {
            updateFeedbackForCurrentDepth()
        }
    }
    
    // MARK: - Public Interface
    
    /// フィードバックを有効化
    func activate() {
        guard !isActive else { return }
        
        isActive = true
        print("ハプティックフィードバックを有効化しました")
        
        // エンジンが必要な場合は起動
        if isHapticAvailable && engine == nil {
            setupHaptics()
        }
        
        // 最新の深度情報に基づいてフィードバックを開始
        updateFeedbackForCurrentDepth()
    }
    
    /// フィードバックを無効化
    func deactivate() {
        guard isActive else { return }
        
        isActive = false
        print("ハプティックフィードバックを無効化しました")
        
        // 実行中のフィードバックを停止
        stopAllFeedback()
        
        // エンジンを停止して省電力化
        engine?.stop()
    }
    
    /// 深度に基づいてフィードバックを更新
    func updateForDepth(_ depth: Float) {
        // 現在の深度を保存（再開時などに使用）
        currentDepth = depth
        
        // 必要な場合のみ処理を実行
        updateFeedbackForCurrentDepth()
        
        // 近すぎる場合の特別な警告
        if settings.hapticFeedback.isEnabled &&
           depth < settings.hapticFeedback.tooCloseDistance {
            triggerTooCloseWarning()
        }
    }
    
    /// すべてのフィードバックを停止
    func stopAllFeedback() {
        stopContinuousFeedback()
    }
    
    /// 設定を更新
    func updateSettings(_ newSettings: AppSettings) {
        let wasEnabled = settings.hapticFeedback.isEnabled
        settings = newSettings
        
        // 有効状態が変更された場合
        if wasEnabled != settings.hapticFeedback.isEnabled {
            if settings.hapticFeedback.isEnabled {
                if isActive {
                    updateFeedbackForCurrentDepth()
                }
            } else {
                stopAllFeedback()
            }
        } else if settings.hapticFeedback.isEnabled && isActive {
            // 設定値のみが変更された場合
            updateFeedbackForCurrentDepth()
        }
    }
    
    // MARK: - Haptic Feedback Implementation
    
    private func updateFeedbackForCurrentDepth() {
        // 必要な条件が揃っているか確認
        guard isActive &&
              settings.hapticFeedback.isEnabled &&
              isHapticAvailable &&
              engine != nil else {
            return
        }
        
        // フィードバック開始距離を超えたら停止
        if currentDepth >= settings.hapticFeedback.startDistance {
            stopContinuousFeedback()
            return
        }
        
        do {
            let (intensity, sharpness) = calculateHapticParameters(for: currentDepth)
            
            if let player = continuousPlayer {
                // 既存プレイヤーのパラメータを更新
                try updatePlayerParameters(player, intensity: intensity, sharpness: sharpness)
            } else {
                // 新規プレイヤーを作成
                try createAndStartPlayer(intensity: intensity, sharpness: sharpness)
            }
        } catch {
            print("ハプティックフィードバックの更新に失敗しました: \(error.localizedDescription)")
            handleFeedbackError()
        }
    }
    
    /// ハプティックパラメータを計算
    private func calculateHapticParameters(for depth: Float) -> (intensity: Float, sharpness: Float) {
        // 変数の初期化
        let startDistance = settings.hapticFeedback.startDistance
        let tooCloseDistance = settings.hapticFeedback.tooCloseDistance
        
        // 正規化された距離 (0.0 - 1.0)
        // 開始距離から近すぎる距離までの範囲で正規化
        let normalizedRange = startDistance - tooCloseDistance
        let normalizedDepth = (depth - tooCloseDistance) / normalizedRange
        let progress = min(1.0, max(0.0, 1.0 - normalizedDepth))
        
        // 人間の知覚に合わせて非線形なスケーリングを適用
        let intensityProgress = pow(progress, 0.6) // よりスムーズな変化
        
        // 強度を計算（強度乗数を適用）
        let multiplier = settings.hapticFeedback.intensityMultiplier
        let baseIntensity = min(1.0, max(0.1, intensityProgress))
        let intensity = min(1.0, baseIntensity * multiplier)
        
        // シャープネスも距離に応じて変化
        let sharpness = 0.2 + (intensityProgress * 0.8)
        
        return (intensity, sharpness)
    }
    
    /// 既存プレイヤーのパラメータを更新
    private func updatePlayerParameters(_ player: CHHapticAdvancedPatternPlayer, intensity: Float, sharpness: Float) throws {
        try player.sendParameters([
            CHHapticDynamicParameter(parameterID: .hapticIntensityControl, value: intensity, relativeTime: 0),
            CHHapticDynamicParameter(parameterID: .hapticSharpnessControl, value: sharpness, relativeTime: 0)
        ], atTime: CHHapticTimeImmediate)
    }
    
    /// 新規プレイヤーを作成して開始
    private func createAndStartPlayer(intensity: Float, sharpness: Float) throws {
        guard let engine = engine else { return }
        
        // 連続的なハプティックパターンを作成
        let continuousEvent = CHHapticEvent(
            eventType: .hapticContinuous,
            parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: sharpness)
            ],
            relativeTime: 0,
            duration: 100.0 // 十分な長さ
        )
        
        let pattern = try CHHapticPattern(events: [continuousEvent], parameters: [])
        continuousPlayer = try engine.makeAdvancedPlayer(with: pattern)
        
        // 再生完了時の処理
        continuousPlayer?.completionHandler = { [weak self] _ in
            DispatchQueue.main.async {
                self?.continuousPlayer = nil
            }
        }
        
        // 再生開始
        try continuousPlayer?.start(atTime: CHHapticTimeImmediate)
    }
    
    /// エラー発生時の処理
    private func handleFeedbackError() {
        stopContinuousFeedback()
        
        guard let engine = engine else { return }
        
        // エラー復旧のためのエンジン再起動
        do {
            try engine.start()
            // 安全な値でフィードバックを再開
            try startSimpleFeedback(intensity: 0.5, sharpness: 0.5)
        } catch {
            print("ハプティックエラーからの復旧に失敗しました: \(error.localizedDescription)")
        }
    }
    
    /// 連続フィードバックを停止
    private func stopContinuousFeedback() {
        guard let player = continuousPlayer else { return }
        
        do {
            try player.stop(atTime: CHHapticTimeImmediate)
        } catch {
            print("連続ハプティックフィードバックの停止に失敗しました: \(error.localizedDescription)")
        }
        
        continuousPlayer = nil
    }
    
    /// シンプルなフィードバックを開始（エラー復旧用）
    private func startSimpleFeedback(intensity: Float, sharpness: Float) throws {
        guard let engine = engine, isActive else { return }
        
        // 既存のプレイヤーを停止
        stopContinuousFeedback()
        
        // 新しいシンプルなパターンを作成
        let event = CHHapticEvent(
            eventType: .hapticContinuous,
            parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: sharpness)
            ],
            relativeTime: 0,
            duration: 100.0
        )
        
        let pattern = try CHHapticPattern(events: [event], parameters: [])
        continuousPlayer = try engine.makeAdvancedPlayer(with: pattern)
        
        // 再生開始
        try continuousPlayer?.start(atTime: CHHapticTimeImmediate)
    }
    
    // MARK: - Too Close Warning
    
    /// 近すぎる場合の警告をトリガー
    func triggerTooCloseWarning() {
        guard isActive &&
              settings.hapticFeedback.isEnabled &&
              isHapticAvailable &&
              engine != nil else {
            return
        }
        
        // UIKitフィードバックでの警告（フォールバック用）
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
        
        // CoreHapticsを使った強力な警告
        do {
            let pattern = try createTooClosePattern()
            let player = try engine?.makePlayer(with: pattern)
            try player?.start(atTime: CHHapticTimeImmediate)
        } catch {
            print("近接警告ハプティックの作成に失敗しました: \(error.localizedDescription)")
        }
    }
    
    private func createTooClosePattern() throws -> CHHapticPattern {
        // 強い、シャープな警告パターンを作成
        let events = createIntenseTooCloseEvents()
        return try CHHapticPattern(events: events, parameters: [])
    }
    
    private func createIntenseTooCloseEvents() -> [CHHapticEvent] {
        // 近接警告用のより複雑なイベントシーケンス
        let sharpness = CHHapticEventParameter(parameterID: .hapticSharpness, value: 1.0)
        let intensity = CHHapticEventParameter(parameterID: .hapticIntensity, value: 1.0)
        
        // 3つの短い、強い振動のシーケンスを作成（より注意を引くため）
        var events = [CHHapticEvent]()
        let duration = 0.1
        
        for i in 0..<3 {
            let startTime = Double(i) * (duration + 0.05)
            events.append(CHHapticEvent(
                eventType: .hapticTransient,
                parameters: [sharpness, intensity],
                relativeTime: startTime
            ))
        }
        
        return events
    }
    
    // MARK: - Cleanup
    
    deinit {
        print("HapticFeedbackService deinitializing")
        stopAllFeedback()
        
        cancellables.forEach { $0.cancel() }
        cancellables.removeAll()
        
        engine?.stop()
    }
}

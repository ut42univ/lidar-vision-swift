import SwiftUI
import Combine

/// メイン画面のViewModel
final class ContentViewModel: ObservableObject {
    // MARK: - Published Properties
    
    @Published var capturedImage: UIImage?
    @Published var showPhotoDetail = false
    @Published var showSettings = false
    @Published var appSettings: AppSettings
    
    // MARK: - Dependencies
    
    let sessionService: ARSessionService
    private let feedbackService: FeedbackService
    private let spatialAudioService: SpatialAudioService
    
    // MARK: - Properties
    
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    init(
        sessionService: ARSessionService? = nil,
        feedbackService: FeedbackService? = nil,
        spatialAudioService: SpatialAudioService? = nil
    ) {
        // 設定をロード
        let loadedSettings = AppSettings.load()
        self.appSettings = loadedSettings
        
        // 依存サービスの初期化
        self.spatialAudioService = spatialAudioService ?? SpatialAudioService(settings: loadedSettings)
        self.feedbackService = feedbackService ?? FeedbackService(settings: loadedSettings)
        self.sessionService = sessionService ?? ARSessionService(
            spatialAudioService: self.spatialAudioService
        )
        
        // 初期設定
        setupBindings()
        setupLifecycleObservers()
        applyInitialSettings()
        
        // フィードバックサービスをアクティブ化
        self.feedbackService.activateFeedback()
    }
    
    // MARK: - Setup Methods
    
    private func setupBindings() {
        // セッションの変更を監視 - メインスレッドでの処理を保証
        sessionService.objectWillChange
            .receive(on: RunLoop.main)  // メインスレッドでの処理を保証
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
        
        // 深度の変更を監視 - スロットリングを追加
        sessionService.$centerDepth
            .receive(on: RunLoop.main)
            .throttle(for: .milliseconds(100), scheduler: RunLoop.main, latest: true)  // 頻繁な更新を制限
            .sink { [weak self] newDepth in
                self?.handleDepthChange(newDepth: newDepth)
            }
            .store(in: &cancellables)
    }
    
    private func setupLifecycleObservers() {
        // アプリのライフサイクル監視を一箇所にまとめる
        let notificationCenter = NotificationCenter.default
        
        // バックグラウンドへの移行
        notificationCenter.publisher(for: UIApplication.willResignActiveNotification)
            .sink { [weak self] _ in self?.pauseARSession() }
            .store(in: &cancellables)
        
        // フォアグラウンドへの復帰
        notificationCenter.publisher(for: UIApplication.didBecomeActiveNotification)
            .sink { [weak self] _ in self?.resumeARSession() }
            .store(in: &cancellables)
        
        // メモリ警告
        notificationCenter.publisher(for: UIApplication.didEnterBackgroundNotification)
            .sink { [weak self] _ in self?.sessionService.resetMeshCache() }
            .store(in: &cancellables)
    }
    
    private func applyInitialSettings() {
        // 初期設定を適用
        sessionService.spatialAudioEnabled = appSettings.spatialAudio.isEnabled
        spatialAudioService.setVolumeMultiplier(appSettings.spatialAudio.volume)
    }
    
    // MARK: - Public API
    
    /// ARセッションを一時停止
    func pauseARSession() {
        print("ContentViewModel: pauseARSession called")
        
        // フィードバックサービスを非アクティブ化
        feedbackService.deactivateFeedback()
        
        // ARセッションを一時停止
        sessionService.pauseSession()
    }

    /// ARセッションを再開
    func resumeARSession() {
        print("ContentViewModel: resumeARSession called")
        
        // フィードバックサービスを再アクティブ化
        feedbackService.activateFeedback()
        
        // ARセッションを再開
        sessionService.resumeSession()
    }
    
    // 写真を撮影して自動分析
    func captureAndAnalyzePhoto() {
        // 撮影前にフィードバックを一時停止
        feedbackService.stopAll()
        
        // セッションチェックと撮影プロセスを一元化
        ensureSessionAndCapture { success in
            if success {
                // 撮影成功フィードバック（振動）
                UINotificationFeedbackGenerator().notificationOccurred(.success)
            }
        }
    }
    
    // セッション状態を確認してから撮影する共通ロジック
    private func ensureSessionAndCapture(completion: @escaping (Bool) -> Void) {
        // 撮影前にARSessionが動作していることを確認
        if !sessionService.isSessionRunning {
            sessionService.resumeSession()
            
            // セッションの再開に少し時間を与える
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.performCapture(completion: completion)
            }
        } else {
            // 通常通り撮影
            performCapture(completion: completion)
        }
    }
    
    // 実際の撮影処理
    private func performCapture(completion: (Bool) -> Void) {
        if let image = sessionService.capturePhoto() {
            capturedImage = image
            showPhotoDetail = true
            completion(true)
        } else {
            completion(false)
        }
    }
    
    // 3Dメッシュの可視性を切り替え
    func toggleMeshVisibility() {
        sessionService.toggleMeshVisibility()
    }
    
    // 空間オーディオを切り替え
    func toggleSpatialAudio() {
        appSettings.spatialAudio.isEnabled.toggle()
        updateServices()
        sessionService.toggleSpatialAudio()
        saveSettings()
    }
    
    // メッシュキャッシュをリセット
    func resetMeshCache() {
        sessionService.resetMeshCache()
    }
    
    // 設定が更新されたときの処理
    func updateSettings(_ newSettings: AppSettings) {
        self.appSettings = newSettings
        updateServices()
        saveSettings()
    }
    
    // サービスに設定を反映
    private func updateServices() {
        spatialAudioService.updateSettings(appSettings)
        feedbackService.updateSettings(appSettings)
        
        // 空間オーディオの状態を更新（必要な場合のみ）
        if sessionService.spatialAudioEnabled != appSettings.spatialAudio.isEnabled {
            sessionService.toggleSpatialAudio()
        }
    }
    
    // 設定を保存
    private func saveSettings() {
        appSettings.save()
    }
    
    private func handleDepthChange(newDepth: Float) {
        // フィードバックサービスを通じて深度情報を更新
        feedbackService.updateFeedbackForDepth(newDepth)
        
        // 近すぎる場合のフィードバックを追加
        if newDepth < appSettings.hapticFeedback.tooCloseDistance {
            feedbackService.triggerTooCloseFeedback()
        }
    }
    
    deinit {
        print("ContentViewModel deinitializing")
        feedbackService.deactivateFeedback()
    }
}

// MARK: - Computed Properties
extension ContentViewModel {
    // メッシュの可視性を取得
    var isMeshVisible: Bool {
        sessionService.isMeshVisible
    }
    
    // 空間オーディオの有効状態を取得
    var isSpatialAudioEnabled: Bool {
        sessionService.spatialAudioEnabled
    }
}

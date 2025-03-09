import SwiftUI
import Combine

/// メイン画面のViewModel
final class ContentViewModel: ObservableObject {
    // 公開プロパティ
    @Published var capturedImage: UIImage?
    @Published var showPhotoDetail = false
    @Published var showSettings = false
    @Published var appSettings: AppSettings
    
    // 固定プロパティ
    let alertColor: Color = .white
    
    // サービス参照
    let sessionService: ARSessionService
    private let feedbackService: FeedbackService
    private let spatialAudioService: SpatialAudioService
    
    // 内部状態
    private var cancellables = Set<AnyCancellable>()
    
    // 深度閾値（メートル単位）
    private var warningDepthThreshold: Float {
        return appSettings.spatialAudio.mediumThreshold
    }
    private var criticalDepthThreshold: Float {
        return appSettings.spatialAudio.nearThreshold
    }
    
    init() {
        // 設定をロード
        let loadedSettings = AppSettings.load()
        
        // すべての格納プロパティを初期化
        let audioService = SpatialAudioService(settings: loadedSettings)
        let feedback = FeedbackService(settings: loadedSettings)
        
        // プロパティに代入
        self.appSettings = loadedSettings
        self.spatialAudioService = audioService
        self.feedbackService = feedback
        self.sessionService = ARSessionService(
            spatialAudioService: audioService
        )
        
        // セッションの変更を監視
        sessionService.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)
        
        // 深度の変更を監視
        sessionService.$centerDepth
            .receive(on: RunLoop.main)
            .sink { [weak self] newDepth in
                self?.handleDepthChange(newDepth: newDepth)
            }
            .store(in: &cancellables)
        
        // 空間オーディオの設定を反映
        sessionService.spatialAudioEnabled = appSettings.spatialAudio.isEnabled
        spatialAudioService.setVolumeMultiplier(appSettings.spatialAudio.volume)
        
        // アプリがバックグラウンドに移動したときにメッシュをリセット
        NotificationCenter.default.addObserver(
            forName: UIApplication.didEnterBackgroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.sessionService.resetMeshCache()
        }
    }
    
    // 深度変更に対応
    private func handleDepthChange(newDepth: Float) {
        if newDepth < criticalDepthThreshold {
            feedbackService.handleCriticalState()
        } else if newDepth < warningDepthThreshold {
            feedbackService.handleWarningState()
        } else {
            feedbackService.stopAll()
        }
    }
    
    // 写真を撮影
    func capturePhoto() {
        if let image = sessionService.capturePhoto() {
            capturedImage = image
            showPhotoDetail = true
        }
    }
    
    // 写真を撮影して自動分析
    func captureAndAnalyzePhoto() {
        if let image = sessionService.capturePhoto() {
            capturedImage = image
            showPhotoDetail = true
            
            // 撮影成功フィードバック（振動）
            UINotificationFeedbackGenerator().notificationOccurred(.success)
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
    
    // メッシュの可視性を取得
    var isMeshVisible: Bool {
        sessionService.isMeshVisible
    }
    
    // 空間オーディオの有効状態を取得
    var isSpatialAudioEnabled: Bool {
        sessionService.spatialAudioEnabled
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
        
        // 空間オーディオの状態を更新
        if sessionService.spatialAudioEnabled != appSettings.spatialAudio.isEnabled {
            sessionService.toggleSpatialAudio()
        }
    }
    
    // 設定を保存
    private func saveSettings() {
        appSettings.save()
    }
}

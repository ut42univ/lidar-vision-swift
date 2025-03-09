import SwiftUI
import Combine

/// メイン画面のViewModel
final class ContentViewModel: ObservableObject {
    // 公開プロパティ
    @Published var soundEnabled: Bool = false
    @Published var spatialAudioEnabled: Bool = false
    @Published var spatialAudioVolume: Float = 0.8
    @Published var capturedImage: UIImage?
    @Published var showPhotoDetail = false
    
    // 固定プロパティ
    let alertColor: Color = .white
    
    // サービス参照
    let sessionService: ARSessionService
    private let feedbackService: FeedbackService
    
    // 内部状態
    private var cancellables = Set<AnyCancellable>()
    
    // 深度閾値（メートル単位）
    private let warningDepthThreshold: Float = 1.0
    private let criticalDepthThreshold: Float = 0.5
    
    init(sessionService: ARSessionService = ARSessionService(), 
         feedbackService: FeedbackService = FeedbackService()) {
        self.sessionService = sessionService
        self.feedbackService = feedbackService
        
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
        
        // 空間オーディオの設定変更を監視
        $spatialAudioEnabled
            .dropFirst()
            .sink { [weak self] enabled in
                self?.sessionService.toggleSpatialAudio()
            }
            .store(in: &cancellables)
        
        $spatialAudioVolume
            .dropFirst()
            .sink { [weak self] volume in
                self?.sessionService.setSpatialAudioVolume(volume)
            }
            .store(in: &cancellables)
            
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
            feedbackService.handleCriticalState(soundEnabled: soundEnabled)
        } else if newDepth < warningDepthThreshold {
            feedbackService.handleWarningState(soundEnabled: soundEnabled)
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
    
    // 3Dメッシュの可視性を切り替え
    func toggleMeshVisibility() {
        sessionService.toggleMeshVisibility()
    }
    
    // 空間オーディオを切り替え
    func toggleSpatialAudio() {
        spatialAudioEnabled.toggle()
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
}

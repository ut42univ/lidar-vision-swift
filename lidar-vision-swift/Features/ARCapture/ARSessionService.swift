// リファクタリング後の ARSessionService
// 責任を明確に分離し、重複コードを削除

import Foundation
import ARKit
import RealityKit

/// AR機能のコアサービス - より焦点を絞ったバージョン
final class ARSessionService: NSObject, ObservableObject {
    // 公開プロパティ
    @Published var centerDepth: Float = 0.0
    @Published var isMeshVisible: Bool = true
    @Published var spatialAudioEnabled: Bool = false
    @Published var isSessionRunning: Bool = false
    
    // 依存サービス - 注入可能にする
    private let meshService: MeshManagementService
    private let spatialAudioService: SpatialAudioService
    private let depthProcessor: DepthDataProcessor
    
    // 内部状態
    weak var arView: ARView?
    
    init(meshService: MeshManagementService = MeshManagementService(),
         spatialAudioService: SpatialAudioService = SpatialAudioService(),
         depthProcessor: DepthDataProcessor = DepthDataProcessor()) {
        self.meshService = meshService
        self.spatialAudioService = spatialAudioService
        self.depthProcessor = depthProcessor
        super.init()
    }
    
    /// ARセッションを開始
    func startSession(for arView: ARView) {
        self.arView = arView
        
        // 設定を作成して適用
        let configuration = createConfiguration()
        updateMeshVisibility()
        
        arView.session.delegate = self
        arView.session.run(configuration)
        
        // ビュー更新サイクルの外で状態を更新
        DispatchQueue.main.async {
            self.isSessionRunning = true
        }
        
        setupMemoryWarningObserver()
    }
    
    // 設定の作成を一箇所にまとめる
    private func createConfiguration() -> ARWorldTrackingConfiguration {
        let configuration = ARWorldTrackingConfiguration()
        
        if ARWorldTrackingConfiguration.supportsFrameSemantics(.sceneDepth) {
            configuration.frameSemantics.insert(.sceneDepth)
        }
        
        if ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh) {
            configuration.sceneReconstruction = .mesh
            configuration.environmentTexturing = .automatic
        }
        
        return configuration
    }
    
    private func setupMemoryWarningObserver() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleMemoryWarning),
            name: UIApplication.didReceiveMemoryWarningNotification,
            object: nil
        )
    }
    
    /// 3Dメッシュの可視性を切り替え
    func toggleMeshVisibility() {
        isMeshVisible.toggle()
        updateMeshVisibility()
    }
    
    /// メッシュの可視性を更新
    private func updateMeshVisibility() {
        guard let arView = arView else { return }
        
        if isMeshVisible {
            arView.debugOptions.insert(.showSceneUnderstanding)
        } else {
            arView.debugOptions.remove(.showSceneUnderstanding)
        }
    }
    
    /// 空間オーディオを切り替え
    func toggleSpatialAudio() {
        spatialAudioEnabled.toggle()
        
        if spatialAudioEnabled {
            spatialAudioService.startSpatialAudio()
        } else {
            spatialAudioService.stopSpatialAudio()
        }
    }
    
    /// 空間オーディオの音量を設定
    func setSpatialAudioVolume(_ volume: Float) {
        spatialAudioService.setVolumeMultiplier(volume)
    }
    
    /// メッシュキャッシュをリセット
    func resetMeshCache() {
        guard let arView = arView, let configuration = arView.session.configuration as? ARWorldTrackingConfiguration else {
            return
        }
        
        arView.session.run(configuration, options: [.resetSceneReconstruction])
        meshService.clearMeshAnchors()
    }
    
    /// メモリ警告の処理
    @objc private func handleMemoryWarning() {
        resetMeshCache()
    }
    
    /// 写真を撮影
    func capturePhoto() -> UIImage? {
        guard let frame = arView?.session.currentFrame else { return nil }
        return ImageCaptureHelper.createImage(from: frame)
    }

    /// ARセッションを一時停止
    func pauseSession() {
        if spatialAudioEnabled {
            spatialAudioService.stopSpatialAudio()
        }
        
        arView?.session.pause()
        
        DispatchQueue.main.async {
            self.isSessionRunning = false
        }
    }
    
    /// ARセッションを再開
    func resumeSession() {
        guard let arView = arView else { return }
        
        // ARセッションを再開
        if let configuration = arView.session.configuration {
            arView.session.run(configuration)
        } else {
            arView.session.run(createConfiguration())
        }
        
        // 状態更新を分離
        DispatchQueue.main.async {
            self.isSessionRunning = true
        }
        
        // 空間オーディオの復元
        if spatialAudioEnabled {
            spatialAudioService.startSpatialAudio()
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}

// MARK: - ARSessionDelegateの実装
extension ARSessionService: ARSessionDelegate {
    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        Task { @MainActor in
            // 深度データの処理を専用クラスに委譲
            if let depth = try? await depthProcessor.processDepthData(from: frame) {
                centerDepth = depth
            }
            
            // 空間オーディオの更新
            if spatialAudioEnabled {
                spatialAudioService.updateWithMeshData(
                    meshAnchors: meshService.meshAnchors,
                    cameraTransform: frame.camera.transform
                )
            }
        }
    }
    
    func session(_ session: ARSession, didAdd anchors: [ARAnchor]) {
        for anchor in anchors {
            if let meshAnchor = anchor as? ARMeshAnchor {
                meshService.addMeshAnchor(meshAnchor)
            }
        }
    }
    
    func session(_ session: ARSession, didUpdate anchors: [ARAnchor]) {
        for anchor in anchors {
            if let meshAnchor = anchor as? ARMeshAnchor {
                meshService.updateMeshAnchor(meshAnchor)
            }
        }
    }
    
    func session(_ session: ARSession, didRemove anchors: [ARAnchor]) {
        for anchor in anchors {
            if let meshAnchor = anchor as? ARMeshAnchor {
                meshService.removeMeshAnchor(meshAnchor)
            }
        }
    }
}

// 深度データ処理を独立したクラスに抽出
class DepthDataProcessor {
    /// フレームから深度情報を抽出
    func processDepthData(from frame: ARFrame) async throws -> Float {
        guard let sceneDepth = frame.sceneDepth else {
            throw ARError(.invalidConfiguration)
        }
        
        let depthMap = sceneDepth.depthMap
        let width = CVPixelBufferGetWidth(depthMap)
        let height = CVPixelBufferGetHeight(depthMap)
        
        CVPixelBufferLockBaseAddress(depthMap, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(depthMap, .readOnly) }
        
        guard let baseAddress = CVPixelBufferGetBaseAddress(depthMap) else {
            throw ARError(.invalidConfiguration)
        }
        
        let floatBuffer = baseAddress.assumingMemoryBound(to: Float32.self)
        let centerIndex = (height / 2) * width + (width / 2)
        return floatBuffer[centerIndex]
    }
}

// 画像キャプチャを独立したヘルパーに抽出
enum ImageCaptureHelper {
    static func createImage(from frame: ARFrame) -> UIImage? {
        let imageBuffer = frame.capturedImage
        let ciContext = CIContext()
        
        let ciImage = CIImage(cvPixelBuffer: imageBuffer)
        guard let cgImage = ciContext.createCGImage(ciImage, from: ciImage.extent) else {
            return nil
        }
        
        // デバイスの向きを考慮して画像の向きを調整
        let orientation = determineImageOrientation()
        return UIImage(cgImage: cgImage, scale: 1.0, orientation: orientation)
    }
    
    private static func determineImageOrientation() -> UIImage.Orientation {
        switch UIDevice.current.orientation {
        case .portrait:
            return .right
        case .portraitUpsideDown:
            return .left
        case .landscapeLeft:
            return .down
        case .landscapeRight:
            return .up
        case .faceUp, .faceDown, .unknown:
            return .right // デフォルトはポートレート
        @unknown default:
            return .right
        }
    }
}

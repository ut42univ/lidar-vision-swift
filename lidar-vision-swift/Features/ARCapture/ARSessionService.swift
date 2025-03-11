import Foundation
import ARKit
import RealityKit
import CoreImage
import UIKit

/// AR機能のコアサービス
final class ARSessionService: NSObject, ObservableObject {
    // 公開プロパティ
    @Published var centerDepth: Float = 0.0
    @Published var isMeshVisible: Bool = true
    @Published var spatialAudioEnabled: Bool = false
    @Published var isSessionRunning: Bool = false
    
    // 依存サービス
    private let meshService: MeshManagementService
    private let spatialAudioService: SpatialAudioService
    
    // 内部状態
    weak var arView: ARView?
    private let ciContext = CIContext()
    
    init(meshService: MeshManagementService = MeshManagementService(),
         spatialAudioService: SpatialAudioService = SpatialAudioService()) {
        self.meshService = meshService
        self.spatialAudioService = spatialAudioService
        super.init()
    }
    
    /// ARセッションを開始
    func startSession(for arView: ARView) {
        self.arView = arView
        
        // 設定の作成
        let configuration = ARWorldTrackingConfiguration()
        
        if ARWorldTrackingConfiguration.supportsFrameSemantics(.sceneDepth) {
            configuration.frameSemantics.insert(.sceneDepth)
        }
        
        if ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh) {
            configuration.sceneReconstruction = .mesh
            configuration.environmentTexturing = .automatic
        }
        
        updateMeshVisibility()
        
        arView.session.delegate = self
        arView.session.run(configuration)
        
        // メモリ警告通知リスナーを設定
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
        if isMeshVisible {
            arView?.debugOptions.insert(.showSceneUnderstanding)
        } else {
            arView?.debugOptions.remove(.showSceneUnderstanding)
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
    
    /// AirPodsの接続を再確認
    func recheckAirPodsConnection() {
        // 簡素化版では何もしない
    }
    
    /// メッシュキャッシュをリセット
    func resetMeshCache() {
        guard let arView = arView else { return }
        
        if let configuration = arView.session.configuration as? ARWorldTrackingConfiguration {
            arView.session.run(configuration, options: [.resetSceneReconstruction])
            meshService.clearMeshAnchors()
        }
    }
    
    /// メモリ警告の処理
    @objc private func handleMemoryWarning() {
        resetMeshCache()
    }
    
    /// 写真を撮影
    func capturePhoto() -> UIImage? {
        guard let frame = arView?.session.currentFrame else { return nil }
        let imageBuffer = frame.capturedImage
        
        let ciImage = CIImage(cvPixelBuffer: imageBuffer)
        guard let cgImage = ciContext.createCGImage(ciImage, from: ciImage.extent) else { return nil }
        
        // デバイスの向きを考慮して画像の向きを調整
        let orientation: UIImage.Orientation
        
        switch UIDevice.current.orientation {
        case .portrait:
            orientation = .right
        case .portraitUpsideDown:
            orientation = .left
        case .landscapeLeft:
            orientation = .down
        case .landscapeRight:
            orientation = .up
        case .faceUp, .faceDown, .unknown:
            orientation = .right // デフォルトはポートレート
        @unknown default:
            orientation = .right
        }
        
        return UIImage(cgImage: cgImage, scale: 1.0, orientation: orientation)
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}

// ARSessionDelegateの実装
extension ARSessionService: ARSessionDelegate {
    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        autoreleasepool {
            updateDepthFromFrame(frame)
            
            if spatialAudioEnabled {
                spatialAudioService.updateWithMeshData(
                    meshAnchors: meshService.meshAnchors,
                    cameraTransform: frame.camera.transform
                )
            }
        }
    }
    
    private func updateDepthFromFrame(_ frame: ARFrame) {
        guard let sceneDepth = frame.sceneDepth else { return }
        let depthMap = sceneDepth.depthMap
        
        let width = CVPixelBufferGetWidth(depthMap)
        let height = CVPixelBufferGetHeight(depthMap)
        
        CVPixelBufferLockBaseAddress(depthMap, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(depthMap, .readOnly) }
        
        if let baseAddress = CVPixelBufferGetBaseAddress(depthMap) {
            let floatBuffer = baseAddress.assumingMemoryBound(to: Float32.self)
            let centerIndex = (height / 2) * width + (width / 2)
            let depthAtCenter = floatBuffer[centerIndex]
            DispatchQueue.main.async {
                self.centerDepth = depthAtCenter
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
    
    /// ARセッションを一時停止
    func pauseSession() {
        print("Pausing AR session")
        
        // 空間オーディオが有効な場合は停止
        if spatialAudioEnabled {
            toggleSpatialAudio() // 既存のトグルメソッドを使用して無効化
        }
        
        arView?.session.pause()
    }
    /// ARセッションを再開
    func resumeSession() {
        guard let arView = arView else {
            print("Cannot resume session: arView is nil")
            return
        }
        
        print("Resuming AR session")
        if let configuration = arView.session.configuration {
            // 既存の設定を使って再開
            arView.session.run(configuration)
            isSessionRunning = true  // セッション再開時にフラグを更新
        } else {
            // 新しい設定で開始（万が一のため）
            let configuration = ARWorldTrackingConfiguration()
            
            if ARWorldTrackingConfiguration.supportsFrameSemantics(.sceneDepth) {
                configuration.frameSemantics.insert(.sceneDepth)
            }
            
            if ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh) {
                configuration.sceneReconstruction = .mesh
                configuration.environmentTexturing = .automatic
            }
            
            arView.session.run(configuration)
            isSessionRunning = true  // セッション再開時にフラグを更新
        }
        
        // セッション再開後、空間オーディオの状態を復元
        // spatialAudioEnabledは設定上の値、this.spatialAudioEnabledは現在の実行状態
        if spatialAudioEnabled && !self.spatialAudioEnabled {
            toggleSpatialAudio() // 有効化
        }
    }
}

import Foundation
import AVFoundation
import ARKit

/// 空間オーディオフィードバックを管理するサービス
final class SpatialAudioService {
    // オーディオエンジンコンポーネント
    private var engine: AVAudioEngine
    private var player: AVAudioPlayerNode
    private var environmentNode: AVAudioEnvironmentNode
    
    // オーディオバッファ
    private var nearBuffer: AVAudioPCMBuffer?
    private var mediumBuffer: AVAudioPCMBuffer?
    private var farBuffer: AVAudioPCMBuffer?
    private var currentBuffer: AVAudioPCMBuffer?
    
    // オーディオ状態
    private var isPlaying = false
    private var volumeMultiplier: Float = 1.0
    
    // 障害物追跡
    private var obstaclePoints: [(position: simd_float3, distance: Float)] = []
    private var cameraPosition: simd_float3 = simd_float3(0, 0, 0)
    
    // 設定
    private var settings: AppSettings
    
    init(settings: AppSettings = AppSettings()) {
        self.settings = settings
        engine = AVAudioEngine()
        player = AVAudioPlayerNode()
        environmentNode = AVAudioEnvironmentNode()
        
        setupAudioEngine()
        generateToneBuffers()
    }
    
    // MARK: - 初期設定
    
    private func setupAudioEngine() {
        // 空間オーディオの環境設定
        environmentNode.listenerPosition = AVAudio3DPoint(x: 0, y: 0, z: 0)
        environmentNode.renderingAlgorithm = .HRTFHQ
        
        // ノードを接続
        engine.attach(player)
        engine.attach(environmentNode)
        
        // ステレオフォーマットを使用
        let format = AVAudioFormat(standardFormatWithSampleRate: 44100.0, channels: 2)
        
        // プレイヤーを環境ノードに接続
        engine.connect(player, to: environmentNode, format: format)
        engine.connect(environmentNode, to: engine.mainMixerNode, format: format)
        
        // オーディオセッションを設定
        configureSpatialAudioSession()
    }
    
    private func configureSpatialAudioSession() {
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.playback, mode: .default, options: [.mixWithOthers, .allowBluetooth])
            try audioSession.setActive(true)
        } catch {
            print("Audio session setup failed: \(error)")
        }
    }
    
    private func generateToneBuffers() {
        // 各距離範囲用のトーンを生成
        nearBuffer = generateToneBuffer(frequency: settings.audioTones.highFrequency, duration: 0.3)
        mediumBuffer = generateToneBuffer(frequency: settings.audioTones.mediumFrequency, duration: 0.5)
        farBuffer = generateToneBuffer(frequency: settings.audioTones.lowFrequency, duration: 1.0)
        
        // デフォルトバッファを設定
        currentBuffer = farBuffer
    }
    
    // トーン生成ヘルパー
    private func generateToneBuffer(frequency: Float, duration: Float, sampleRate: Double = 44100.0) -> AVAudioPCMBuffer? {
        let audioFormat = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 2)
        guard let audioFormat = audioFormat else { return nil }
        
        let frameCount = AVAudioFrameCount(duration * Float(sampleRate))
        guard let buffer = AVAudioPCMBuffer(pcmFormat: audioFormat, frameCapacity: frameCount) else { return nil }
        
        buffer.frameLength = frameCount
        
        let omega = 2.0 * Float.pi * frequency
        
        // フェードイン/アウト用のサンプル数
        let fadeInSamples = min(Int(0.01 * Float(sampleRate)), Int(frameCount) / 10)
        let fadeOutSamples = min(Int(0.01 * Float(sampleRate)), Int(frameCount) / 10)
        
        // バッファにサイン波を生成
        for frame in 0..<Int(frameCount) {
            let value = sin(omega * Float(frame) / Float(sampleRate))
            
            // フェードイン/アウト適用
            var amplitude: Float = 1.0
            if frame < fadeInSamples {
                amplitude = Float(frame) / Float(fadeInSamples)
            } else if frame > Int(frameCount) - fadeOutSamples {
                let fadeOutPosition = frame - (Int(frameCount) - fadeOutSamples)
                amplitude = 1.0 - (Float(fadeOutPosition) / Float(fadeOutSamples))
            }
            
            // 両チャンネルに値を設定
            buffer.floatChannelData?[0][frame] = value * amplitude
            buffer.floatChannelData?[1][frame] = value * amplitude
        }
        
        return buffer
    }
    
    // MARK: - 公開メソッド
    
    /// 設定を更新
    func updateSettings(_ newSettings: AppSettings) {
        self.settings = newSettings
        
        // 音量更新
        volumeMultiplier = settings.spatialAudio.volume
        
        // トーンバッファを再生成
        generateToneBuffers()
        
        // プレイヤーの更新
        if isPlaying {
            stopSpatialAudio()
            startSpatialAudio()
        }
    }
    
    /// 空間オーディオフィードバックを開始
    func startSpatialAudio() {
        guard !isPlaying else { return }
        
        do {
            try engine.start()
            
            // 初期バッファをロード
            if let buffer = farBuffer {
                player.scheduleBuffer(buffer, at: nil, options: .loops, completionHandler: nil)
            }
            
            player.play()
            isPlaying = true
            
        } catch {
            print("Failed to start audio engine: \(error)")
        }
    }
    
    /// 空間オーディオフィードバックを停止
    func stopSpatialAudio() {
        guard isPlaying else { return }
        
        player.stop()
        engine.stop()
        isPlaying = false
    }
    
    /// 音量の設定
    func setVolumeMultiplier(_ multiplier: Float) {
        volumeMultiplier = max(0, min(1, multiplier))
    }
    
    /// メッシュデータで更新
    func updateWithMeshData(meshAnchors: [ARMeshAnchor], cameraTransform: simd_float4x4) {
        guard isPlaying else { return }
        
        // 障害物ポイントをリセット
        obstaclePoints.removeAll()
        
        // カメラ位置を更新
        cameraPosition = simd_make_float3(
            cameraTransform.columns.3.x,
            cameraTransform.columns.3.y,
            cameraTransform.columns.3.z
        )
        
        // カメラの正面ベクトルを更新
        let cameraForward = simd_normalize(simd_float3(
            -cameraTransform.columns.2.x,
            -cameraTransform.columns.2.y,
            -cameraTransform.columns.2.z
        ))
        
        // メッシュアンカーを処理
        for anchor in meshAnchors {
            processAnchor(anchor, cameraForward)
        }
        
        // 障害物に基づいてオーディオを更新
        updateAudioForObstacles()
    }
    
    /// リスナーの向きを更新
    func updateListenerOrientation(yaw: Float, pitch: Float, roll: Float) {
        environmentNode.listenerAngularOrientation = AVAudio3DAngularOrientation(
            yaw: yaw, pitch: pitch, roll: roll
        )
    }
    
    // MARK: - 内部処理メソッド
    
    // アンカーを処理
    private func processAnchor(_ anchor: ARMeshAnchor, _ cameraForward: simd_float3) {
        // アンカーの中心位置をワールド空間で取得
        let anchorPosition = simd_make_float3(
            anchor.transform.columns.3.x,
            anchor.transform.columns.3.y,
            anchor.transform.columns.3.z
        )
        
        // アンカーまでの距離
        let distanceToAnchor = simd_distance(cameraPosition, anchorPosition)
        
        // 距離が最大距離を超える場合はスキップ
        if distanceToAnchor > settings.spatialAudio.maxDistance {
            return
        }
        
        // アンカーへの方向
        let directionToAnchor = simd_normalize(anchorPosition - cameraPosition)
        let dotProduct = simd_dot(cameraForward, directionToAnchor)
        
        // 前方と少し側面のポイントを考慮 (約150度の視野)
        if dotProduct > -0.5 {
            obstaclePoints.append((anchorPosition, distanceToAnchor))
        }
    }
    
    // 障害物に基づいてオーディオを更新
    private func updateAudioForObstacles() {
        if obstaclePoints.isEmpty {
            // 障害物なし - 小さい音または無音
            player.volume = 0.1
            
            // 遠い音を使用
            if currentBuffer !== farBuffer, let buffer = farBuffer {
                changeBuffer(to: buffer)
            }
            
            // 位置をリセット
            player.position = AVAudio3DPoint(x: 0, y: 0, z: -1)
            return
        }
        
        // 距離でソート
        obstaclePoints.sort { $0.distance < $1.distance }
        
        // 最も近い障害物を取得
        let closestObstacle = obstaclePoints[0]
        let position = closestObstacle.position
        let distance = closestObstacle.distance
        
        // 方向を計算
        let direction = simd_normalize(position - cameraPosition)
        
        // 3D空間に音を配置
        positionSound(at: direction, distance: distance)
        
        // 距離に基づいて適切な音を選択
        if distance < settings.spatialAudio.nearThreshold {
            // 近い障害物 - 高周波数、高音量
            if currentBuffer !== nearBuffer, let buffer = nearBuffer {
                changeBuffer(to: buffer)
            }
            player.rate = 1.5
            
        } else if distance < settings.spatialAudio.mediumThreshold {
            // 中間距離 - 中周波数
            if currentBuffer !== mediumBuffer, let buffer = mediumBuffer {
                changeBuffer(to: buffer)
            }
            player.rate = 1.2
            
        } else {
            // 遠い距離 - 低周波数
            if currentBuffer !== farBuffer, let buffer = farBuffer {
                changeBuffer(to: buffer)
            }
            player.rate = 1.0
        }
    }
    
    // 3D空間に音を配置
    private func positionSound(at direction: simd_float3, distance: Float) {
        // 音源の位置を設定
        let scaledDirection = direction * min(2.0, distance)
        
        player.position = AVAudio3DPoint(
            x: scaledDirection.x,
            y: scaledDirection.y,
            z: scaledDirection.z
        )
        
        // 距離に基づいて音量を計算 (近いほど大きい)
        let volume = (1.0 - (distance / settings.spatialAudio.maxDistance)) * volumeMultiplier
        
        // 最小音量を設定
        player.volume = max(0.1, min(1.0, volume))
    }
    
    // 別のオーディオバッファに変更
    private func changeBuffer(to newBuffer: AVAudioPCMBuffer) {
        currentBuffer = newBuffer
        
        player.stop()
        player.scheduleBuffer(newBuffer, at: nil, options: .loops, completionHandler: nil)
        player.play()
    }
    
    deinit {
        stopSpatialAudio()
    }
}

import Foundation
import AVFoundation
import ARKit

/// 空間オーディオフィードバックを管理するサービス
final class SpatialAudioService {
    // オーディオエンジンコンポーネント
    private var engine: AVAudioEngine
    private var player: AVAudioPlayerNode
    private var environmentNode: AVAudioEnvironmentNode
    
    // オーディオバッファ管理を改善
    private struct AudioToneBuffers {
        let near: AVAudioPCMBuffer?
        let medium: AVAudioPCMBuffer?
        let far: AVAudioPCMBuffer?
    }
    private var toneBuffers: AudioToneBuffers
    private var currentBuffer: AVAudioPCMBuffer?
    
    // オーディオ状態
    private var isPlaying = false
    private var volumeMultiplier: Float = 1.0
    
    // 障害物追跡
    private struct ObstaclePoint {
        let position: simd_float3
        let distance: Float
    }
    private var obstaclePoints: [ObstaclePoint] = []
    private var cameraPosition: simd_float3 = simd_float3(0, 0, 0)
    private var cameraTransform: simd_float4x4 = simd_float4x4(1)
    
    // 設定
    private var settings: AppSettings
    
    init(settings: AppSettings = AppSettings()) {
        self.settings = settings
        engine = AVAudioEngine()
        player = AVAudioPlayerNode()
        environmentNode = AVAudioEnvironmentNode()
        
        // バッファを初期化（実際の生成は後で）
        toneBuffers = AudioToneBuffers(near: nil, medium: nil, far: nil)
        
        setupAudioEngine()
        generateToneBuffers()
    }
    
    // MARK: - オーディオ設定
    
    private func setupAudioEngine() {
        // 空間オーディオの環境設定
        configureSpatialEnvironment()
        
        // ノードを接続
        connectAudioNodes()
        
        // オーディオセッションを設定
        configureSpatialAudioSession()
    }
    
    /// 空間音響環境の構成
    private func configureSpatialEnvironment() {
        environmentNode.listenerPosition = AVAudio3DPoint(x: 0, y: 0, z: 0)
        environmentNode.renderingAlgorithm = .HRTFHQ
    }
    
    /// オーディオノードの接続
    private func connectAudioNodes() {
        engine.attach(player)
        engine.attach(environmentNode)
        
        // ステレオフォーマットを使用
        let format = AVAudioFormat(standardFormatWithSampleRate: 44100.0, channels: 2)
        
        if let format = format {
            // プレイヤーを環境ノードに接続
            engine.connect(player, to: environmentNode, format: format)
            engine.connect(environmentNode, to: engine.mainMixerNode, format: format)
        }
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
        let nearBuffer = generateToneBuffer(frequency: settings.audioTones.highFrequency, duration: 0.3)
        let mediumBuffer = generateToneBuffer(frequency: settings.audioTones.mediumFrequency, duration: 0.5)
        let farBuffer = generateToneBuffer(frequency: settings.audioTones.lowFrequency, duration: 1.0)
        
        toneBuffers = AudioToneBuffers(near: nearBuffer, medium: mediumBuffer, far: farBuffer)
        
        // デフォルトバッファを設定
        currentBuffer = farBuffer
    }
    
    // トーン生成ヘルパー - 波形生成アルゴリズムを改善
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
        
        // SIMD操作で一度に複数のサンプルを処理
        guard let floatChannelData = buffer.floatChannelData else { return nil }
        
        // SIMD処理のための準備
        let sampleCount = Int(frameCount)
        _ = SIMD16<Float>(
            0/16, 1/16, 2/16, 3/16, 4/16, 5/16, 6/16, 7/16,
            8/16, 9/16, 10/16, 11/16, 12/16, 13/16, 14/16, 15/16
        )
        
        // バッファ処理をチャンク単位で実行
        for base in stride(from: 0, to: sampleCount, by: 16) {
            let remainingSamples = min(16, sampleCount - base)
            
            // 通常のサンプル生成
            for i in 0..<remainingSamples {
                let frame = base + i
                let value = sin(omega * Float(frame) / Float(sampleRate))
                
                // フェードイン/アウト適用
                var amplitude: Float = 1.0
                if frame < fadeInSamples {
                    amplitude = Float(frame) / Float(fadeInSamples)
                } else if frame > sampleCount - fadeOutSamples {
                    let fadeOutPosition = frame - (sampleCount - fadeOutSamples)
                    amplitude = 1.0 - (Float(fadeOutPosition) / Float(fadeOutSamples))
                }
                
                // 両チャンネルに値を設定
                floatChannelData[0][frame] = value * amplitude
                floatChannelData[1][frame] = value * amplitude
            }
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
            if let buffer = toneBuffers.far {
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
        
        // カメラ位置と方向の計算を効率化
        updateCameraPosition(from: cameraTransform)
        
        // 障害物ポイントを計算
        processObstacles(meshAnchors)
        
        // 障害物に基づいてオーディオを更新
        updateAudioForObstacles()
    }
    
    /// カメラ位置と方向の更新
    private func updateCameraPosition(from transform: simd_float4x4) {
        self.cameraTransform = transform
        cameraPosition = simd_make_float3(
            transform.columns.3.x,
            transform.columns.3.y,
            transform.columns.3.z
        )
    }
    
    /// 障害物を処理
    private func processObstacles(_ meshAnchors: [ARMeshAnchor]) {
        // 障害物ポイントをリセット
        obstaclePoints.removeAll()
        
        // カメラの正面ベクトルを計算
        let cameraForward = simd_normalize(simd_float3(
            -cameraTransform.columns.2.x,
            -cameraTransform.columns.2.y,
            -cameraTransform.columns.2.z
        ))
        
        // メッシュアンカーを処理
        for anchor in meshAnchors {
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
                continue
            }
            
            // アンカーへの方向
            let directionToAnchor = simd_normalize(anchorPosition - cameraPosition)
            let dotProduct = simd_dot(cameraForward, directionToAnchor)
            
            // 前方と少し側面のポイントを考慮 (約150度の視野)
            if dotProduct > -0.5 {
                obstaclePoints.append(ObstaclePoint(position: anchorPosition, distance: distanceToAnchor))
            }
        }
    }
    
    // 障害物に基づいてオーディオを更新
    private func updateAudioForObstacles() {
        if obstaclePoints.isEmpty {
            handleNoObstacles()
            return
        }
        
        // 距離でソート
        obstaclePoints.sort { $0.distance < $1.distance }
        
        // 最も近い障害物を取得
        let closestObstacle = obstaclePoints[0]
        handleClosestObstacle(closestObstacle)
    }
    
    // 障害物がない場合の処理
    private func handleNoObstacles() {
        // 障害物なし - 小さい音または無音
        player.volume = 0.1
        
        // 遠い音を使用
        if currentBuffer !== toneBuffers.far, let buffer = toneBuffers.far {
            changeBuffer(to: buffer)
        }
        
        // 位置をリセット
        player.position = AVAudio3DPoint(x: 0, y: 0, z: -1)
    }
    
    // 最も近い障害物に対する処理
    private func handleClosestObstacle(_ obstacle: ObstaclePoint) {
        let position = obstacle.position
        let distance = obstacle.distance
        
        // 方向を計算
        let direction = simd_normalize(position - cameraPosition)
        
        // 3D空間に音を配置
        positionSound(at: direction, distance: distance)
        
        // 距離に基づいて適切な音を選択
        updateToneByDistance(distance)
    }
    
    // 距離に基づいてトーンを更新
    private func updateToneByDistance(_ distance: Float) {
        if distance < settings.spatialAudio.nearThreshold {
            // 近い障害物 - 高周波数、高音量
            if currentBuffer !== toneBuffers.near, let buffer = toneBuffers.near {
                changeBuffer(to: buffer)
            }
            player.rate = 1.5
            
        } else if distance < settings.spatialAudio.mediumThreshold {
            // 中間距離 - 中周波数
            if currentBuffer !== toneBuffers.medium, let buffer = toneBuffers.medium {
                changeBuffer(to: buffer)
            }
            player.rate = 1.2
            
        } else {
            // 遠い距離 - 低周波数
            if currentBuffer !== toneBuffers.far, let buffer = toneBuffers.far {
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
    
    /// リスナーの向きを更新
    func updateListenerOrientation(yaw: Float, pitch: Float, roll: Float) {
        environmentNode.listenerAngularOrientation = AVAudio3DAngularOrientation(
            yaw: yaw, pitch: pitch, roll: roll
        )
    }
    
    deinit {
        stopSpatialAudio()
    }
}

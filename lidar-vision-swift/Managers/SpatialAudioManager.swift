import Foundation
import AVFoundation
import ARKit
import RealityKit
import CoreMotion

final class SpatialAudioManager: NSObject {
    // Audio engine components
    private var engine: AVAudioEngine
    private var player: AVAudioPlayerNode
    private var environmentNode: AVAudioEnvironmentNode
    
    // Audio buffers
    private var nearBuffer: AVAudioPCMBuffer?
    private var mediumBuffer: AVAudioPCMBuffer?
    private var farBuffer: AVAudioPCMBuffer?
    private var currentBuffer: AVAudioPCMBuffer?
    
    // Audio state
    private var isPlaying = false
    private var volumeMultiplier: Float = 1.0
    
    // Obstacle tracking
    private var obstaclePoints: [(position: simd_float3, distance: Float)] = []
    private var cameraPosition: simd_float3 = simd_float3(0, 0, 0)
    private var cameraForward: simd_float3 = simd_float3(0, 0, -1)
    
    // Configuration
    private let maxDistance: Float = 5.0 // Maximum distance for sounds (meters)
    private let nearThreshold: Float = 0.5 // Near warning threshold
    private let mediumThreshold: Float = 2.0 // Medium warning threshold
    
    // Sound characteristics
    private let nearFrequency: Float = 880.0  // High pitch for close objects
    private let mediumFrequency: Float = 440.0 // Medium pitch
    private let farFrequency: Float = 220.0   // Low pitch for distant objects
    
    // Head tracking
    private let headphoneMotionManager = CMHeadphoneMotionManager()
    private var headTrackingEnabled = false
    private var lastHeadOrientation: simd_float3 = simd_float3(0, 0, 0)
    
    // AirPods detection
    private var isUsingAirPods = false
    
    override init() {
        // Initialize audio components
        engine = AVAudioEngine()
        player = AVAudioPlayerNode()
        environmentNode = AVAudioEnvironmentNode()
        
        super.init()
        
        print("SpatialAudioManager: Initializing...")
        setupAudioEngine()
        generateToneBuffers()
        detectAirPods()
        setupHeadTracking()
    }
    
    // MARK: - Setup Methods
    
    private func setupAudioEngine() {
        print("SpatialAudioManager: Setting up audio engine")
        
        // Configure environment for spatial audio
        environmentNode.listenerPosition = AVAudio3DPoint(x: 0, y: 0, z: 0)
        environmentNode.listenerAngularOrientation = AVAudio3DAngularOrientation(yaw: 0, pitch: 0, roll: 0)
        
        // Enhanced spatial settings
        environmentNode.distanceAttenuationParameters.distanceAttenuationModel = .inverse
        environmentNode.distanceAttenuationParameters.referenceDistance = 0.3
        environmentNode.distanceAttenuationParameters.maximumDistance = maxDistance
        environmentNode.distanceAttenuationParameters.rolloffFactor = 1.5  // Steeper rolloff for better distance perception
        
        // Reverb settings to enhance spatial perception
        environmentNode.reverbParameters.enable = true
        environmentNode.reverbParameters.level = 0.3  // Subtle reverb
        
        // Use best algorithm for spatial rendering
        if #available(iOS 13.0, *) {
            environmentNode.renderingAlgorithm = .auto  // Use best available algorithm
        } else {
            environmentNode.renderingAlgorithm = .HRTFHQ
        }
        
        // Connect nodes
        engine.attach(player)
        engine.attach(environmentNode)
        
        // Using explicit stereo format
        let format = AVAudioFormat(standardFormatWithSampleRate: 44100.0, channels: 2)
        
        // Connect player to environment node for spatial effects
        engine.connect(player, to: environmentNode, format: format)
        engine.connect(environmentNode, to: engine.mainMixerNode, format: format)
        
        // Configure audio session for spatial audio
        configureSpatialAudioSession()
    }
    
    private func configureSpatialAudioSession() {
        let audioSession = AVAudioSession.sharedInstance()
        do {
            if #available(iOS 14.0, *) {
                // Use spatialized mode if available
                try audioSession.setCategory(.playback, mode: .default, options: [.mixWithOthers, .allowBluetooth, .allowBluetoothA2DP])
                
                // iOS 14以上で可能な場合、空間オーディオ設定を有効化
                if #available(iOS 15.0, *) {
                    try audioSession.setSupportsMultichannelContent(true)
                    print("SpatialAudioManager: Multichannel content support enabled")
                }
                print("SpatialAudioManager: Spatial audio mode configured")
            } else {
                // Fallback for older iOS versions
                try audioSession.setCategory(.playback, mode: .default, options: [.mixWithOthers, .allowBluetooth, .allowBluetoothA2DP])
            }
            
            try audioSession.setActive(true)
        } catch {
            print("SpatialAudioManager: Failed to set audio session: \(error)")
        }
    }
    
    private func generateToneBuffers() {
        print("SpatialAudioManager: Generating audio buffers")
        
        // Generate tones for each distance range
        nearBuffer = generateEnhancedToneBuffer(frequency: nearFrequency, duration: 0.3, harmonics: true)
        mediumBuffer = generateEnhancedToneBuffer(frequency: mediumFrequency, duration: 0.5, harmonics: true)
        farBuffer = generateEnhancedToneBuffer(frequency: farFrequency, duration: 1.0, harmonics: false)
        
        // Set default buffer
        currentBuffer = farBuffer
    }
    
    // Generate enhanced tone with harmonics for better spatial perception
    private func generateEnhancedToneBuffer(frequency: Float, duration: Float, harmonics: Bool, sampleRate: Double = 44100.0) -> AVAudioPCMBuffer? {
        // ステレオ（2チャンネル）のオーディオフォーマットを作成
        let audioFormat = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 2)
        guard let audioFormat = audioFormat else { return nil }
        
        let frameCount = AVAudioFrameCount(duration * Float(sampleRate))
        guard let buffer = AVAudioPCMBuffer(pcmFormat: audioFormat, frameCapacity: frameCount) else { return nil }
        
        buffer.frameLength = frameCount
        
        // Main frequency
        let omega = 2.0 * Float.pi * frequency
        
        // Add fade in/out to avoid clicks
        let fadeInSamples = min(Int(0.01 * Float(sampleRate)), Int(frameCount) / 10)
        let fadeOutSamples = min(Int(0.01 * Float(sampleRate)), Int(frameCount) / 10)
        
        // Create a more complex and spatially recognizable sound
        for frame in 0..<Int(frameCount) {
            // Basic sine wave
            var value = sin(omega * Float(frame) / Float(sampleRate))
            
            // Add harmonics for richer sound if requested
            if harmonics {
                // Add second harmonic (2x frequency) at lower amplitude
                value += 0.3 * sin(2 * omega * Float(frame) / Float(sampleRate))
                
                // Add third harmonic (3x frequency) at even lower amplitude
                value += 0.15 * sin(3 * omega * Float(frame) / Float(sampleRate))
                
                // Normalize to avoid clipping
                value = value / 1.45
            }
            
            // Add slight envelope modulation for more character
            let modulation = 1.0 + 0.1 * sin(2.0 * Float.pi * 3.0 * Float(frame) / Float(sampleRate))
            value *= modulation
            
            // Apply fade in/out envelope
            var amplitude: Float = 1.0
            if frame < fadeInSamples {
                amplitude = Float(frame) / Float(fadeInSamples) // Linear fade in
            } else if frame > Int(frameCount) - fadeOutSamples {
                let fadeOutPosition = frame - (Int(frameCount) - fadeOutSamples)
                amplitude = 1.0 - (Float(fadeOutPosition) / Float(fadeOutSamples)) // Linear fade out
            }
            
            // Set values for both channels
            buffer.floatChannelData?[0][frame] = value * amplitude
            buffer.floatChannelData?[1][frame] = value * amplitude
        }
        
        return buffer
    }
    
    // MARK: - AirPods and Head Tracking
    
    private func detectAirPods() {
        print("SpatialAudioManager: Checking for AirPods...")
        
        let currentRoute = AVAudioSession.sharedInstance().currentRoute
        for output in currentRoute.outputs {
            let portName = output.portName.lowercased()
            if output.portType == .bluetoothA2DP &&
               (portName.contains("airpods pro") ||
                portName.contains("airpods max") ||
                portName.contains("airpods")) {
                isUsingAirPods = true
                print("SpatialAudioManager: AirPods detected! Enabling enhanced features")
                break
            }
        }
        
        // Set up notification to detect when audio route changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleRouteChange),
            name: AVAudioSession.routeChangeNotification,
            object: nil
        )
    }
    
    @objc private func handleRouteChange(notification: Notification) {
        detectAirPods()
        
        // Restart head tracking if needed
        if isUsingAirPods {
            setupHeadTracking()
        } else {
            stopHeadTracking()
        }
    }
    
    private func setupHeadTracking() {
        // Check if headphone motion is available (AirPods Pro/Max support this)
        if headphoneMotionManager.isDeviceMotionAvailable {
            print("SpatialAudioManager: Headphone motion tracking available")
            startHeadTracking()
        } else {
            print("SpatialAudioManager: Headphone motion tracking not available")
            headTrackingEnabled = false
        }
    }
    
    private func startHeadTracking() {
        guard !headTrackingEnabled, headphoneMotionManager.isDeviceMotionAvailable else { return }
        
        print("SpatialAudioManager: Starting head tracking")
        headphoneMotionManager.startDeviceMotionUpdates(to: .main) { [weak self] motion, error in
            guard let self = self, let motion = motion else {
                if let error = error {
                    print("SpatialAudioManager: Head tracking error: \(error)")
                }
                return
            }
            
            // 頭の向きを取得
            let attitude = motion.attitude
            
            // 頭の向きから角度を計算
            let yaw = Float(attitude.yaw)
            let pitch = Float(attitude.pitch)
            let roll = Float(attitude.roll)
            
            // 頭の向きを記録
            self.lastHeadOrientation = simd_float3(yaw, pitch, roll)
            
            // オーディオリスナーの向きを更新
            self.updateAudioListenerOrientation(yaw: yaw, pitch: pitch, roll: roll)
        }
        
        headTrackingEnabled = true
    }
    
    private func stopHeadTracking() {
        if headTrackingEnabled {
            headphoneMotionManager.stopDeviceMotionUpdates()
            headTrackingEnabled = false
            print("SpatialAudioManager: Head tracking stopped")
        }
    }
    
    private func updateAudioListenerOrientation(yaw: Float, pitch: Float, roll: Float) {
        // 角度をAVAudio3DAngularOrientationに変換して適用
        environmentNode.listenerAngularOrientation = AVAudio3DAngularOrientation(
            yaw: yaw,
            pitch: pitch,
            roll: roll
        )
    }
    
    // MARK: - Public Methods
    
    // Start spatial audio feedback
    func startSpatialAudio() {
        guard !isPlaying else { return }
        
        print("SpatialAudioManager: Starting spatial audio")
        do {
            try engine.start()
            
            // Load initial buffer
            if let buffer = farBuffer {
                player.scheduleBuffer(buffer, at: nil, options: .loops, completionHandler: nil)
            }
            
            player.play()
            isPlaying = true
            
            // Start head tracking if available
            if isUsingAirPods {
                startHeadTracking()
            }
            
        } catch {
            print("SpatialAudioManager: Failed to start audio engine: \(error)")
        }
    }
    
    // Stop spatial audio feedback
    func stopSpatialAudio() {
        guard isPlaying else { return }
        
        print("SpatialAudioManager: Stopping spatial audio")
        player.stop()
        engine.stop()
        stopHeadTracking()
        isPlaying = false
    }
    
    // Update with new mesh data
    func updateWithMeshData(meshAnchors: [ARMeshAnchor], cameraTransform: simd_float4x4) {
        guard isPlaying else { return }
        
        // Reset obstacle points
        obstaclePoints.removeAll()
        
        // Update camera position
        cameraPosition = simd_make_float3(
            cameraTransform.columns.3.x,
            cameraTransform.columns.3.y,
            cameraTransform.columns.3.z
        )
        
        // Update camera forward vector
        cameraForward = simd_normalize(simd_float3(
            -cameraTransform.columns.2.x,
            -cameraTransform.columns.2.y,
            -cameraTransform.columns.2.z
        ))
        
        // Process mesh anchors
        for anchor in meshAnchors {
            processAnchor(anchor)
        }
        
        // Update audio based on obstacles
        updateAudioForObstacles()
    }
    
    // Process a mesh anchor to find obstacle points
    private func processAnchor(_ anchor: ARMeshAnchor) {
        // Get anchor center position in world space
        let anchorPosition = simd_make_float3(
            anchor.transform.columns.3.x,
            anchor.transform.columns.3.y,
            anchor.transform.columns.3.z
        )
        
        // Skip if anchor is too far
        let distanceToAnchor = simd_distance(cameraPosition, anchorPosition)
        if distanceToAnchor > maxDistance * 1.5 {
            return
        }
        
        // Add the anchor center as a primary point
        let directionToAnchor = simd_normalize(anchorPosition - cameraPosition)
        let dotProduct = simd_dot(cameraForward, directionToAnchor)
        
        // Consider points in front and slightly to the sides (approx 150 degree field)
        if dotProduct > -0.5 {
            obstaclePoints.append((anchorPosition, distanceToAnchor))
        }
        
        // Sample additional points around the anchor for better coverage
        let sampleCount = 5
        for i in 0..<sampleCount {
            // Generate points at different offsets
            let offsets: [simd_float3] = [
                simd_float3(0.5, 0, 0),
                simd_float3(-0.5, 0, 0),
                simd_float3(0, 0.5, 0),
                simd_float3(0, -0.5, 0),
                simd_float3(0, 0, 0.5)
            ]
            
            let samplePos = anchorPosition + offsets[i]
            let distance = simd_distance(cameraPosition, samplePos)
            
            if distance <= maxDistance {
                let directionToSample = simd_normalize(samplePos - cameraPosition)
                let dotProduct = simd_dot(cameraForward, directionToSample)
                
                if dotProduct > -0.5 {
                    obstaclePoints.append((samplePos, distance))
                }
            }
        }
    }
    
    // Update audio based on obstacles
    private func updateAudioForObstacles() {
        if obstaclePoints.isEmpty {
            // No obstacles - silence or ambient sound
            player.volume = 0.1
            
            // Use far sound
            if currentBuffer !== farBuffer, let buffer = farBuffer {
                changeBuffer(to: buffer)
            }
            
            // Reset position to ambient
            player.position = AVAudio3DPoint(x: 0, y: 0, z: -1)
            return
        }
        
        // Sort by distance
        obstaclePoints.sort { $0.distance < $1.distance }
        
        // Get closest obstacle
        let closestObstacle = obstaclePoints[0]
        let position = closestObstacle.position
        let distance = closestObstacle.distance
        
        // Get direction accounting for head orientation if tracking enabled
        var direction = position - cameraPosition
        
        if headTrackingEnabled {
            // Apply head rotation to direction vector
            // This makes obstacles stay in place even when head turns
            let headYaw = lastHeadOrientation.x
            
            // Create rotation matrix around y-axis based on head yaw
            let rotationMatrix = simd_float3x3(
                simd_float3(cos(headYaw), 0, sin(headYaw)),
                simd_float3(0, 1, 0),
                simd_float3(-sin(headYaw), 0, cos(headYaw))
            )
            
            // Apply rotation to direction
            direction = rotationMatrix * direction
        }
        
        // Normalize direction
        direction = simd_normalize(direction)
        
        // Position sound in 3D space
        positionSound(at: direction, distance: distance)
        
        // Choose appropriate sound based on distance
        if distance < nearThreshold {
            // Near obstacle - high frequency, high volume
            if currentBuffer !== nearBuffer, let buffer = nearBuffer {
                changeBuffer(to: buffer)
            }
            
            // Set player rate higher for urgency
            player.rate = 1.5
            
        } else if distance < mediumThreshold {
            // Medium distance - medium frequency
            if currentBuffer !== mediumBuffer, let buffer = mediumBuffer {
                changeBuffer(to: buffer)
            }
            
            player.rate = 1.2
            
        } else {
            // Far distance - low frequency
            if currentBuffer !== farBuffer, let buffer = farBuffer {
                changeBuffer(to: buffer)
            }
            
            player.rate = 1.0
        }
    }
    
    // Position sound in 3D space
    private func positionSound(at direction: simd_float3, distance: Float) {
        // Set position of sound source
        // Scale direction vector to create clearer spatial positioning
        // but avoid placing it too far away
        let scaledDirection = direction * min(2.0, distance)
        
        player.position = AVAudio3DPoint(
            x: scaledDirection.x,
            y: scaledDirection.y,
            z: scaledDirection.z
        )
        
        // Calculate volume based on distance (closer = louder)
        var volume = 1.0 - (distance / maxDistance)
        
        // Enhance the volume curve for better perception
        volume = volume * volume * volumeMultiplier
        
        // Set minimum volume for audibility
        volume = max(0.1, min(1.0, volume))
        
        player.volume = volume
    }
    
    // Change to a different audio buffer
    private func changeBuffer(to newBuffer: AVAudioPCMBuffer) {
        currentBuffer = newBuffer
        
        player.stop()
        player.scheduleBuffer(newBuffer, at: nil, options: .loops, completionHandler: nil)
        player.play()
    }
    
    // Set global volume multiplier
    func setVolumeMultiplier(_ multiplier: Float) {
        volumeMultiplier = max(0, min(1, multiplier))
    }
    
    // Manually update listener orientation when no head tracking
    func updateListenerOrientation(yaw: Float, pitch: Float, roll: Float) {
        if !headTrackingEnabled {
            updateAudioListenerOrientation(yaw: yaw, pitch: pitch, roll: roll)
        }
    }
    
    // Restart AirPods detection
    func recheckForAirPods() {
        detectAirPods()
        if isUsingAirPods {
            setupHeadTracking()
        }
    }
    
    // Clean up resources
    deinit {
        stopSpatialAudio()
        NotificationCenter.default.removeObserver(self)
    }
}

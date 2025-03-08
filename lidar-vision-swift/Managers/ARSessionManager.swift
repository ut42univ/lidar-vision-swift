import Foundation
import ARKit
import RealityKit
import CoreImage
import UIKit

final class ARSessionManager: NSObject, ObservableObject, ARSessionDelegate {
    @Published var centerDepth: Float = 0.0
    @Published var isMeshVisible: Bool = true
    @Published var spatialAudioEnabled: Bool = false
    
    weak var arView: ARView?
    private let ciContext = CIContext()
    
    // Mesh configuration properties
    private var meshAnchors: [ARMeshAnchor] = []
    
    // Cache management properties
    private var cacheResetTimer: Timer?
    private var lastCameraPosition: simd_float3?
    private let distanceThresholdForReset: Float = 50.0 // Reset after 50m movement
    private let maxMeshDistance: Float = 15.0 // Keep only meshes within 15m
    
    // Enhanced spatial audio manager
    private let spatialAudioManager = SpatialAudioManager()
    
    func startSession(for arView: ARView) {
        self.arView = arView
        
        // Create configuration with scene depth and mesh enabled
        let configuration = ARWorldTrackingConfiguration()
        
        // Enable scene depth if available
        if ARWorldTrackingConfiguration.supportsFrameSemantics(.sceneDepth) {
            configuration.frameSemantics.insert(.sceneDepth)
        }
        
        // Enable scene mesh if available
        if ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh) {
            configuration.sceneReconstruction = .mesh
            
            // Set additional mesh configuration
            configuration.environmentTexturing = .automatic
        }
        
        // Configure debug options to visualize the mesh
        updateMeshVisibility()
        
        arView.session.delegate = self
        arView.session.run(configuration)
        
        // Start cache management
        setupCacheManagement()
        
        print("ARSessionManager: Session started with mesh reconstruction")
    }
    
    // Toggle 3D mesh visibility
    func toggleMeshVisibility() {
        isMeshVisible.toggle()
        updateMeshVisibility()
    }
    
    // Update mesh visibility based on current state
    private func updateMeshVisibility() {
        if isMeshVisible {
            arView?.debugOptions.insert(.showSceneUnderstanding)
        } else {
            arView?.debugOptions.remove(.showSceneUnderstanding)
        }
    }
    
    // Toggle spatial audio
    func toggleSpatialAudio() {
        spatialAudioEnabled.toggle()
        
        if spatialAudioEnabled {
            spatialAudioManager.startSpatialAudio()
            print("ARSessionManager: Spatial audio enabled")
        } else {
            spatialAudioManager.stopSpatialAudio()
            print("ARSessionManager: Spatial audio disabled")
        }
    }
    
    // Set spatial audio volume
    func setSpatialAudioVolume(_ volume: Float) {
        spatialAudioManager.setVolumeMultiplier(volume)
    }
    
    // Recheck for AirPods connection
    func recheckAirPodsConnection() {
        spatialAudioManager.recheckForAirPods()
    }
    
    // MARK: - Mesh Cache Management
    
    private func setupCacheManagement() {
        // Start periodic cache reset (every 5 minutes)
        startPeriodicCacheReset(interval: 300)
        
        // Set up memory warning notification listener
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleMemoryWarning),
            name: UIApplication.didReceiveMemoryWarningNotification,
            object: nil
        )
    }
    
    // Method to reset mesh cache
    func resetMeshCache() {
        guard let arView = arView else { return }
        
        print("Resetting mesh cache...")
        
        // Reset session reconstruction while maintaining current settings
        if let configuration = arView.session.configuration as? ARWorldTrackingConfiguration {
            arView.session.run(configuration, options: [.resetSceneReconstruction])
            
            // Clear saved mesh anchor array
            meshAnchors.removeAll()
            
            print("Mesh cache has been reset")
        }
    }
    
    // Function to periodically clear cache
    func startPeriodicCacheReset(interval: TimeInterval) {
        // Stop existing timer if any
        cacheResetTimer?.invalidate()
        
        // Start new timer
        cacheResetTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            print("Executing periodic cache reset...")
            self?.resetMeshCache()
        }
    }
    
    // Handle memory warning
    @objc private func handleMemoryWarning() {
        print("Memory warning received: resetting mesh cache")
        resetMeshCache()
    }
    
    // Distance-based mesh filtering
    private func filterMeshAnchors(maxDistance: Float) {
        guard let arView = arView,
              let cameraTransform = arView.session.currentFrame?.camera.transform else { return }
        
        // Get camera position
        let cameraPosition = simd_make_float3(
            cameraTransform.columns.3.x,
            cameraTransform.columns.3.y,
            cameraTransform.columns.3.z
        )
        
        // Number of anchors before filtering
        let beforeCount = meshAnchors.count
        
        // Remove mesh anchors outside range
        meshAnchors = meshAnchors.filter { meshAnchor in
            let meshPosition = simd_make_float3(
                meshAnchor.transform.columns.3.x,
                meshAnchor.transform.columns.3.y,
                meshAnchor.transform.columns.3.z
            )
            let distance = simd_distance(cameraPosition, meshPosition)
            return distance <= maxDistance
        }
        
        // Number of anchors after filtering
        let afterCount = meshAnchors.count
        
        if beforeCount != afterCount {
            print("Distance-based filtering: Removed \(beforeCount - afterCount) meshes. Remaining: \(afterCount)")
        }
    }
    
    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        autoreleasepool {
            guard let sceneDepth = frame.sceneDepth else { return }
            let depthMap = sceneDepth.depthMap
            
            // Update center depth quickly.
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
            
            // Update spatial audio with current mesh data if enabled
            if spatialAudioEnabled {
                spatialAudioManager.updateWithMeshData(
                    meshAnchors: meshAnchors,
                    cameraTransform: frame.camera.transform
                )
                
                // Update audio listener orientation from device if not using AirPods tracking
                if let orientation = UIDevice.current.orientation.deviceOrientation {
                    spatialAudioManager.updateListenerOrientation(
                        yaw: orientation.yaw,
                        pitch: orientation.pitch,
                        roll: orientation.roll
                    )
                }
            }
            
            // Mesh cache management: distance-based reset
            let currentPosition = simd_make_float3(
                frame.camera.transform.columns.3.x,
                frame.camera.transform.columns.3.y,
                frame.camera.transform.columns.3.z
            )
            
            // First frame or significant movement
            if let lastPosition = lastCameraPosition {
                let movementDistance = simd_distance(currentPosition, lastPosition)
                
                // Reset cache if moved beyond threshold distance
                if movementDistance > distanceThresholdForReset {
                    print("Movement distance exceeded threshold (\(movementDistance)m): Resetting mesh")
                    resetMeshCache()
                    lastCameraPosition = currentPosition
                }
            } else {
                // Record current position for first frame
                lastCameraPosition = currentPosition
            }
            
            // Filter out-of-range meshes at a frequency of 1 every 10 frames
            if Int(frame.timestamp * 100) % 10 == 0 {
                filterMeshAnchors(maxDistance: maxMeshDistance)
            }
        }
    }
    
    func session(_ session: ARSession, didAdd anchors: [ARAnchor]) {
        for anchor in anchors {
            if let meshAnchor = anchor as? ARMeshAnchor {
                addMeshAnchor(meshAnchor)
            }
        }
    }
    
    func session(_ session: ARSession, didUpdate anchors: [ARAnchor]) {
        for anchor in anchors {
            if let meshAnchor = anchor as? ARMeshAnchor {
                updateMeshAnchor(meshAnchor)
            }
        }
    }
    
    func session(_ session: ARSession, didRemove anchors: [ARAnchor]) {
        for anchor in anchors {
            if let meshAnchor = anchor as? ARMeshAnchor {
                removeMeshAnchor(meshAnchor)
            }
        }
    }
    
    private func addMeshAnchor(_ meshAnchor: ARMeshAnchor) {
        meshAnchors.append(meshAnchor)
    }
    
    private func updateMeshAnchor(_ meshAnchor: ARMeshAnchor) {
        if let index = meshAnchors.firstIndex(where: { $0.identifier == meshAnchor.identifier }) {
            meshAnchors[index] = meshAnchor
        } else {
            addMeshAnchor(meshAnchor)
        }
    }
    
    private func removeMeshAnchor(_ meshAnchor: ARMeshAnchor) {
        if let index = meshAnchors.firstIndex(where: { $0.identifier == meshAnchor.identifier }) {
            meshAnchors.remove(at: index)
        }
    }
    
    func capturePhoto() -> UIImage? {
        guard let frame = arView?.session.currentFrame else { return nil }
        let imageBuffer = frame.capturedImage
        let ciImage = CIImage(cvPixelBuffer: imageBuffer)
        guard let cgImage = ciContext.createCGImage(ciImage, from: ciImage.extent) else { return nil }
        let orientation = UIImage.Orientation(rawValue: UIDevice.current.orientation.rawValue) ?? .up
        return UIImage(cgImage: cgImage, scale: 1.0, orientation: orientation)
    }
    
    deinit {
        cacheResetTimer?.invalidate()
        cacheResetTimer = nil
        
        NotificationCenter.default.removeObserver(self)
    }
}

// Extension to convert device orientation to spatial audio orientation values
extension UIDeviceOrientation {
    var deviceOrientation: (yaw: Float, pitch: Float, roll: Float)? {
        switch self {
        case .portrait:
            return (yaw: 0, pitch: 0, roll: 0)
        case .portraitUpsideDown:
            return (yaw: 0, pitch: 0, roll: Float.pi)
        case .landscapeLeft:
            return (yaw: -Float.pi/2, pitch: 0, roll: 0)
        case .landscapeRight:
            return (yaw: Float.pi/2, pitch: 0, roll: 0)
        case .faceUp:
            return (yaw: 0, pitch: -Float.pi/2, roll: 0)
        case .faceDown:
            return (yaw: 0, pitch: Float.pi/2, roll: 0)
        default:
            return nil
        }
    }
}

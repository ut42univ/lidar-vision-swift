import SwiftUI
import ARKit
import RealityKit

// ② ARViewをSwiftUIでラップする
struct ARViewContainer: UIViewRepresentable {
    @ObservedObject var depthData: DepthData

    func makeUIView(context: Context) -> ARView {
        let arView = ARView(frame: .zero)
        let configuration = ARWorldTrackingConfiguration()
        if ARWorldTrackingConfiguration.supportsFrameSemantics(.sceneDepth) {
            configuration.frameSemantics.insert(.sceneDepth)
        }
        arView.session.run(configuration)
        arView.session.delegate = context.coordinator
        return arView
    }
    
    func updateUIView(_ uiView: ARView, context: Context) {
        // 必要に応じた更新処理
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(depthData: depthData)
    }
    
    class Coordinator: NSObject, ARSessionDelegate {
        var depthData: DepthData
        
        init(depthData: DepthData) {
            self.depthData = depthData
        }
        
        func session(_ session: ARSession, didUpdate frame: ARFrame) {
            guard let sceneDepth = frame.sceneDepth else { return }
            let depthMap = sceneDepth.depthMap
            let width = CVPixelBufferGetWidth(depthMap)
            let height = CVPixelBufferGetHeight(depthMap)
            CVPixelBufferLockBaseAddress(depthMap, .readOnly)
            if let baseAddress = CVPixelBufferGetBaseAddress(depthMap) {
                let floatBuffer = baseAddress.assumingMemoryBound(to: Float32.self)
                let centerIndex = (height / 2) * width + (width / 2)
                let depthAtCenter = floatBuffer[centerIndex]
                CVPixelBufferUnlockBaseAddress(depthMap, .readOnly)
                // メインスレッドでSwiftUIの状態を更新
                DispatchQueue.main.async {
                    self.depthData.centerDepth = depthAtCenter
                }
            } else {
                CVPixelBufferUnlockBaseAddress(depthMap, .readOnly)
            }
        }
    }
}


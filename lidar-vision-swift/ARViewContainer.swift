import SwiftUI
import ARKit
import RealityKit

// ARViewをSwiftUIに統合するビュー
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
    
    func updateUIView(_ uiView: ARView, context: Context) { }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(depthData: depthData)
    }
    
    class Coordinator: NSObject, ARSessionDelegate {
        var depthData: DepthData
        let ciContext = CIContext()
        
        init(depthData: DepthData) {
            self.depthData = depthData
        }
        
        func session(_ session: ARSession, didUpdate frame: ARFrame) {
            guard let sceneDepth = frame.sceneDepth else { return }
            let depthMap = sceneDepth.depthMap
            let width = CVPixelBufferGetWidth(depthMap)
            let height = CVPixelBufferGetHeight(depthMap)
            
            CVPixelBufferLockBaseAddress(depthMap, .readOnly)
            defer { CVPixelBufferUnlockBaseAddress(depthMap, .readOnly) }
            
            // 中心深度の取得
            if let baseAddress = CVPixelBufferGetBaseAddress(depthMap) {
                let floatBuffer = baseAddress.assumingMemoryBound(to: Float32.self)
                let centerIndex = (height / 2) * width + (width / 2)
                let depthAtCenter = floatBuffer[centerIndex]
                DispatchQueue.main.async {
                    self.depthData.centerDepth = depthAtCenter
                }
            }
            
            // Depth Mapを疑似カラー画像に変換して更新
            if let overlayImage = self.imageFromPixelBuffer(depthMap) {
                DispatchQueue.main.async {
                    self.depthData.depthOverlayImage = overlayImage
                }
            }
        }
        
        func imageFromPixelBuffer(_ pixelBuffer: CVPixelBuffer) -> UIImage? {
            let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
            guard let falseColorFilter = CIFilter(name: "CIFalseColor") else { return nil }
            falseColorFilter.setValue(ciImage, forKey: kCIInputImageKey)
            falseColorFilter.setValue(CIColor(red: 0, green: 0, blue: 1), forKey: "inputColor0")
            falseColorFilter.setValue(CIColor(red: 1, green: 0, blue: 0), forKey: "inputColor1")
            guard let outputImage = falseColorFilter.outputImage else { return nil }
            guard let cgImage = ciContext.createCGImage(outputImage, from: outputImage.extent) else { return nil }
            return UIImage(cgImage: cgImage)
        }
    }
}

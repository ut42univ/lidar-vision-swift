import Foundation
import ARKit
import RealityKit
import CoreImage
import UIKit

final class ARSessionManager: NSObject, ObservableObject, ARSessionDelegate {
    @Published var centerDepth: Float = 0.0
    @Published var depthOverlayImage: UIImage?
    weak var arView: ARView?
    
    private let ciContext = CIContext()
    // Configurable pseudo-color parameters for depth overlay
    private let overlayColor0 = CIColor(red: 0, green: 0, blue: 1)
    private let overlayColor1 = CIColor(red: 1, green: 0, blue: 0)
    
    func startSession(for arView: ARView) {
        self.arView = arView
        let configuration = ARWorldTrackingConfiguration()
        if ARWorldTrackingConfiguration.supportsFrameSemantics(.sceneDepth) {
            configuration.frameSemantics.insert(.sceneDepth)
        }
        arView.session.delegate = self
        arView.session.run(configuration)
    }
    
    func session(_ session: ARSession, didUpdate frame: ARFrame) {
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
        
        if let overlayImage = generateOverlayImage(from: depthMap) {
            DispatchQueue.main.async {
                self.depthOverlayImage = overlayImage
            }
        }
    }
    
    private func generateOverlayImage(from pixelBuffer: CVPixelBuffer) -> UIImage? {
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        guard let falseColorFilter = CIFilter(name: "CIFalseColor") else { return nil }
        falseColorFilter.setValue(ciImage, forKey: kCIInputImageKey)
        falseColorFilter.setValue(overlayColor0, forKey: "inputColor0")
        falseColorFilter.setValue(overlayColor1, forKey: "inputColor1")
        
        guard let outputImage = falseColorFilter.outputImage,
              let cgImage = ciContext.createCGImage(outputImage, from: outputImage.extent) else {
            return nil
        }
        return UIImage(cgImage: cgImage)
    }
    
    func capturePhoto() -> UIImage? {
        guard let frame = arView?.session.currentFrame else { return nil }
        let imageBuffer = frame.capturedImage
        let ciImage = CIImage(cvPixelBuffer: imageBuffer)
        guard let cgImage = ciContext.createCGImage(ciImage, from: ciImage.extent) else { return nil }
        let orientation = UIImage.Orientation(deviceOrientation: UIDevice.current.orientation)
        return UIImage(cgImage: cgImage, scale: 1.0, orientation: orientation)
    }
}

extension UIImage.Orientation {
    init(deviceOrientation: UIDeviceOrientation) {
        switch deviceOrientation {
        case .portrait: self = .right
        case .landscapeLeft: self = .up
        case .landscapeRight: self = .down
        case .portraitUpsideDown: self = .left
        default: self = .right
        }
    }
}

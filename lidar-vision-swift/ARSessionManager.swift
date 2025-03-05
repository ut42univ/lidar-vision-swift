//
//  ARSessionManager.swift
//  lidar-vision-swift
//
//  Created by Takuya Uehara on 2025/03/05.
//


import Foundation
import ARKit
import RealityKit
import CoreImage
import UIKit

// Manages AR session and depth data extraction
final class ARSessionManager: NSObject, ObservableObject, ARSessionDelegate {
    // Published properties for depth value and overlay image
    @Published var centerDepth: Float = 0.0
    @Published var depthOverlayImage: UIImage? = nil
    
    private let ciContext = CIContext()
    
    // Starts the AR session with the required configuration
    func startSession(for arView: ARView) {
        let configuration = ARWorldTrackingConfiguration()
        if ARWorldTrackingConfiguration.supportsFrameSemantics(.sceneDepth) {
            configuration.frameSemantics.insert(.sceneDepth)
        }
        arView.session.delegate = self
        arView.session.run(configuration)
    }
    
    // ARSessionDelegate method to process each ARFrame
    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        guard let sceneDepth = frame.sceneDepth else { return }
        let depthMap = sceneDepth.depthMap
        let width = CVPixelBufferGetWidth(depthMap)
        let height = CVPixelBufferGetHeight(depthMap)
        
        CVPixelBufferLockBaseAddress(depthMap, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(depthMap, .readOnly) }
        
        // Extract the center depth value
        if let baseAddress = CVPixelBufferGetBaseAddress(depthMap) {
            let floatBuffer = baseAddress.assumingMemoryBound(to: Float32.self)
            let centerIndex = (height / 2) * width + (width / 2)
            let depthAtCenter = floatBuffer[centerIndex]
            DispatchQueue.main.async {
                self.centerDepth = depthAtCenter
            }
        }
        
        // Generate a pseudo-colored overlay image from the depth map
        if let overlayImage = generateOverlayImage(from: depthMap) {
            DispatchQueue.main.async {
                self.depthOverlayImage = overlayImage
            }
        }
    }
    
    // Converts a CVPixelBuffer depth map into a pseudo-colored UIImage
    private func generateOverlayImage(from pixelBuffer: CVPixelBuffer) -> UIImage? {
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        guard let falseColorFilter = CIFilter(name: "CIFalseColor") else { return nil }
        falseColorFilter.setValue(ciImage, forKey: kCIInputImageKey)
        falseColorFilter.setValue(CIColor(red: 0, green: 0, blue: 1), forKey: "inputColor0")
        falseColorFilter.setValue(CIColor(red: 1, green: 0, blue: 0), forKey: "inputColor1")
        
        guard let outputImage = falseColorFilter.outputImage,
              let cgImage = ciContext.createCGImage(outputImage, from: outputImage.extent) else {
            return nil
        }
        return UIImage(cgImage: cgImage)
    }
}

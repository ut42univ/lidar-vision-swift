import SwiftUI
import ARKit
import RealityKit

struct ARViewContainer: UIViewRepresentable {
    @ObservedObject var sessionManager: ARSessionManager
    
    func makeUIView(context: Context) -> ARView {
        let arView = ARView(frame: .zero)
        sessionManager.startSession(for: arView)
        return arView
    }
    
    func updateUIView(_ uiView: ARView, context: Context) { }
}

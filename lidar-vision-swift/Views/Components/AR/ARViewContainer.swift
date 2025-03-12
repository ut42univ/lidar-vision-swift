 import SwiftUI
import ARKit
import RealityKit

/// ARViewのSwiftUIラッパー
struct ARViewContainer: UIViewRepresentable {
    @ObservedObject var sessionService: ARSessionService
    
    func makeUIView(context: Context) -> ARView {
        let arView = ARView(frame: .zero)
        sessionService.startSession(for: arView)
        return arView
    }
    
    func updateUIView(_ uiView: ARView, context: Context) {
        // 更新が必要な場合のみ実装
    }
}

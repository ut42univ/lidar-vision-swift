//
//  ARViewContainer.swift
//  lidar-vision-swift
//
//  Created by Takuya Uehara on 2025/02/28.
//


import SwiftUI
import ARKit
import RealityKit

struct ARViewContainer: UIViewRepresentable {
    func makeUIView(context: Context) -> ARView {
        let arView = ARView(frame: .zero)
        // ARセッションの設定
        let configuration = ARWorldTrackingConfiguration()
        // LiDAR対応の深度情報取得が可能か確認し、取得を有効化
        if ARWorldTrackingConfiguration.supportsFrameSemantics(.sceneDepth) {
            configuration.frameSemantics.insert(.sceneDepth)
        }
        arView.session.run(configuration)
        // セッションのdelegateにCoordinatorを設定してフレーム更新時の処理を行う
        arView.session.delegate = context.coordinator
        return arView
    }
    
    func updateUIView(_ uiView: ARView, context: Context) {
        // 状況に応じた更新処理を追加可能
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    class Coordinator: NSObject, ARSessionDelegate {
        // ARSessionのフレーム更新時に呼ばれる
        func session(_ session: ARSession, didUpdate frame: ARFrame) {
            // sceneDepthが取得できるか確認
            guard let sceneDepth = frame.sceneDepth else { return }
            let depthMap = sceneDepth.depthMap
            // depthMapから画像サイズを取得
            let width = CVPixelBufferGetWidth(depthMap)
            let height = CVPixelBufferGetHeight(depthMap)
            // ピクセルバッファをロックしてメモリアクセス
            CVPixelBufferLockBaseAddress(depthMap, .readOnly)
            if let baseAddress = CVPixelBufferGetBaseAddress(depthMap) {
                // Float32型のバッファとして扱う
                let floatBuffer = baseAddress.assumingMemoryBound(to: Float32.self)
                // 画像中心のインデックスを計算
                let centerIndex = (height / 2) * width + (width / 2)
                let depthAtCenter = floatBuffer[centerIndex]
                // ロック解除
                CVPixelBufferUnlockBaseAddress(depthMap, .readOnly)
                // 深度値（単位はメートル）を利用してUI更新やログ出力
                print("中心の深度: \(depthAtCenter) m")
                // 例：DispatchQueue.main.asyncでSwiftUI側の@Stateを更新するなど
            } else {
                CVPixelBufferUnlockBaseAddress(depthMap, .readOnly)
            }
        }
    }
}

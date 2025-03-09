//
//  MeshManagementService.swift
//  lidar-vision-swift
//
//  Created by Takuya Uehara on 2025/03/09.
//


import Foundation
import ARKit

/// ARメッシュアンカーの管理を行うサービス
final class MeshManagementService {
    // メッシュデータ
    private(set) var meshAnchors: [ARMeshAnchor] = []
    
    /// メッシュアンカーを追加
    func addMeshAnchor(_ meshAnchor: ARMeshAnchor) {
        meshAnchors.append(meshAnchor)
    }
    
    /// メッシュアンカーを更新
    func updateMeshAnchor(_ meshAnchor: ARMeshAnchor) {
        if let index = meshAnchors.firstIndex(where: { $0.identifier == meshAnchor.identifier }) {
            meshAnchors[index] = meshAnchor
        } else {
            addMeshAnchor(meshAnchor)
        }
    }
    
    /// メッシュアンカーを削除
    func removeMeshAnchor(_ meshAnchor: ARMeshAnchor) {
        if let index = meshAnchors.firstIndex(where: { $0.identifier == meshAnchor.identifier }) {
            meshAnchors.remove(at: index)
        }
    }
    
    /// すべてのメッシュアンカーをクリア
    func clearMeshAnchors() {
        meshAnchors.removeAll()
    }
}
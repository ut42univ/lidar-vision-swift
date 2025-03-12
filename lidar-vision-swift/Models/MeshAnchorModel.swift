import ARKit
import RealityKit

/// ARMeshAnchorのデータモデル
/// ARKitのメッシュデータを扱いやすい形式で保持
struct MeshAnchorModel: Identifiable {
    let id: UUID
    let transform: simd_float4x4
    let geometry: ARMeshGeometry
    let center: simd_float3
    let extent: simd_float3
    
    /// ARMeshAnchorからモデルを作成
    init(from meshAnchor: ARMeshAnchor) {
        self.id = meshAnchor.identifier
        self.transform = meshAnchor.transform
        self.geometry = meshAnchor.geometry
        
        // アンカーの中心位置を計算
        self.center = simd_make_float3(
            meshAnchor.transform.columns.3.x,
            meshAnchor.transform.columns.3.y,
            meshAnchor.transform.columns.3.z
        )
        
        // メッシュの大きさを推定
        let vertexBuffer = meshAnchor.geometry.vertices
        let vertices = vertexBuffer.buffer.contents().bindMemory(
            to: SIMD3<Float>.self,
            capacity: vertexBuffer.count
        )
        
        var minBounds = SIMD3<Float>(repeating: Float.greatestFiniteMagnitude)
        var maxBounds = SIMD3<Float>(repeating: -Float.greatestFiniteMagnitude)
        
        // 頂点バッファから範囲を計算
        for i in 0..<vertexBuffer.count {
            let vertex = vertices[i]
            minBounds = min(minBounds, vertex)
            maxBounds = max(maxBounds, vertex)
        }
        
        // メッシュの大きさを設定
        self.extent = maxBounds - minBounds
    }
    
    /// ポイントがメッシュに含まれているかチェック
    func contains(point: simd_float3, withTolerance tolerance: Float = 0.1) -> Bool {
        let localPoint = simd_mul(simd_inverse(transform), simd_float4(point.x, point.y, point.z, 1.0))
        let localPosition = simd_make_float3(localPoint.x, localPoint.y, localPoint.z)
        
        // メッシュの境界ボックス内にあるかチェック
        let halfExtent = extent * 0.5
        let lowerBound = center - halfExtent - tolerance
        let upperBound = center + halfExtent + tolerance
        
        return (
            localPosition.x >= lowerBound.x && localPosition.x <= upperBound.x &&
            localPosition.y >= lowerBound.y && localPosition.y <= upperBound.y &&
            localPosition.z >= lowerBound.z && localPosition.z <= upperBound.z
        )
    }
    
    /// メッシュと他のメッシュの距離を計算
    func distance(to other: MeshAnchorModel) -> Float {
        return simd_distance(self.center, other.center)
    }
}

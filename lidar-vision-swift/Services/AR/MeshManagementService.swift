import Foundation
import ARKit
import Combine

/// ARメッシュアンカーの管理を行うサービス（最適化版）
final class MeshManagementService: ObservableObject {
    // メッシュデータ
    @Published private(set) var meshAnchors: [ARMeshAnchor] = []
    
    // パフォーマンス最適化のための高速アクセスディクショナリ
    private var anchorsById: [UUID: ARMeshAnchor] = [:]
    
    // メモリ管理オプション
    private var autoCleanupEnabled = true
    private var lastCleanupTime = Date()
    private var cleanupInterval: TimeInterval = 60 // 秒単位、定期的なメッシュのクリーンアップ
    
    // メッシュ確認用のメトリック
    private(set) var totalMeshCount: Int = 0
    private(set) var totalVertexCount: Int = 0
    
    init(autoCleanupEnabled: Bool = true) {
        self.autoCleanupEnabled = autoCleanupEnabled
    }
    
    /// メッシュアンカーを追加
    func addMeshAnchor(_ meshAnchor: ARMeshAnchor) {
        // 既に同じIDのアンカーが存在するか確認
        if anchorsById[meshAnchor.identifier] != nil {
            updateMeshAnchor(meshAnchor)
            return
        }
        
        // データ構造に追加
        meshAnchors.append(meshAnchor)
        anchorsById[meshAnchor.identifier] = meshAnchor
        
        // メトリックを更新
        updateMetrics()
        
        // 必要に応じてメモリを最適化
        checkAndPerformCleanup()
    }
    
    /// メッシュアンカーを更新
    func updateMeshAnchor(_ meshAnchor: ARMeshAnchor) {
        if let index = meshAnchors.firstIndex(where: { $0.identifier == meshAnchor.identifier }) {
            meshAnchors[index] = meshAnchor
            anchorsById[meshAnchor.identifier] = meshAnchor
            
            // メトリックを更新
            updateMetrics()
        } else {
            // 存在しない場合は追加
            addMeshAnchor(meshAnchor)
        }
    }
    
    /// メッシュアンカーを削除
    func removeMeshAnchor(_ meshAnchor: ARMeshAnchor) {
        anchorsById.removeValue(forKey: meshAnchor.identifier)
        
        if let index = meshAnchors.firstIndex(where: { $0.identifier == meshAnchor.identifier }) {
            meshAnchors.remove(at: index)
            
            // メトリックを更新
            updateMetrics()
        }
    }
    
    /// すべてのメッシュアンカーをクリア
    func clearMeshAnchors() {
        meshAnchors.removeAll()
        anchorsById.removeAll()
        
        // メトリックをリセット
        totalMeshCount = 0
        totalVertexCount = 0
        
        // 最終クリーンアップ時間を更新
        lastCleanupTime = Date()
    }
    
    /// 指定した座標に最も近いメッシュアンカーを取得
    func getNearestMeshAnchor(to position: simd_float3, maxDistance: Float = Float.infinity) -> ARMeshAnchor? {
        guard !meshAnchors.isEmpty else { return nil }
        
        var nearestAnchor: ARMeshAnchor? = nil
        var minDistance = maxDistance
        
        for anchor in meshAnchors {
            let anchorPosition = simd_make_float3(
                anchor.transform.columns.3.x,
                anchor.transform.columns.3.y,
                anchor.transform.columns.3.z
            )
            
            let distance = simd_distance(position, anchorPosition)
            
            if distance < minDistance {
                minDistance = distance
                nearestAnchor = anchor
            }
        }
        
        return nearestAnchor
    }
    
    /// メッシュアンカーを各部屋や区画ごとにグループ化（簡易的な空間分割）
    func groupMeshesIntoClusters(clusterRadius: Float = 0.5) -> [[ARMeshAnchor]] {
        var clusters: [[ARMeshAnchor]] = []
        var processedIds = Set<UUID>()
        
        // 各メッシュについて
        for anchor in meshAnchors {
            // すでに処理済みのメッシュはスキップ
            if processedIds.contains(anchor.identifier) {
                continue
            }
            
            // 新しいクラスターを開始
            var cluster: [ARMeshAnchor] = [anchor]
            processedIds.insert(anchor.identifier)
            
            // アンカーの位置
            let anchorPosition = simd_make_float3(
                anchor.transform.columns.3.x,
                anchor.transform.columns.3.y,
                anchor.transform.columns.3.z
            )
            
            // 残りのメッシュで近いものを探す
            for otherAnchor in meshAnchors {
                if processedIds.contains(otherAnchor.identifier) {
                    continue
                }
                
                let otherPosition = simd_make_float3(
                    otherAnchor.transform.columns.3.x,
                    otherAnchor.transform.columns.3.y,
                    otherAnchor.transform.columns.3.z
                )
                
                // 距離チェック
                if simd_distance(anchorPosition, otherPosition) <= clusterRadius {
                    cluster.append(otherAnchor)
                    processedIds.insert(otherAnchor.identifier)
                }
            }
            
            // クラスターをリストに追加
            clusters.append(cluster)
        }
        
        return clusters
    }
    
    // MARK: - 内部ヘルパーメソッド
    
    /// メトリックを更新
    private func updateMetrics() {
        totalMeshCount = meshAnchors.count
        
        // 頂点数の合計を計算
        totalVertexCount = meshAnchors.reduce(0) { sum, anchor in
            sum + anchor.geometry.vertices.count
        }
    }
    
    /// 必要に応じてメモリ最適化のためのクリーンアップを実行
    private func checkAndPerformCleanup() {
        guard autoCleanupEnabled else { return }
        
        let now = Date()
        if now.timeIntervalSince(lastCleanupTime) > cleanupInterval {
            performCleanup()
            lastCleanupTime = now
        }
    }
    
    /// メモリ最適化のためのクリーンアップを実行
    private func performCleanup() {
        // メモリ使用量を減らすための最適化
        
        // 1. 古くなったメッシュの削除（ARKitが自動的に管理するため、通常は不要）
        
        // 2. 重複メッシュの確認と削除
        removeDuplicateMeshes()
        
        // 3. 不要な詳細情報の削除（オプション）
        
        print("Mesh cleanup performed - Total meshes: \(totalMeshCount), Total vertices: \(totalVertexCount)")
    }
    
    /// 重複または非常に近いメッシュを削除
    private func removeDuplicateMeshes() {
        // 位置がほぼ同じメッシュを特定して削除
        // 実装はアプリケーションの具体的な要件によって異なるため、
        // ここではアウトラインのみを提供
        
        // この実装は実際のアプリケーションニーズに応じてカスタマイズする必要がある
        var indicesToRemove = Set<Int>()
        
        // 簡易的な近接チェック
        for i in 0..<meshAnchors.count {
            for j in (i+1)..<meshAnchors.count {
                let anchor1 = meshAnchors[i]
                let anchor2 = meshAnchors[j]
                
                let pos1 = simd_make_float3(
                    anchor1.transform.columns.3.x,
                    anchor1.transform.columns.3.y,
                    anchor1.transform.columns.3.z
                )
                
                let pos2 = simd_make_float3(
                    anchor2.transform.columns.3.x,
                    anchor2.transform.columns.3.y,
                    anchor2.transform.columns.3.z
                )
                
                // 非常に近い場合は重複と見なす（距離閾値はアプリケーションによって調整）
                if simd_distance(pos1, pos2) < 0.05 {
                    // 頂点数が少ない方を削除候補とする
                    if anchor1.geometry.vertices.count < anchor2.geometry.vertices.count {
                        indicesToRemove.insert(i)
                    } else {
                        indicesToRemove.insert(j)
                    }
                }
            }
        }
        
        // 削除候補を削除（降順ソートして配列のインデックスが変わらないようにする）
        for index in indicesToRemove.sorted(by: >) {
            let anchorToRemove = meshAnchors[index]
            removeMeshAnchor(anchorToRemove)
        }
    }
    
    /// 自動クリーンアップの設定を更新
    func setAutoCleanup(enabled: Bool, interval: TimeInterval? = nil) {
        autoCleanupEnabled = enabled
        
        if let newInterval = interval {
            cleanupInterval = newInterval
        }
    }
    
    /// 手動でクリーンアップを実行
    func manualCleanup() {
        performCleanup()
        lastCleanupTime = Date()
    }
}

// MARK: - メッシュアンカーモデルの拡張
extension MeshAnchorModel {
    /// 2つのメッシュアンカーモデル間の類似度を計算（0.0-1.0の範囲）
    func similarity(to other: MeshAnchorModel) -> Float {
        // 距離に基づいた類似度
        let distanceSimilarity = 1.0 - min(1.0, distance(to: other) / 5.0) // 5mを最大距離と仮定
        
        // サイズに基づいた類似度
        let sizeSimilarity = 1.0 - min(1.0, simd_distance(self.extent, other.extent) / 2.0)
        
        // 各要素の重みづけ
        return 0.7 * distanceSimilarity + 0.3 * sizeSimilarity
    }
    
    /// メッシュの体積を概算
    var approximateVolume: Float {
        return extent.x * extent.y * extent.z
    }
}

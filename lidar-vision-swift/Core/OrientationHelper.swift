import SwiftUI
import Combine

/// デバイスの向きを管理するヘルパークラス - リファクタリング済み
final class OrientationHelper: ObservableObject {
    @Published var rotationAngle: Double = 90
    private var cancellables = Set<AnyCancellable>() // Setで複数の購読を管理
    
    private let orientationAngles: [UIDeviceOrientation: Double] = [
        .portrait: 90,
        .landscapeLeft: 0,
        .landscapeRight: 180,
        .portraitUpsideDown: -90
    ]
    
    init() {
        UIDevice.current.beginGeneratingDeviceOrientationNotifications()
        
        // 購読を保存するパターンを使用
        NotificationCenter.default.publisher(for: UIDevice.orientationDidChangeNotification)
            .compactMap { [weak self] _ in self?.calculateRotationAngle() }
            .receive(on: RunLoop.main)
            .assign(to: \.rotationAngle, on: self)
            .store(in: &cancellables)
            
        // 初期角度を計算して設定
        rotationAngle = calculateRotationAngle()
    }
    
    /// 現在のデバイス方向に基づいて回転角度を計算
    private func calculateRotationAngle() -> Double {
        return orientationAngles[UIDevice.current.orientation] ?? 90
    }
    
    deinit {
        UIDevice.current.endGeneratingDeviceOrientationNotifications()
        cancellables.forEach { $0.cancel() }
    }
}

import SwiftUI
import Combine

/// デバイスの向きを管理するヘルパークラス
final class OrientationHelper: ObservableObject {
    @Published var rotationAngle: Double = 90
    private var cancellable: AnyCancellable?
    
    private let orientationAngles: [UIDeviceOrientation: Double] = [
        .portrait: 90,
        .landscapeLeft: 0,
        .landscapeRight: 180,
        .portraitUpsideDown: -90
    ]
    
    init() {
        UIDevice.current.beginGeneratingDeviceOrientationNotifications()
        cancellable = NotificationCenter.default.publisher(for: UIDevice.orientationDidChangeNotification)
            .sink { [weak self] _ in self?.updateRotationAngle() }
        updateRotationAngle()
    }
    
    private func updateRotationAngle() {
        let angle = orientationAngles[UIDevice.current.orientation] ?? 90
        DispatchQueue.main.async {
            self.rotationAngle = angle
        }
    }
    
    deinit {
        UIDevice.current.endGeneratingDeviceOrientationNotifications()
    }
}

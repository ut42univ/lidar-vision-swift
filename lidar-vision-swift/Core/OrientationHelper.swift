import SwiftUI
import Combine

/// デバイスの向きを管理するヘルパークラス
final class OrientationHelper: ObservableObject {
    @Published var rotationAngle: Double = 90
    private var cancellables = Set<AnyCancellable>()
    
    private let orientationAngles: [UIDeviceOrientation: Double] = [
        .portrait: 90,
        .landscapeLeft: 0,
        .landscapeRight: 180,
        .portraitUpsideDown: -90
    ]
    
    init() {
        UIDevice.current.beginGeneratingDeviceOrientationNotifications()
        
        NotificationCenter.default.publisher(for: UIDevice.orientationDidChangeNotification)
            .compactMap { [weak self] _ in self?.calculateRotationAngle() }
            .receive(on: DispatchQueue.main)
            .assign(to: \.rotationAngle, on: self)
            .store(in: &cancellables)
            
        rotationAngle = calculateRotationAngle()
    }
    
    private func calculateRotationAngle() -> Double {
        return orientationAngles[UIDevice.current.orientation] ?? 90
    }
    
    deinit {
        UIDevice.current.endGeneratingDeviceOrientationNotifications()
    }
}

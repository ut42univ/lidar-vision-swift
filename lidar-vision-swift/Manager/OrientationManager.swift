//
//  OrientationManager.swift
//  lidar-vision-swift
//
//  Created by Takuya Uehara on 2025/03/05.
//


import SwiftUI
import Combine

// Monitors device orientation and publishes the rotation angle for depth overlay correction.
final class OrientationManager: ObservableObject {
    // The rotation angle (in degrees) to apply to the depth overlay image.
    // The default value assumes portrait mode (90 degrees rotation for a landscape depth image).
    @Published var rotationAngle: Double = 90

    private var cancellable: AnyCancellable?
    
    init() {
        // Begin generating orientation notifications.
        UIDevice.current.beginGeneratingDeviceOrientationNotifications()
        cancellable = NotificationCenter.default.publisher(for: UIDevice.orientationDidChangeNotification)
            .sink { [weak self] _ in
                self?.updateRotationAngle()
            }
        updateRotationAngle()
    }
    
    private func updateRotationAngle() {
        let orientation = UIDevice.current.orientation
        // Adjust the rotation angle based on the device's orientation.
        var angle: Double = 90  // default: portrait
        switch orientation {
        case .portrait:
            angle = 90
        case .landscapeLeft:
            angle = 0
        case .landscapeRight:
            angle = 180
        case .portraitUpsideDown:
            angle = -90
        default:
            angle = 90
        }
        DispatchQueue.main.async {
            self.rotationAngle = angle
        }
    }
    
    deinit {
        UIDevice.current.endGeneratingDeviceOrientationNotifications()
    }
}

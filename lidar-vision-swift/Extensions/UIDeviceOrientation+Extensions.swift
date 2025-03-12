import UIKit

extension UIDeviceOrientation {
    /// デバイスの向きから空間オーディオ向きの値を取得
    var deviceOrientation: (yaw: Float, pitch: Float, roll: Float)? {
        switch self {
        case .portrait:
            return (yaw: 0, pitch: 0, roll: 0)
        case .portraitUpsideDown:
            return (yaw: 0, pitch: 0, roll: Float.pi)
        case .landscapeLeft:
            return (yaw: -Float.pi/2, pitch: 0, roll: 0)
        case .landscapeRight:
            return (yaw: Float.pi/2, pitch: 0, roll: 0)
        case .faceUp:
            return (yaw: 0, pitch: -Float.pi/2, roll: 0)
        case .faceDown:
            return (yaw: 0, pitch: Float.pi/2, roll: 0)
        default:
            return nil
        }
    }
}

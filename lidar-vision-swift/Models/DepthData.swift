import Combine
import UIKit

// Observable object for storing depth information
class DepthData: ObservableObject {
    @Published var centerDepth: Float = 0.0
    @Published var depthOverlayImage: UIImage? = nil
}

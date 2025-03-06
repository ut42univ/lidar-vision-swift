import SwiftUI
import Combine

final class ContentViewModel: ObservableObject {
    @Published var sessionManager: ARSessionManager
    @Published var soundEnabled: Bool = false
    @Published var capturedImage: UIImage?
    
    private let feedbackManager: FeedbackManager
    private var cancellables = Set<AnyCancellable>()
    
    // Depth thresholds for feedback (in meters)
    private let warningDepthThreshold: Float = 1.0
    private let criticalDepthThreshold: Float = 0.5
    
    init(sessionManager: ARSessionManager = ARSessionManager(), feedbackManager: FeedbackManager = FeedbackManager()) {
        self.sessionManager = sessionManager
        self.feedbackManager = feedbackManager
        
        // Forward session manager changes to update the view
        sessionManager.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)
        
        sessionManager.$centerDepth
            .receive(on: RunLoop.main)
            .sink { [weak self] newDepth in
                self?.handleDepthChange(newDepth: newDepth)
            }
            .store(in: &cancellables)
    }
    
    private func handleDepthChange(newDepth: Float) {
        if newDepth < criticalDepthThreshold {
            feedbackManager.handleCriticalState(soundEnabled: soundEnabled)
        } else if newDepth < warningDepthThreshold {
            feedbackManager.handleWarningState(soundEnabled: soundEnabled)
        } else {
            feedbackManager.stopAll()
        }
    }
    
    func capturePhoto() {
        if let image = sessionManager.capturePhoto() {
            capturedImage = image
        }
    }
    
    var alertColor: Color {
        switch sessionManager.centerDepth {
        case ..<criticalDepthThreshold: return .red
        case ..<warningDepthThreshold: return .yellow
        default: return .white
        }
    }
    
    var overlayColor: Color? {
        switch sessionManager.centerDepth {
        case ..<criticalDepthThreshold: return Color.red.opacity(0.2)
        case ..<warningDepthThreshold: return Color.yellow.opacity(0.2)
        default: return nil
        }
    }
}

//
//  ContentViewModel.swift
//  lidar-vision-swift
//
//  Created by Takuya Uehara on 2025/03/05.
//


import SwiftUI
import Combine

// View model that handles feedback based on depth changes
final class ContentViewModel: ObservableObject {
    // AR session manager provides depth data
    @Published var sessionManager: ARSessionManager
    // Controls sound feedback on/off
    @Published var soundEnabled: Bool = false
    
    private let feedbackManager: FeedbackManager
    private var cancellables = Set<AnyCancellable>()
    
    // Depth thresholds for feedback
    private let warningThreshold: Float = 1.0
    private let criticalThreshold: Float = 0.5
    
    init(sessionManager: ARSessionManager = ARSessionManager(), feedbackManager: FeedbackManager = FeedbackManager()) {
        self.sessionManager = sessionManager
        self.feedbackManager = feedbackManager
        
        // Forward changes from ARSessionManager to ContentViewModel
        sessionManager.objectWillChange
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
        
        // Observe changes to centerDepth for feedback handling
        sessionManager.$centerDepth
            .receive(on: RunLoop.main)
            .sink { [weak self] newDepth in
                self?.handleDepthChange(newDepth: newDepth)
            }
            .store(in: &cancellables)
    }

    
    // Adjusts feedback based on the current depth value
    private func handleDepthChange(newDepth: Float) {
        if newDepth < criticalThreshold {
            feedbackManager.handleCriticalState(soundEnabled: soundEnabled)
        } else if newDepth < warningThreshold {
            feedbackManager.handleWarningState(soundEnabled: soundEnabled)
        } else {
            feedbackManager.stopAll()
        }
    }
    
    // Computed property for the crosshair color based on depth
    var alertColor: Color {
        switch sessionManager.centerDepth {
        case ..<criticalThreshold: return .red
        case ..<warningThreshold: return .yellow
        default: return .white
        }
    }
    
    // Computed property for an optional overlay color based on depth
    var overlayColor: Color? {
        switch sessionManager.centerDepth {
        case ..<criticalThreshold: return Color.red.opacity(0.2)
        case ..<warningThreshold: return Color.yellow.opacity(0.2)
        default: return nil
        }
    }
}

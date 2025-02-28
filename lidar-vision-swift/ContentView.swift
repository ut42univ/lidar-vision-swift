import SwiftUI
import AudioToolbox

struct ContentView: View {
    @StateObject var depthData = DepthData()
    @StateObject var feedbackManager = FeedbackManager()
    
    // Depth threshold values
    private let warningThreshold: Float = 1.0
    private let criticalThreshold: Float = 0.5
    
    @State private var soundEnabled: Bool = false
    
    private var alertColor: Color {
        switch depthData.centerDepth {
        case ..<criticalThreshold: return .red
        case ..<warningThreshold: return .yellow
        default: return .white
        }
    }
    
    private var overlayColor: Color? {
        switch depthData.centerDepth {
        case ..<criticalThreshold: return Color.red.opacity(0.2)
        case ..<warningThreshold: return Color.yellow.opacity(0.2)
        default: return nil
        }
    }
    
    var body: some View {
        ZStack {
            ARViewContainer(depthData: depthData)
                .edgesIgnoringSafeArea(.all)
            
            // Depth map overlay (PIP)
            if let depthImage = depthData.depthOverlayImage {
                Image(uiImage: depthImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .rotationEffect(Angle(degrees: 90))
                    .frame(width: 150, height: 150)
                    .cornerRadius(4)
                    .padding(4)
                    .background(Color.black.opacity(0.7))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .padding()
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
            }
            
            // Depth value display
            VStack {
                Spacer()
                Text(String(format: "Distance: %.2f m", depthData.centerDepth))
                    .padding()
                    .background(Color.black.opacity(0.5))
                    .foregroundColor(.white)
                    .cornerRadius(8)
                    .padding(.bottom, 20)
            }
            
            // Safety overlay
            if let overlayColor = overlayColor {
                overlayColor
                    .edgesIgnoringSafeArea(.all)
                    .transition(.opacity)
            }
        }
        .overlay(
            CrossMarker(color: alertColor)
                .frame(width: 40, height: 40),
            alignment: .center
        )
        .overlay(
            Button(action: { soundEnabled.toggle() }) {
                Image(systemName: soundEnabled ? "speaker.wave.2.fill" : "speaker.slash.fill")
                    .font(.system(size: 24))
                    .frame(width: 44, height: 44)
                    .padding()
                    .background(Color.black.opacity(0.5))
                    .foregroundColor(.white)
                    .clipShape(Circle())
            }
            .padding(),
            alignment: .topLeading
        )
        .onChange(of: depthData.centerDepth) { _, newDepth in
            handleDepthChange(newDepth: newDepth)
        }
        .onDisappear {
            feedbackManager.stopAll()
        }
    }
    
    private func handleDepthChange(newDepth: Float) {
        switch newDepth {
        case ..<criticalThreshold:
            feedbackManager.handleCriticalState(soundEnabled: soundEnabled)
        case ..<warningThreshold:
            feedbackManager.handleWarningState(soundEnabled: soundEnabled)
        default:
            feedbackManager.stopAll()
        }
    }
}

#Preview {
    ContentView()
}

import SwiftUI
import AudioToolbox

// Main content view rendering AR and feedback UI.
struct ContentView: View {
    @StateObject var viewModel = ContentViewModel()
    @StateObject var orientationManager = OrientationManager()

    var body: some View {
        ZStack {
            ARViewContainer(sessionManager: viewModel.sessionManager)
                .edgesIgnoringSafeArea(.all)
            
            // PIP depth overlay with dynamic rotation based on device orientation.
            if let depthImage = viewModel.sessionManager.depthOverlayImage {
                Image(uiImage: depthImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .rotationEffect(Angle(degrees: orientationManager.rotationAngle))
                    .frame(width: 150, height: 150)
                    .cornerRadius(4)
                    .padding(4)
                    .background(Color.black.opacity(0.7))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .padding()
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
            }
            
            // Depth value display at the bottom.
            VStack {
                Spacer()
                Text(String(format: "Distance: %.2f m", viewModel.sessionManager.centerDepth))
                    .padding()
                    .background(Color.black.opacity(0.5))
                    .foregroundColor(.white)
                    .cornerRadius(8)
                    .padding(.bottom, 20)
            }
            
            // Safety overlay based on depth thresholds.
            if let overlayColor = viewModel.overlayColor {
                overlayColor
                    .edgesIgnoringSafeArea(.all)
                    .transition(.opacity)
            }
        }
        .overlay(
            // Crosshair marker with dynamic alert color.
            CrossMarker(color: viewModel.alertColor)
                .frame(width: 40, height: 40),
            alignment: .center
        )
        .overlay(
            // Button to toggle sound feedback.
            Button(action: { viewModel.soundEnabled.toggle() }) {
                Image(systemName: viewModel.soundEnabled ? "speaker.wave.2.fill" : "speaker.slash.fill")
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
    }
}

#Preview {
    ContentView()
}

import SwiftUI
import AudioToolbox

struct ContentView: View {
    @StateObject var viewModel = ContentViewModel()
    @StateObject var orientationManager = OrientationManager()
    
    var body: some View {
        ZStack {
            ARViewContainer(sessionManager: viewModel.sessionManager)
                .ignoresSafeArea()
            
            // Removed PIP depth overlay
            
            VStack {
                Spacer()
                Text(String(format: "Distance: %.2f m", viewModel.sessionManager.centerDepth))
                    .padding()
                    .background(Color.black.opacity(0.5))
                    .foregroundColor(.white)
                    .cornerRadius(8)
                    .padding(.bottom, 20)
            }
            
            if let overlayColor = viewModel.overlayColor {
                overlayColor
                    .ignoresSafeArea()
                    .transition(.opacity)
            }
        }
        .overlay(
            CrossMarker(color: viewModel.alertColor)
                .frame(width: 40, height: 40),
            alignment: .center
        )
        .overlay(
            HStack(spacing: 10) {
                // Sound toggle button
                Button(action: {
                    viewModel.soundEnabled.toggle()
                }) {
                    Image(systemName: viewModel.soundEnabled ? "speaker.wave.2.fill" : "speaker.slash.fill")
                        .font(.system(size: 20))
                        .frame(width: 40, height: 40)
                        .background(Color.black.opacity(0.5))
                        .foregroundColor(.white)
                        .clipShape(Circle())
                }
                
                // Mesh visibility toggle button
                Button(action: {
                    viewModel.toggleMeshVisibility()
                }) {
                    Image(systemName: viewModel.isMeshVisible ? "grid.circle.fill" : "grid.circle")
                        .font(.system(size: 20))
                        .frame(width: 40, height: 40)
                        .background(Color.black.opacity(0.5))
                        .foregroundColor(.white)
                        .clipShape(Circle())
                }
                
                // Mesh reset button
                Button(action: {
                    viewModel.resetMeshCache()
                }) {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.system(size: 20))
                        .frame(width: 40, height: 40)
                        .background(Color.black.opacity(0.5))
                        .foregroundColor(.white)
                        .clipShape(Circle())
                }
            }
            .padding(),
            alignment: .topLeading
        )
        .overlay(
            VStack {
                Spacer()
                HStack {
                    Button(action: {
                        viewModel.capturePhoto()
                    }) {
                        Image(systemName: "camera")
                            .font(.system(size: 24))
                            .frame(width: 44, height: 44)
                            .padding()
                            .background(Color.black.opacity(0.5))
                            .foregroundColor(.white)
                            .clipShape(Circle())
                    }
                    Spacer()
                }
                .padding()
            }
        )
        .fullScreenCover(isPresented: $viewModel.showPhotoDetail, content: {
            if let capturedImage = viewModel.capturedImage {
                PhotoDetailView(image: capturedImage)
            }
        })
    }
}

#Preview {
    ContentView()
}

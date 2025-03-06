import SwiftUI
import AudioToolbox

struct ContentView: View {
    @StateObject var viewModel = ContentViewModel()
    @StateObject var orientationManager = OrientationManager()
    
    var body: some View {
        ZStack {
            ARViewContainer(sessionManager: viewModel.sessionManager)
                .ignoresSafeArea()
            
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
            
            if let photo = viewModel.capturedImage {
                PhotoPreview(image: photo) {
                    withAnimation(.easeInOut) {
                        viewModel.capturedImage = nil
                    }
                }
                .zIndex(1)
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .scale(scale: 0.8)),
                    removal: .opacity.combined(with: .scale(scale: 1.2))
                ))
            }
        }
        .overlay(
            CrossMarker(color: viewModel.alertColor)
                .frame(width: 40, height: 40),
            alignment: .center
        )
        .overlay(
            Button(action: {
                viewModel.soundEnabled.toggle()
            }) {
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
        .overlay(
            Button(action: {
                withAnimation(.easeInOut) {
                    viewModel.capturePhoto()
                }
            }) {
                Image(systemName: "camera")
                    .font(.system(size: 24))
                    .frame(width: 44, height: 44)
                    .padding()
                    .background(Color.black.opacity(0.5))
                    .foregroundColor(.white)
                    .clipShape(Circle())
            }
            .padding(),
            alignment: .bottomLeading
        )
    }
}

struct PhotoPreview: View {
    let image: UIImage
    let onClose: () -> Void
    
    var body: some View {
        ZStack(alignment: .topTrailing) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(maxWidth: 300, maxHeight: 300)
                .background(Color.black.opacity(0.8))
                .cornerRadius(12)
                .padding()
                .shadow(radius: 10)
            
            Button(action: onClose) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 32))
                    .foregroundColor(.white)
                    .padding(8)
            }
        }
    }
}

#Preview {
    ContentView()
}

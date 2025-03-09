import SwiftUI

/// メイン画面
struct ContentView: View {
    @StateObject var viewModel = ContentViewModel()
    @StateObject var orientationHelper = OrientationHelper()
    @State private var showAudioSettings = false
    @State private var showAirPodsAlert = false
    
    var body: some View {
        ZStack {
            // ARView
            ARViewContainer(sessionService: viewModel.sessionService)
                .ignoresSafeArea()
            
            // 深度表示
            VStack {
                Spacer()
                Text(String(format: "距離: %.2f m", viewModel.sessionService.centerDepth))
                    .padding()
                    .background(Color.black.opacity(0.5))
                    .foregroundColor(.white)
                    .cornerRadius(8)
                    .padding(.bottom, 20)
            }
        }
        .overlay(
            CrossMarker(color: viewModel.alertColor)
                .frame(width: 40, height: 40),
            alignment: .center
        )
        .overlay(
            // 上部コントロールボタン
            HStack(spacing: 10) {
                // サウンド切り替えボタン
                controlButton(
                    icon: viewModel.soundEnabled ? "speaker.wave.2.fill" : "speaker.slash.fill",
                    action: { viewModel.soundEnabled.toggle() }
                )
                
                // 空間オーディオ切り替えボタン
                controlButton(
                    icon: viewModel.spatialAudioEnabled ? "airpodsmax" : "headphones",
                    iconColor: viewModel.spatialAudioEnabled ? .green : .white,
                    action: {
                        if !viewModel.spatialAudioEnabled {
                            viewModel.sessionService.recheckAirPodsConnection()
                            showAirPodsAlert = true
                        } else {
                            viewModel.toggleSpatialAudio()
                        }
                    }
                )
                
                // オーディオ設定ボタン
                controlButton(
                    icon: "slider.horizontal.3",
                    action: { showAudioSettings.toggle() }
                )
                
                // メッシュ可視性切り替えボタン
                controlButton(
                    icon: viewModel.isMeshVisible ? "grid.circle.fill" : "grid.circle",
                    action: { viewModel.toggleMeshVisibility() }
                )
                
                // メッシュリセットボタン
                controlButton(
                    icon: "arrow.triangle.2.circlepath",
                    action: { viewModel.resetMeshCache() }
                )
            }
            .padding(),
            alignment: .topLeading
        )
        .overlay(
            // カメラボタン
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
        .fullScreenCover(isPresented: $viewModel.showPhotoDetail) {
            if let capturedImage = viewModel.capturedImage {
                PhotoDetailView(image: capturedImage)
            }
        }
        .sheet(isPresented: $showAudioSettings) {
            AudioSettingsView(
                volume: $viewModel.spatialAudioVolume,
                isEnabled: $viewModel.spatialAudioEnabled
            )
        }
        .alert("3D空間オーディオ", isPresented: $showAirPodsAlert) {
            Button("了解") {
                viewModel.toggleSpatialAudio()
            }
        } message: {
            Text("AirPodsまたはAirPods Proを装着すると、ヘッドトラッキングによる高度な空間オーディオが有効になります。ステレオイヤホンでも基本的な空間オーディオ機能は利用できます。")
        }
    }
    
    // コントロールボタンを生成する補助関数
    private func controlButton(icon: String, iconColor: Color = .white, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .frame(width: 40, height: 40)
                .background(Color.black.opacity(0.5))
                .foregroundColor(iconColor)
                .clipShape(Circle())
        }
    }
}

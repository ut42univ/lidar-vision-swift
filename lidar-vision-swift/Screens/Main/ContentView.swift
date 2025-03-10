import SwiftUI

/// メイン画面
struct ContentView: View {
    @StateObject var viewModel = ContentViewModel()
    @StateObject var orientationHelper = OrientationHelper()
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
                // 設定ボタン
                controlButton(
                    icon: "gear",
                    action: { viewModel.showSettings = true }
                )
                
                // 空間オーディオ切り替えボタン
                controlButton(
                    icon: viewModel.isSpatialAudioEnabled ? "airpodsmax" : "headphones",
                    iconColor: viewModel.isSpatialAudioEnabled ? .green : .white,
                    action: {
                        if !viewModel.isSpatialAudioEnabled {
                            viewModel.sessionService.recheckAirPodsConnection()
                            showAirPodsAlert = true
                        } else {
                            viewModel.toggleSpatialAudio()
                        }
                    }
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
            // カメラボタン（長押し対応）
            VStack {
                Spacer()
                HStack {
                    // 長押しジェスチャーを追加
                    cameraButton
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
        .sheet(isPresented: $viewModel.showSettings) {
            AppSettingsView(
                settings: viewModel.appSettings,
                onSettingsChanged: { newSettings in
                    viewModel.updateSettings(newSettings)
                }
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
    
    // カメラボタン（長押し対応）
    private var cameraButton: some View {
        Image(systemName: "camera")
            .font(.system(size: 24))
            .frame(width: 60, height: 60)
            .padding()
            .background(Color.black.opacity(0.5))
            .foregroundColor(.white)
            .clipShape(Circle())
            .gesture(
                LongPressGesture(minimumDuration: 0.5)
                    .onEnded { _ in
                        // 触覚フィードバック
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        // 写真撮影と自動分析
                        viewModel.captureAndAnalyzePhoto()
                    }
            )
            .overlay(
                Circle()
                    .stroke(Color.white, lineWidth: 2)
                    .padding(4)
            )
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

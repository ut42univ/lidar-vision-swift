import SwiftUI

/// メイン画面 - リファクタリング版
struct ContentView: View {
    @StateObject var viewModel = ContentViewModel()
    @StateObject var orientationHelper = OrientationHelper()
    @State private var showAirPodsAlert = false
    
    var body: some View {
        ZStack {
            // ARView
            ARViewContainer(sessionService: viewModel.sessionService)
                .ignoresSafeArea()
            
            // UI要素を重ねる
            VStack {
                // 上部コントローラー
                HeaderControls()
                
                Spacer()
                
                // 距離表示
                DistanceDisplay(depth: viewModel.sessionService.centerDepth)
            }
        }
        // 中央の十字マーカーをオーバーレイ
        .overlay(
            CrossMarker(color: viewModel.alertColor),
            alignment: .center
        )
        // カメラボタンをオーバーレイ
        .overlay(
            CameraButtonView(),
            alignment: .bottomLeading
        )
        // 画面遷移設定
        .presentationModifiers()
        // アラート設定
        .alert("3D Spatial Audio", isPresented: $showAirPodsAlert) {
            Button("OK") {
                viewModel.toggleSpatialAudio()
            }
        } message: {
            Text("Advanced spatial audio with head tracking is available when using AirPods or AirPods Pro. Basic spatial audio is available with any stereo headphones.")
        }
        // ライフサイクル設定
        .onAppear {
            viewModel.resumeARSession()
        }
        .onDisappear {
            viewModel.pauseARSession()
        }
        // 環境設定
        .environmentObject(viewModel)
    }
    
    // MARK: - サブビュー
    
    // 上部コントロールボタンエリア
    private struct HeaderControls: View {
        @EnvironmentObject var viewModel: ContentViewModel
        @State private var showAirPodsAlert = false
        
        var body: some View {
            HStack(spacing: 10) {
                // 設定ボタン
                ControlButton(icon: "gear") {
                    // 設定画面を表示する前に必ずARセッションを一時停止
                    viewModel.pauseARSession()
                    viewModel.showSettings = true
                }
                
                // 空間オーディオ切り替えボタン
                ControlButton(
                    icon: viewModel.isSpatialAudioEnabled ? "airpodsmax" : "headphones",
                    iconColor: viewModel.isSpatialAudioEnabled ? .green : .white
                ) {
                    if !viewModel.isSpatialAudioEnabled {
                        showAirPodsAlert = true
                    } else {
                        viewModel.toggleSpatialAudio()
                    }
                }
                
                // メッシュ可視性切り替えボタン
                ControlButton(
                    icon: viewModel.isMeshVisible ? "grid.circle.fill" : "grid.circle"
                ) {
                    viewModel.toggleMeshVisibility()
                }
                
                // メッシュリセットボタン
                ControlButton(icon: "arrow.triangle.2.circlepath") {
                    viewModel.resetMeshCache()
                }
            }
            .padding()
        }
    }
    
    // 深度表示コンポーネント
    private struct DistanceDisplay: View {
        let depth: Float
        
        var body: some View {
            Text(String(format: "Distance: %.2f m", depth))
                .padding()
                .background(Color.black.opacity(0.5))
                .foregroundColor(.white)
                .cornerRadius(8)
                .padding(.bottom, 20)
        }
    }
    
    // カメラボタンコンポーネント
    private struct CameraButtonView: View {
        @EnvironmentObject var viewModel: ContentViewModel
        
        var body: some View {
            VStack {
                Spacer()
                HStack {
                    cameraButton
                    Spacer()
                }
                .padding()
            }
        }
        
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
                            
                            // ARセッションを一時停止してから写真を撮影
                            viewModel.pauseARSession()
                            
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
    }
    
    // コントロールボタンコンポーネント
    private struct ControlButton: View {
        let icon: String
        var iconColor: Color = .white
        let action: () -> Void
        
        var body: some View {
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
}

// MARK: - View拡張

extension View {
    /// 画面遷移モディファイアをまとめる
    func presentationModifiers() -> some View {
        self
            .withPhotoDetailCover()
            .withSettingsSheet()
    }
    
    /// PhotoDetailのカバー表示を設定
    private func withPhotoDetailCover() -> some View {
        self.modifier(PhotoDetailModifier())
    }
    
    /// Settingsのシート表示を設定
    private func withSettingsSheet() -> some View {
        self.modifier(SettingsSheetModifier())
    }
}

// PhotoDetail表示モディファイア
struct PhotoDetailModifier: ViewModifier {
    @EnvironmentObject var viewModel: ContentViewModel
    
    func body(content: Content) -> some View {
        content
            .fullScreenCover(isPresented: $viewModel.showPhotoDetail, onDismiss: {
                // 詳細画面を閉じたらARセッションを再開
                viewModel.resumeARSession()
            }) {
                if let capturedImage = viewModel.capturedImage {
                    PhotoDetailView(image: capturedImage)
                        .onAppear {
                            print("PhotoDetailView appeared")
                        }
                }
            }
    }
}

// Settings表示モディファイア
struct SettingsSheetModifier: ViewModifier {
    @EnvironmentObject var viewModel: ContentViewModel
    
    func body(content: Content) -> some View {
        content
            .sheet(isPresented: $viewModel.showSettings, onDismiss: {
                // 設定画面を閉じたらARセッションを再開
                print("Settings dismissed")
                DispatchQueue.main.async {
                    viewModel.resumeARSession()
                }
            }) {
                AppSettingsView(
                    settings: viewModel.appSettings,
                    onSettingsChanged: { newSettings in
                        viewModel.updateSettings(newSettings)
                    }
                )
                .onAppear {
                    print("AppSettingsView appeared")
                }
            }
    }
}

#Preview {
    ContentView()
}

import SwiftUI
import AudioToolbox

struct ContentView: View {
    @StateObject var viewModel = ContentViewModel()
    @StateObject var orientationManager = OrientationManager()
    @State private var showAudioSettings = false
    @State private var showAirPodsAlert = false
    
    var body: some View {
        ZStack {
            ARViewContainer(sessionManager: viewModel.sessionManager)
                .ignoresSafeArea()
            
            VStack {
                Spacer()
                Text(String(format: "距離: %.2f m", viewModel.sessionManager.centerDepth))
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
                
                // Spatial audio toggle button with AirPods icon
                Button(action: {
                    // 先に AirPods チェックを実行し、アラートを表示
                    if !viewModel.spatialAudioEnabled {
                        viewModel.sessionManager.recheckAirPodsConnection()
                        showAirPodsAlert = true
                    } else {
                        // 既に有効な場合は単純に無効化
                        viewModel.toggleSpatialAudio()
                    }
                }) {
                    Image(systemName: viewModel.spatialAudioEnabled ? "airpodsmax" : "headphones")
                        .font(.system(size: 20))
                        .frame(width: 40, height: 40)
                        .background(Color.black.opacity(0.5))
                        .foregroundColor(viewModel.spatialAudioEnabled ? .green : .white)
                        .clipShape(Circle())
                }
                
                // Spatial audio settings button
                Button(action: {
                    showAudioSettings.toggle()
                }) {
                    Image(systemName: "slider.horizontal.3")
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
        .sheet(isPresented: $showAudioSettings) {
            EnhancedAudioSettingsView(
                volume: $viewModel.spatialAudioVolume,
                isEnabled: $viewModel.spatialAudioEnabled
            )
        }
        .alert("3D空間オーディオ", isPresented: $showAirPodsAlert) {
            Button("了解") {
                // アラートを閉じた後に空間オーディオを有効化
                viewModel.toggleSpatialAudio()
            }
        } message: {
            Text("AirPodsまたはAirPods Proを装着すると、ヘッドトラッキングによる高度な空間オーディオが有効になります。ステレオイヤホンでも基本的な空間オーディオ機能は利用できます。")
        }
    }
}

struct EnhancedAudioSettingsView: View {
    @Binding var volume: Float
    @Binding var isEnabled: Bool
    @Environment(\.dismiss) private var dismiss
    @State private var showHeadphoneInfo = false
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("空間オーディオ")) {
                    Toggle("空間オーディオを有効化", isOn: $isEnabled)
                        .tint(.blue)
                    
                    VStack(alignment: .leading) {
                        Text("音量: \(Int(volume * 100))%")
                        Slider(value: $volume, in: 0...1, step: 0.05)
                            .tint(.blue)
                    }
                    .padding(.vertical, 8)
                    
                    Button(action: {
                        showHeadphoneInfo = true
                    }) {
                        HStack {
                            Image(systemName: "airpodsmax")
                                .foregroundColor(.blue)
                            Text("AirPodsについて")
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    }
                    
                    HStack {
                        Text("状態:")
                        Spacer()
                        Text(isEnabled ? "有効" : "無効")
                            .foregroundColor(isEnabled ? .green : .secondary)
                    }
                }
                
                Section(header: Text("使い方"), footer: Text("最適な体験のために、AirPods ProまたはAirPods Maxの使用をお勧めします。")) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("空間オーディオの仕組み")
                            .font(.headline)
                        
                        Text("障害物に近づくと、その方向から音が聞こえます。AirPods Proを使用すると、ヘッドの動きに合わせて音の方向が調整されます。")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)
                    
                    VStack(alignment: .leading, spacing: 10) {
                        Text("音の意味")
                            .font(.headline)
                        
                        Text("・高音（近い）: 0.5m以内の障害物\n・中音（警告）: 0.5m～2m以内の障害物\n・低音（遠い）: 2m～5m以内の障害物")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle("オーディオ設定")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完了") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showHeadphoneInfo) {
                AirPodsInfoView()
            }
        }
        .presentationDetents([.medium, .large])
    }
}

struct AirPodsInfoView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Image(systemName: "airpodsmax")
                    .font(.system(size: 80))
                    .foregroundColor(.blue)
                    .padding(.top, 40)
                
                Text("AirPods Proでの拡張機能")
                    .font(.title2)
                    .fontWeight(.bold)
                
                VStack(alignment: .leading, spacing: 16) {
                    FeatureRow(
                        icon: "person.wave.2.fill",
                        title: "ヘッドトラッキング",
                        description: "頭の動きを検出し、それに合わせて音源の位置を調整します。"
                    )
                    
                    FeatureRow(
                        icon: "ear.and.waveform",
                        title: "ダイナミックヘッドトラッキング",
                        description: "AirPods Proが頭の動きを検出し、音の方向を現実世界に固定します。"
                    )
                    
                    FeatureRow(
                        icon: "speaker.wave.3.fill",
                        title: "没入型オーディオ",
                        description: "周囲の障害物からの音が、より正確な方向から聞こえるようになります。"
                    )
                }
                .padding(.horizontal, 30)
                
                Spacer()
                
                Text("AirPods ProまたはAirPods Maxを接続すると、これらの機能が自動的に有効になります。")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                    .padding(.bottom, 20)
            }
            .navigationTitle("AirPods 拡張機能")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("閉じる") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct FeatureRow: View {
    var icon: String
    var title: String
    var description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 26))
                .foregroundColor(.blue)
                .frame(width: 36, height: 36)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

#Preview {
    ContentView()
}

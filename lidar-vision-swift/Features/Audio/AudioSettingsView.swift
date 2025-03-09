import SwiftUI

/// オーディオ設定画面
struct AudioSettingsView: View {
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
                
                // 使い方セクション
                Section(header: Text("使い方"), footer: Text("最適な体験のために、AirPods ProまたはAirPods Maxの使用をお勧めします。")) {
                    // 使い方の説明内容
                    helpContentView
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
    
    // 使い方の説明を分離
    private var helpContentView: some View {
        VStack(spacing: 16) {
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
}

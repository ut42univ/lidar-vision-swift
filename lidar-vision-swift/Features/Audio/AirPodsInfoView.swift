import SwiftUI

/// AirPodsの拡張機能に関する情報を表示するビュー
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

/// 機能説明の行コンポーネント
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


import SwiftUI

/// 洗練された近接警告表示コンポーネント - メインビューのデザインシステムと統一
struct ProximityWarningView: View {
    // アニメーション用の状態変数
    @State private var pulseScale: CGFloat = 0.95
    @State private var pulseOpacity: Double = 0.0
    @State private var ringScale: CGFloat = 0.8
    @State private var ringOpacity: Double = 0.0
    @State private var iconOpacity: Double = 0.0
    @State private var textOpacity: Double = 0.0
    
    // 距離情報
    var distance: Float
    
    // デザイン定数
    private enum Design {
        static let containerSize: CGFloat = 240
        static let cornerRadius: CGFloat = 24
        static let backgroundMaterial: Material = .ultraThinMaterial
    }
    
    var body: some View {
        ZStack {
            // 背景ブラー（視認性を確保しながら洗練された印象に）
            backgroundBlur
            
            // 警告コンテンツ
            warningContent
        }
        .accessibilityLabel("警告：障害物が非常に近いです")
        .onAppear {
            // 連続したアニメーションシーケンスを開始
            withAnimation(.easeIn(duration: 0.2)) {
                iconOpacity = 1.0
                textOpacity = 1.0
            }
            
            startPulseAnimation()
            startRingAnimation()
        }
    }
    
    // 背景ブラー - ContentViewのマテリアルスタイルに完全に合わせる
    private var backgroundBlur: some View {
        RoundedRectangle(cornerRadius: Design.cornerRadius)
            .fill(Color.clear)
            .frame(width: Design.containerSize, height: Design.containerSize)
            .background(Design.backgroundMaterial)
            .clipShape(RoundedRectangle(cornerRadius: Design.cornerRadius))
    }
    
    // 警告コンテンツ
    private var warningContent: some View {
        VStack(spacing: 24) {
            // アイコンとパルスリング
            ZStack {
                // 外側のパルスリング
                Circle()
                    .stroke(Color.red.opacity(0.2), lineWidth: 2)
                    .frame(width: 70, height: 70)
                    .scaleEffect(ringScale)
                    .opacity(ringOpacity)
                
                // 内側のパルス円
                Circle()
                    .fill(.red)
                    .frame(width: 80, height: 80)
                    .scaleEffect(pulseScale)
                    .opacity(pulseOpacity)
                
                // 警告アイコン
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 40, weight: .medium))
                    .foregroundColor(.white)
                    .opacity(iconOpacity)
            }
            
            // 距離テキスト
            Text("Too Close")
                .font(.headline)
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(.red.opacity(0.8))
                )
                .opacity(textOpacity)
        }
    }
    
    // パルスアニメーションの開始
    private func startPulseAnimation() {
        // 初期状態を設定
        pulseScale = 0.9
        pulseOpacity = 0.7
        
        // メインのパルスアニメーション
        withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
            pulseScale = 1.1
            pulseOpacity = 0.9
        }
    }
    
    // リングアニメーションの開始
    private func startRingAnimation() {
        // 初期状態を設定
        ringScale = 0.9
        ringOpacity = 0.4
        
        // リングのパルスアニメーション（外側に拡大）
        withAnimation(.easeOut(duration: 1.8).repeatForever(autoreverses: false)) {
            ringScale = 1.5
            ringOpacity = 0
        }
        
        // 少し遅延して2つ目のアニメーションを開始（連続した波のように見せる）
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
            withAnimation(.easeOut(duration: 1.8).repeatForever(autoreverses: false)) {
                // 2つ目は少し早く動かす
                ringScale = 1.7
                ringOpacity = 0
            }
        }
    }
}

// プレビュー
#Preview {
    ZStack {
        Color.gray.opacity(0.3).edgesIgnoringSafeArea(.all)
        ProximityWarningView(distance: 0.18)
    }
}

import SwiftUI

/// 洗練された近接警告表示コンポーネント - Appleデザイン言語に準拠
struct ProximityWarningView: View {
    // 距離情報
    var distance: Float
    
    // デザイン定数
    private enum Design {
        static let containerSize: CGFloat = 240
        static let cornerRadius: CGFloat = 24
        static let backgroundMaterial: Material = .ultraThinMaterial
        static let warningRed = Color(red: 0.97, green: 0.26, blue: 0.24)
    }
    
    var body: some View {
        TimelineView(.animation) { timeline in
            // 現在の時間に基づいてアニメーション状態を計算
            let time = timeline.date.timeIntervalSinceReferenceDate
            
            // 中心円のパルス（0.6秒周期でアニメーション）
            let pulseValue = sin(time * 5.0) * 0.5 + 0.5 // 0.0-1.0の範囲で変化
            let pulseScale = 1.0 + (pulseValue * 0.08) // 1.0-1.08の範囲で変化
            let pulseOpacity = 0.4 + (pulseValue * 0.3) // 0.4-0.7の範囲で変化
            
            // 外側のリングのアニメーション計算（1.8秒周期）
            let ringPhase1 = (time.truncatingRemainder(dividingBy: 1.8)) / 1.8
            let ringScale1 = 1.0 + (ringPhase1 * 0.4) // 1.0-1.4の範囲で変化
            let ringOpacity1 = max(0, 0.7 - (ringPhase1 * 0.7)) // 0.7-0.0の範囲で変化
            
            // 2つ目のリングのアニメーション計算（1.8秒周期、0.9秒遅延）
            let ringPhase2 = ((time + 0.9).truncatingRemainder(dividingBy: 1.8)) / 1.8
            let ringScale2 = 1.0 + (ringPhase2 * 0.4) // 1.0-1.4の範囲で変化
            let ringOpacity2 = max(0, 0.7 - (ringPhase2 * 0.7)) // 0.7-0.0の範囲で変化
        
            ZStack {
                // 背景ブラー
                RoundedRectangle(cornerRadius: Design.cornerRadius)
                    .fill(Color.black.opacity(0.05))
                    .frame(width: Design.containerSize, height: Design.containerSize)
                    .background(Design.backgroundMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: Design.cornerRadius))
                
                // 警告コンテンツ
                VStack(spacing: 40) {
                    // アイコンと警告リング
                    ZStack {
                        // 1つ目のリングアニメーション
                        Circle()
                            .stroke(Design.warningRed.opacity(ringOpacity1), lineWidth: 2)
                            .frame(width: 90, height: 90)
                            .scaleEffect(ringScale1)
                        
                        // 2つ目のリングアニメーション
                        Circle()
                            .stroke(Design.warningRed.opacity(ringOpacity2), lineWidth: 2)
                            .frame(width: 90, height: 90)
                            .scaleEffect(ringScale2)
                        
                        // 警告アイコンの背景円
                        Circle()
                            .fill(Design.warningRed.opacity(pulseOpacity))
                            .frame(width: 80, height: 80)
                            .scaleEffect(pulseScale)
                        
                        // 警告アイコン
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 36, weight: .medium))
                            .foregroundColor(.white)
                    }
                    .padding(.top, 10)
                    
                    // 警告テキスト - シンプルなテキストのみ
                    VStack(spacing: 8) {
                        Text("Proximity Alert")
                            .font(.system(size: 19, weight: .semibold))
                            .foregroundColor(.white)
                        
                        Text("Object is too close")
                            .font(.system(size: 16, weight: .regular))
                            .foregroundColor(.white.opacity(0.9))
                    }
                    .padding(.bottom, 10)
                }
                .frame(width: Design.containerSize)
            }
            .accessibilityLabel("警告：障害物が近接しています")
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

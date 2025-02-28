//
//  ContentView.swift
//  lidar-vision-swift
//
//  Created by Takuya Uehara on 2025/02/28.
//

import SwiftUI
import AudioToolbox

struct ContentView: View {
    @StateObject var depthData = DepthData()
    @StateObject var feedbackManager = FeedbackManager()
    
    // 警告レベルの閾値
    let warningThreshold: Float = 1.0
    let criticalThreshold: Float = 0.5
    // サウンドの有効／無効を管理するフラグ
    @State private var soundEnabled: Bool = true
    
    var alertColor: Color {
        if depthData.centerDepth < criticalThreshold {
            return .red
        } else if depthData.centerDepth < warningThreshold {
            return .yellow
        } else {
            return .white
        }
    }
    
    var overlayColor: Color? {
        if depthData.centerDepth < criticalThreshold {
            return Color.red.opacity(0.2)
        } else if depthData.centerDepth < warningThreshold {
            return Color.yellow.opacity(0.2)
        } else {
            return nil
        }
    }
    
    var body: some View {
        ZStack {
            ARViewContainer(depthData: depthData)
                .edgesIgnoringSafeArea(.all)
            
            // pip形式でDepth Mapを右上に表示
            if let depthImage = depthData.depthOverlayImage {
                Image(uiImage: depthImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .rotationEffect(Angle(degrees: 90)) // 時計回りに90°回転（必要に応じて調整）
                    .frame(width: 150, height: 150)
                    .cornerRadius(4)
                    .padding(4)
                    .background(Color.black.opacity(0.7))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .padding()
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
            }
            
            // 下部に深度値表示
            VStack {
                Spacer()
                Text(String(format: "距離: %.2f m", depthData.centerDepth))
                    .padding()
                    .background(Color.black.opacity(0.5))
                    .foregroundColor(.white)
                    .cornerRadius(8)
                    .padding(.bottom, 20)
            }
            
            // 警告用オーバーレイ（必要に応じて）
            if let overlayColor = overlayColor {
                overlayColor
                    .edgesIgnoringSafeArea(.all)
                    .transition(.opacity)
            }
        }
        // 画面中央にクロスマーカーを配置
        .overlay(
            CrossMarker(color: alertColor)
                .frame(width: 40, height: 40),
            alignment: .center
        )
        // サウンド切替ボタンを左上に配置
        .overlay(
            Button(action: { soundEnabled.toggle() }) {
                Image(systemName: soundEnabled ? "speaker.wave.2.fill" : "speaker.slash.fill")
                    .font(.system(size: 24))
                    .padding()
                    .background(Color.black.opacity(0.5))
                    .foregroundColor(.white)
                    .clipShape(Circle())
            }
            .padding(),
            alignment: .topLeading
        )
        .onChange(of: depthData.centerDepth) { newDepth, _ in
            if newDepth < criticalThreshold {
                feedbackManager.stopWarningHapticFeedback()
                feedbackManager.startCriticalHapticFeedback()
                feedbackManager.stopWarningSound()
                if soundEnabled {
                    feedbackManager.startCriticalSound()
                } else {
                    feedbackManager.stopCriticalSound()
                }
            } else if newDepth < warningThreshold {
                feedbackManager.stopCriticalHapticFeedback()
                feedbackManager.startWarningHapticFeedback()
                feedbackManager.stopCriticalSound()
                if soundEnabled {
                    feedbackManager.startWarningSound()
                } else {
                    feedbackManager.stopWarningSound()
                }
            } else {
                feedbackManager.stopAll()
            }
        }
        .onDisappear {
            feedbackManager.stopAll()
        }
    }
}

#Preview {
    ContentView()
}

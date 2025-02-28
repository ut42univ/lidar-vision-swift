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
    
    // 警告レベルの閾値（単位：メートル）
    let warningThreshold: Float = 1.0
    let criticalThreshold: Float = 0.5
    
    // サウンドの有効／無効を管理するフラグ（ボタンで切替）
    @State private var soundEnabled: Bool = true
    
    // 現在の警告レベルに応じたクロスマーカーの色
    var alertColor: Color {
        if depthData.centerDepth < criticalThreshold {
            return .red
        } else if depthData.centerDepth < warningThreshold {
            return .yellow
        } else {
            return .white
        }
    }
    
    // オーバーレイの色（警告レベルに応じた半透明色）
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
            
            // 警告用オーバーレイ
            if let overlayColor = overlayColor {
                overlayColor
                    .edgesIgnoringSafeArea(.all)
                    .transition(.opacity)
            }
            
            VStack {
                HStack {
                    Spacer()
                    // サウンド切替ボタン
                    Button(action: {
                        soundEnabled.toggle()
                    }) {
                        Image(systemName: soundEnabled ? "speaker.wave.2.fill" : "speaker.slash.fill")
                            .font(.system(size: 24))
                            .padding()
                            .background(Color.black.opacity(0.5))
                            .foregroundColor(.white)
                            .clipShape(Circle())
                    }
                    .padding()
                }
                Spacer()
                Text(String(format: "距離: %.2f m", depthData.centerDepth))
                    .padding()
                    .background(Color.black.opacity(0.5))
                    .foregroundColor(.white)
                    .cornerRadius(8)
                    .padding(.bottom, 20)
            }
        }
        // 画面中央にクロスマーカーをoverlayで配置
        .overlay(
            CrossMarker(color: alertColor)
                .frame(width: 40, height: 40),
            alignment: .center
        )
        // 深度変化に応じたフィードバックの開始／停止（iOS 17仕様のonChange）
        .onChange(of: depthData.centerDepth) { newDepth, _ in
            if newDepth < criticalThreshold {
                // 警告レベル2：Critical
                feedbackManager.stopWarningHapticFeedback()
                feedbackManager.startCriticalHapticFeedback()
                feedbackManager.stopWarningSound()
                if soundEnabled {
                    feedbackManager.startCriticalSound()
                } else {
                    feedbackManager.stopCriticalSound()
                }
            } else if newDepth < warningThreshold {
                // 警告レベル1：Warning
                feedbackManager.stopCriticalHapticFeedback()
                feedbackManager.startWarningHapticFeedback()
                feedbackManager.stopCriticalSound()
                if soundEnabled {
                    feedbackManager.startWarningSound()
                } else {
                    feedbackManager.stopWarningSound()
                }
            } else {
                // 安全域：すべて停止
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

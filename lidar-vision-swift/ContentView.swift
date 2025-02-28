//
//  ContentView.swift
//  lidar-vision-swift
//
//  Created by Takuya Uehara on 2025/02/28.
//

import SwiftUI
import AudioToolbox

// ContentView：AR映像、クロスマーカー、警告オーバーレイ、連続的な触覚・音声フィードバック、サウンド切替ボタンを実装
struct ContentView: View {
    @StateObject var depthData = DepthData()
    // 閾値（単位：メートル）
    let threshold: Float = 0.5
    // 触覚フィードバック用タイマー
    @State private var hapticTimer: Timer? = nil
    // 音声フィードバック用タイマー
    @State private var soundTimer: Timer? = nil
    // サウンドの有効／無効を管理するフラグ（ボタンで切替）
    @State private var soundEnabled: Bool = true

    var body: some View {
        ZStack {
            ARViewContainer(depthData: depthData)
                .edgesIgnoringSafeArea(.all)
            
            // 警告用の赤いオーバーレイ
            if depthData.centerDepth < threshold {
                Color.red.opacity(0.2)
                    .edgesIgnoringSafeArea(.all)
                    .transition(.opacity)
            }
            
            VStack {
                HStack {
                    Spacer()
                    // サウンドのオン／オフ切替ボタン
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
        // 中央にクロスマーカーを配置
        .overlay(
            CrossMarker(isTooClose: depthData.centerDepth < threshold)
                .frame(width: 40, height: 40),
            alignment: .center
        )
        // iOS 17仕様の onChange（新しい値とTransactionの2パラメータ版）
        .onChange(of: depthData.centerDepth) { newDepth, _ in
            if newDepth < threshold {
                startHapticTimer()
                if soundEnabled {
                    startSoundTimer()
                } else {
                    stopSoundTimer()
                }
            } else {
                stopHapticTimer()
                stopSoundTimer()
            }
        }
        .onDisappear {
            stopHapticTimer()
            stopSoundTimer()
        }
    }
    
    // 触覚フィードバックタイマーの開始
    func startHapticTimer() {
        if hapticTimer == nil {
            hapticTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
                let generator = UIImpactFeedbackGenerator(style: .heavy)
                generator.impactOccurred()
            }
        }
    }
    
    // 触覚フィードバックタイマーの停止
    func stopHapticTimer() {
        hapticTimer?.invalidate()
        hapticTimer = nil
    }
    
    // 音声フィードバックタイマーの開始（システムサウンドでビープ音）
    func startSoundTimer() {
        if soundTimer == nil {
            soundTimer = Timer.scheduledTimer(withTimeInterval: 0.4, repeats: true) { _ in
                // ここではシステムサウンドID 1255（例: 軽いビープ音）を再生
                AudioServicesPlaySystemSound(SystemSoundID(1255))
            }
        }
    }
    
    // 音声フィードバックタイマーの停止
    func stopSoundTimer() {
        soundTimer?.invalidate()
        soundTimer = nil
    }
}



#Preview {
    ContentView()
}

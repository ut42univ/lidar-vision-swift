//
//  FeedbackManager.swift
//  lidar-vision-swift
//
//  Created by Takuya Uehara on 2025/02/28.
//

import AudioToolbox
import UIKit

final class FeedbackManager: ObservableObject {
    // 警告レベル1用触覚タイマー（例：0.3秒間隔、mediumスタイル）
    private var hapticWarningTimer: Timer?
    // 警告レベル2用触覚タイマー（例：0.1秒間隔、heavyスタイル）
    private var hapticCriticalTimer: Timer?
    
    private var warningSoundTimer: Timer?
    private var criticalSoundTimer: Timer?
    
    // 警告レベル1用触覚フィードバック
    func startWarningHapticFeedback() {
        if hapticWarningTimer == nil {
            hapticWarningTimer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: true) { _ in
                let generator = UIImpactFeedbackGenerator(style: .medium)
                generator.impactOccurred()
            }
        }
    }
    
    func stopWarningHapticFeedback() {
        hapticWarningTimer?.invalidate()
        hapticWarningTimer = nil
    }
    
    // 警告レベル2用触覚フィードバック：より速い間隔、より強い振動
    func startCriticalHapticFeedback() {
        if hapticCriticalTimer == nil {
            hapticCriticalTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
                let generator = UIImpactFeedbackGenerator(style: .heavy)
                generator.impactOccurred()
            }
        }
    }
    
    func stopCriticalHapticFeedback() {
        hapticCriticalTimer?.invalidate()
        hapticCriticalTimer = nil
    }
    
    // 警告レベル1用サウンド（例：SystemSoundID 1006）を開始
    func startWarningSound() {
        if warningSoundTimer == nil {
            warningSoundTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
                AudioServicesPlaySystemSound(SystemSoundID(1255))
            }
        }
    }
    
    func stopWarningSound() {
        warningSoundTimer?.invalidate()
        warningSoundTimer = nil
    }
    
    // 警告レベル2用サウンド（例：SystemSoundID 1005）を開始
    func startCriticalSound() {
        if criticalSoundTimer == nil {
            criticalSoundTimer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: true) { _ in
                AudioServicesPlaySystemSound(SystemSoundID(1256))
            }
        }
    }
    
    func stopCriticalSound() {
        criticalSoundTimer?.invalidate()
        criticalSoundTimer = nil
    }
    
    // すべてのフィードバック停止
    func stopAll() {
        stopWarningHapticFeedback()
        stopCriticalHapticFeedback()
        stopWarningSound()
        stopCriticalSound()
    }
}


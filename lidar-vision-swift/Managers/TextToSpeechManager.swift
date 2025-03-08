//
//  TextToSpeechManager.swift
//  lidar-vision-swift
//
//  Created by Takuya Uehara on 2025/03/08.
//


import AVFoundation
import Combine
import Foundation

final class TextToSpeechManager: ObservableObject {
    private let synthesizer = AVSpeechSynthesizer()
    
    @Published var isPlaying: Bool = false
    @Published var rate: Float = 0.5 // 読み上げ速度 (0.0 - 1.0)
    @Published var pitch: Float = 1.0 // 音の高さ (0.5 - 2.0)
    @Published var volume: Float = 0.8 // 音量 (0.0 - 1.0)
    @Published var language: String = "en-US"
    
    init() {
        synthesizer.delegate = nil
    }
    
    // テキストを読み上げる
    func speak(text: String) {
        // すでに読み上げ中の場合は停止
        if isPlaying {
            stopSpeaking()
        }
        
        // 音声発話の設定
        let utterance = AVSpeechUtterance(string: text)
        utterance.rate = rate
        utterance.pitchMultiplier = pitch
        utterance.volume = volume
        utterance.voice = AVSpeechSynthesisVoice(language: language)
        
        // 読み上げ開始
        synthesizer.speak(utterance)
        isPlaying = true
    }
    
    // 読み上げを停止
    func stopSpeaking() {
        synthesizer.stopSpeaking(at: .immediate)
        isPlaying = false
    }
    
    // 言語を変更
    func setLanguage(to languageCode: String) {
        language = languageCode
    }
    
    // 自動言語検出して読み上げ
    func speakWithAutoLanguageDetection(text: String) {
        // テキストが英語っぽいかどうか簡易判定
        let englishPattern = "^[A-Za-z0-9\\s.,!?;:'\"()-]+$"
        if let regex = try? NSRegularExpression(pattern: englishPattern) {
            let range = NSRange(location: 0, length: text.utf16.count)
            if regex.firstMatch(in: text, options: [], range: range) != nil {
                // 英語のテキストっぽい場合
                language = "en-US"
            } else {
                // それ以外は日本語と仮定
                language = "ja-JP"
            }
        }
        
        speak(text: text)
    }
    
    deinit {
        stopSpeaking()
    }
}

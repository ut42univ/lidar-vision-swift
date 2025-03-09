import AVFoundation
import Combine
import Foundation

/// シンプル化されたテキスト読み上げサービス（英語のみ）
final class TextToSpeechService: NSObject, ObservableObject, @unchecked Sendable {
    private let synthesizer = AVSpeechSynthesizer()
    
    @Published var isPlaying: Bool = false
    @Published var currentText: String = "" // 現在読み上げ中のテキスト
    
    // 固定設定
    private let rate: Float = 0.5 // 読み上げ速度
    private let pitch: Float = 1.0 // 音の高さ
    private let volume: Float = 0.8 // 音量
    
    override init() {
        super.init()
        synthesizer.delegate = self
    }
    
    /// テキストを読み上げる
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
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        
        // 現在のテキストを保存
        currentText = text
        
        // 読み上げ開始
        synthesizer.speak(utterance)
        isPlaying = true
    }
    
    /// 読み上げを停止
    func stopSpeaking() {
        synthesizer.stopSpeaking(at: .immediate)
        isPlaying = false
    }
    
    deinit {
        stopSpeaking()
    }
}

// MARK: - AVSpeechSynthesizerDelegate
extension TextToSpeechService: AVSpeechSynthesizerDelegate {
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        DispatchQueue.main.async {
            self.isPlaying = false
        }
    }
    
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        DispatchQueue.main.async {
            self.isPlaying = false
        }
    }
}

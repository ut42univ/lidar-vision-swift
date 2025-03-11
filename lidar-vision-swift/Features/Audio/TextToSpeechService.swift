import AVFoundation
import Combine
import Foundation

/// テキスト読み上げサービス - 効率化＆簡素化バージョン
final class TextToSpeechService: NSObject, ObservableObject {
    // 公開プロパティ
    @Published var isPlaying: Bool = false
    @Published var currentText: String = ""
    
    // 設定プロパティ
    private var rate: Float
    private var pitch: Float
    private var volume: Float
    private var language: String
    
    // 内部実装
    private let synthesizer: AVSpeechSynthesizer
    
    init(rate: Float = 0.5, pitch: Float = 1.0, volume: Float = 0.8, language: String = "en-US") {
        self.rate = rate
        self.pitch = pitch
        self.volume = volume
        self.language = language
        self.synthesizer = AVSpeechSynthesizer()
        
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
        let utterance = createUtterance(for: text)
        
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
    
    /// 設定を更新
    func updateSettings(rate: Float? = nil, pitch: Float? = nil, volume: Float? = nil, language: String? = nil) {
        // 指定された値のみ更新
        if let newRate = rate {
            self.rate = newRate
        }
        
        if let newPitch = pitch {
            self.pitch = newPitch
        }
        
        if let newVolume = volume {
            self.volume = newVolume
        }
        
        if let newLanguage = language {
            self.language = newLanguage
        }
        
        // 再生中の場合は更新した設定で再開
        if isPlaying, let text = currentText.nilIfEmpty {
            let wasPlaying = isPlaying
            stopSpeaking()
            
            if wasPlaying {
                speak(text: text)
            }
        }
    }
    
    // AVSpeechUtteranceの作成
    private func createUtterance(for text: String) -> AVSpeechUtterance {
        let utterance = AVSpeechUtterance(string: text)
        
        // 設定を適用
        utterance.rate = rate
        utterance.pitchMultiplier = pitch
        utterance.volume = volume
        
        // 適切な音声の選択
        utterance.voice = AVSpeechSynthesisVoice(language: language)
        
        return utterance
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

// 便利な拡張
extension String {
    var nilIfEmpty: String? {
        return self.isEmpty ? nil : self
    }
}

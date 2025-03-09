import Foundation

/// アプリケーション全体のオーディオ設定を管理するモデル
struct AudioSettings {
    // 空間オーディオ設定
    struct SpatialAudio {
        var isEnabled: Bool = false
        var volume: Float = 0.8
        var maxDistance: Float = 5.0 // 最大検出距離（メートル）
        var nearThreshold: Float = 0.5 // 近い障害物の閾値
        var mediumThreshold: Float = 2.0 // 中間距離の閾値
    }
    
    // テキスト読み上げ設定
    struct TextToSpeech {
        var rate: Float = 0.5 // 読み上げ速度 (0.0 - 1.0)
        var pitch: Float = 1.0 // 音の高さ (0.5 - 2.0)
        var volume: Float = 0.8 // 音量 (0.0 - 1.0)
        var language: String = "en-US" // デフォルト言語
        
        // サポートされている言語
        static let supportedLanguages = [
            "en-US": "English (US)",
            "ja-JP": "日本語",
            "en-GB": "English (UK)",
            "fr-FR": "Français",
            "de-DE": "Deutsch",
            "zh-CN": "中文 (简体)",
            "es-ES": "Español"
        ]
    }
    
    // アプリケーション内の効果音設定
    struct SoundEffects {
        var isEnabled: Bool = true
        var hapticFeedback: Bool = true
    }
    
    var spatialAudio = SpatialAudio()
    var textToSpeech = TextToSpeech()
    var soundEffects = SoundEffects()
    
    /// 設定をデフォルト値にリセット
    mutating func resetToDefaults() {
        spatialAudio = SpatialAudio()
        textToSpeech = TextToSpeech()
        soundEffects = SoundEffects()
    }
    
    /// 空間オーディオの状態を切り替え
    mutating func toggleSpatialAudio() {
        spatialAudio.isEnabled.toggle()
    }
    
    /// 効果音の状態を切り替え
    mutating func toggleSoundEffects() {
        soundEffects.isEnabled.toggle()
    }
}

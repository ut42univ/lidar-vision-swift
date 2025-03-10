import Foundation
import UIKit

/// 触覚フィードバックの強度
enum HapticIntensity: String, Codable {
    case light
    case medium
    case heavy
    
    var uiStyle: UIImpactFeedbackGenerator.FeedbackStyle {
        switch self {
        case .light: return .light
        case .medium: return .medium
        case .heavy: return .heavy
        }
    }
}

/// アプリケーション全体の設定を管理するモデル
struct AppSettings: Codable {
    // 空間オーディオ設定
    struct SpatialAudio: Codable {
        var isEnabled: Bool = false
        var volume: Float = 0.8
        var maxDistance: Float = 5.0 // 最大検出距離（メートル）
        var nearThreshold: Float = 0.5 // 近い障害物の閾値
        var mediumThreshold: Float = 2.0 // 中間距離の閾値
    }
    
    // 音響トーン設定
    struct AudioTones: Codable {
        var highFrequency: Float = 880.0  // 高音（近距離用）
        var mediumFrequency: Float = 440.0 // 中音（中距離用）
        var lowFrequency: Float = 220.0   // 低音（遠距離用）
    }
    
    // 触覚フィードバック設定
    struct HapticFeedback: Codable {
        var isEnabled: Bool = true
        var nearIntensity: HapticIntensity = .heavy
        var mediumIntensity: HapticIntensity = .medium
        var nearInterval: TimeInterval = 0.1  // 近距離の振動間隔（秒）
        var mediumInterval: TimeInterval = 0.3 // 中距離の振動間隔（秒）
    }
    
    // テキスト読み上げ設定
    struct TextToSpeech: Codable {
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
    
    var spatialAudio = SpatialAudio()
    var audioTones = AudioTones()
    var hapticFeedback = HapticFeedback()
    var textToSpeech = TextToSpeech()
    
    // MARK: - 永続化
    
    /// 設定を保存
    func save() {
        do {
            let data = try JSONEncoder().encode(self)
            UserDefaults.standard.set(data, forKey: "AppSettings")
            print("設定を保存しました")
        } catch {
            print("設定の保存に失敗しました: \(error)")
        }
    }
    
    /// 設定をロード
    static func load() -> AppSettings {
        guard let data = UserDefaults.standard.data(forKey: "AppSettings") else {
            print("保存された設定がないため、デフォルト設定を使用します")
            return AppSettings()
        }
        
        do {
            return try JSONDecoder().decode(AppSettings.self, from: data)
        } catch {
            print("設定の読み込みに失敗しました: \(error)")
            return AppSettings()
        }
    }
}

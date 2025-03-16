import Foundation
import UIKit
import Combine

/// 触覚フィードバックの強度 - 列挙型を使用して明確化
enum HapticIntensity: String, Codable, CaseIterable {
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
    
    var displayName: String {
        switch self {
        case .light: return "Light"
        case .medium: return "Medium"
        case .heavy: return "Heavy"
        }
    }
}

/// アプリケーション設定 - UserDefaultsとの同期を改善
final class AppSettings: ObservableObject, Codable {
    // MARK: - Nested Settings Structures
    
    /// 空間オーディオ設定
    struct SpatialAudio: Codable {
        var isEnabled: Bool = false
        var volume: Float = 0.8
        var maxDistance: Float = 5.0
        var nearThreshold: Float = 0.5
        var mediumThreshold: Float = 2.0
        
        // 値の検証を追加
        mutating func validate() {
            volume = max(0, min(1, volume))
            maxDistance = max(1, min(10, maxDistance))
            nearThreshold = max(0.1, min(1, nearThreshold))
            mediumThreshold = max(1, min(maxDistance - 0.5, mediumThreshold))
        }
    }
    
    /// 音響トーン設定
    struct AudioTones: Codable {
        var highFrequency: Float = 880.0
        var mediumFrequency: Float = 440.0
        var lowFrequency: Float = 220.0
        
        // 値の検証を追加
        mutating func validate() {
            highFrequency = max(500, min(1200, highFrequency))
            mediumFrequency = max(300, min(700, mediumFrequency))
            lowFrequency = max(100, min(400, lowFrequency))
        }
    }
    
    /// 触覚フィードバック設定
    struct HapticFeedback: Codable {
        var isEnabled: Bool = true
        var startDistance: Float = 3.0
        var nearIntensity: HapticIntensity = .heavy
        var mediumIntensity: HapticIntensity = .medium
        var nearInterval: TimeInterval = 0.1
        var mediumInterval: TimeInterval = 0.3
        var useCoreHaptics: Bool = true
        var powerSavingMode: Bool = false
        var intensityMultiplier: Float = 1.0
        var tooCloseDistance: Float = 0.25  // 0.5から0.25に変更
        
        init(isEnabled: Bool = true, startDistance: Float = 3.0, nearIntensity: HapticIntensity = .heavy, mediumIntensity: HapticIntensity = .medium, nearInterval: TimeInterval = 0.1, mediumInterval: TimeInterval = 0.3, useCoreHaptics: Bool = true, powerSavingMode: Bool = false, intensityMultiplier: Float = 1.0, tooCloseDistance: Float = 0.25) {  // 0.5から0.25に変更
            self.isEnabled = isEnabled
            self.startDistance = startDistance
            self.nearIntensity = nearIntensity
            self.mediumIntensity = mediumIntensity
            self.nearInterval = nearInterval
            self.mediumInterval = mediumInterval
            self.useCoreHaptics = useCoreHaptics
            self.powerSavingMode = powerSavingMode
            self.intensityMultiplier = intensityMultiplier
            self.tooCloseDistance = tooCloseDistance
        }
        
        // 値の検証を追加
        mutating func validate() {
            startDistance = max(0.5, min(5, startDistance))
            nearInterval = max(0.05, min(0.5, nearInterval))
            mediumInterval = max(0.1, min(1, mediumInterval))
            intensityMultiplier = max(0.5, min(1.5, intensityMultiplier))
            tooCloseDistance = max(0.1, min(1, tooCloseDistance))
        }
        
        // デコード処理にデフォルト値を設定
        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            isEnabled = try container.decodeIfPresent(Bool.self, forKey: .isEnabled) ?? true
            startDistance = try container.decodeIfPresent(Float.self, forKey: .startDistance) ?? 3.0
            nearIntensity = try container.decodeIfPresent(HapticIntensity.self, forKey: .nearIntensity) ?? .heavy
            mediumIntensity = try container.decodeIfPresent(HapticIntensity.self, forKey: .mediumIntensity) ?? .medium
            nearInterval = try container.decodeIfPresent(TimeInterval.self, forKey: .nearInterval) ?? 0.1
            mediumInterval = try container.decodeIfPresent(TimeInterval.self, forKey: .mediumInterval) ?? 0.3
            useCoreHaptics = try container.decodeIfPresent(Bool.self, forKey: .useCoreHaptics) ?? true
            powerSavingMode = try container.decodeIfPresent(Bool.self, forKey: .powerSavingMode) ?? false
            intensityMultiplier = try container.decodeIfPresent(Float.self, forKey: .intensityMultiplier) ?? 1.0
            tooCloseDistance = try container.decodeIfPresent(Float.self, forKey: .tooCloseDistance) ?? 0.25  // 0.5から0.25に変更
        }
        
        enum CodingKeys: String, CodingKey {
            case isEnabled, startDistance, nearIntensity, mediumIntensity, nearInterval, mediumInterval, useCoreHaptics, powerSavingMode, intensityMultiplier, tooCloseDistance
        }
    }
    
    /// テキスト読み上げ設定
    struct TextToSpeech: Codable {
        var rate: Float = 0.5
        var pitch: Float = 1.0
        var volume: Float = 0.8
        var language: String = "en-US"
        
        // サポートされている言語の定義を静的プロパティから計算プロパティに変更
        static var supportedLanguages: [String: String] {
            [
                "en-US": "English (US)",
                "ja-JP": "日本語",
                "en-GB": "English (UK)",
                "fr-FR": "Français",
                "de-DE": "Deutsch",
                "zh-CN": "中文 (简体)",
                "es-ES": "Español"
            ]
        }
        
        // 値の検証を追加
        mutating func validate() {
            rate = max(0.1, min(1, rate))
            pitch = max(0.5, min(2, pitch))
            volume = max(0, min(1, volume))
            
            // 言語が有効でなければデフォルトに戻す
            if !Self.supportedLanguages.keys.contains(language) {
                language = "en-US"
            }
        }
    }
    
    // MARK: - Properties
    
    @Published var spatialAudio = SpatialAudio()
    @Published var audioTones = AudioTones()
    @Published var hapticFeedback = HapticFeedback()
    @Published var textToSpeech = TextToSpeech()
    
    private var cancellables = Set<AnyCancellable>()
    private let saveSubject = PassthroughSubject<Void, Never>()
    
    // MARK: - Initialization
    
    init() {
        setupAutosave()
    }
    
    // MARK: - Autosave
    
    private func setupAutosave() {
        // 設定変更を監視して自動保存
        let publishers: [AnyPublisher<Void, Never>] = [
            $spatialAudio.dropFirst().map { _ in }.eraseToAnyPublisher(),
            $audioTones.dropFirst().map { _ in }.eraseToAnyPublisher(),
            $hapticFeedback.dropFirst().map { _ in }.eraseToAnyPublisher(),
            $textToSpeech.dropFirst().map { _ in }.eraseToAnyPublisher(),
            saveSubject.eraseToAnyPublisher()
        ]
        
        Publishers.MergeMany(publishers)
            .debounce(for: .seconds(0.5), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.save()
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Settings Operations
    
    /// 設定をデフォルト値にリセット
    func resetToDefaults() {
        spatialAudio = SpatialAudio()
        audioTones = AudioTones()
        hapticFeedback = HapticFeedback()
        textToSpeech = TextToSpeech()
        
        // 明示的に保存をトリガー
        saveSubject.send()
    }
    
    /// 空間オーディオの状態を切り替え
    func toggleSpatialAudio() {
        spatialAudio.isEnabled.toggle()
    }
    
    /// 触覚フィードバックの状態を切り替え
    func toggleHapticFeedback() {
        hapticFeedback.isEnabled.toggle()
    }
    
    /// すべての設定値を検証
    func validateAllSettings() {
        spatialAudio.validate()
        audioTones.validate()
        hapticFeedback.validate()
        textToSpeech.validate()
    }
    
    // MARK: - Persistence
    
    /// 設定を保存
    func save() {
        // 保存前に値を検証
        validateAllSettings()
        
        do {
            let data = try JSONEncoder().encode(self)
            UserDefaults.standard.set(data, forKey: "AppSettings")
        } catch {
            #if DEBUG
            assertionFailure("Failed to save settings: \(error)")
            #endif
        }
    }
    
    /// 設定をロード
    static func load() -> AppSettings {
        guard let data = UserDefaults.standard.data(forKey: "AppSettings") else {
            return AppSettings()
        }
        
        do {
            let settings = try JSONDecoder().decode(AppSettings.self, from: data)
            settings.validateAllSettings()
            return settings
        } catch {
            #if DEBUG
            assertionFailure("Failed to load settings: \(error)")
            #endif
            return AppSettings()
        }
    }
    
    // MARK: - Codable
    
    enum CodingKeys: String, CodingKey {
        case spatialAudio, audioTones, hapticFeedback, textToSpeech
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(spatialAudio, forKey: .spatialAudio)
        try container.encode(audioTones, forKey: .audioTones)
        try container.encode(hapticFeedback, forKey: .hapticFeedback)
        try container.encode(textToSpeech, forKey: .textToSpeech)
    }
    
    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        spatialAudio = try container.decode(SpatialAudio.self, forKey: .spatialAudio)
        audioTones = try container.decode(AudioTones.self, forKey: .audioTones)
        hapticFeedback = try container.decode(HapticFeedback.self, forKey: .hapticFeedback)
        textToSpeech = try container.decode(TextToSpeech.self, forKey: .textToSpeech)
        
        setupAutosave()
    }
}

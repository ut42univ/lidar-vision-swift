import Foundation

/// アプリケーション全体の環境設定を管理
struct AppEnvironment {
    /// OpenAI APIキー
    static var openAIAPIKey: String {
        guard let apiKey = Bundle.main.infoDictionary?["OPENAI_API_KEY"] as? String else {
            print("Warning: OPENAI_API_KEY is not set in Info.plist")
            return ""
        }
        return apiKey
    }
}

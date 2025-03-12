import Foundation

/// アプリケーション全体の環境設定を管理
struct AppEnvironment {
    /// OpenAI APIキー
    static var openAIAPIKey: String? {
        #if DEBUG
        let key = Bundle.main.infoDictionary?["OPENAI_API_KEY"] as? String
        if key == nil || key?.isEmpty == true {
            print("Warning: OPENAI_API_KEY is not set in Info.plist")
        }
        return key
        #else
        return Bundle.main.infoDictionary?["OPENAI_API_KEY"] as? String
        #endif
    }
}

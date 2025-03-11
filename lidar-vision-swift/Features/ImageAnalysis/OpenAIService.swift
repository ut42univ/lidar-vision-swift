import Foundation
import UIKit
import Combine

/// OpenAI API関連エラー
enum OpenAIServiceError: Error {
    case invalidAPIKey
    case imageConversionFailed
    case networkError(Error)
    case decodingError(Error)
    case responseError(Int, String)
    case unknownError
}

struct ChatMessage: Identifiable {
    let id = UUID()
    let content: String
    let isUser: Bool
    let timestamp = Date()
}

/// OpenAI APIを使用した画像分析と会話サービス
final class OpenAIService: ObservableObject {
    @Published var isLoading = false
    @Published var imageDescription: String = ""
    @Published var error: String? = nil
    @Published var messages: [ChatMessage] = []
    
    private var cancellables = Set<AnyCancellable>()
    private let apiKey: String
    private var imageBase64: String? = nil
    
    init(apiKey: String? = nil) {
        // APIキーがパラメータとして渡された場合はそれを使用、そうでなければ環境から取得
        self.apiKey = apiKey ?? AppEnvironment.openAIAPIKey
        print("OpenAIService initialized")
    }
    
    /// 画像を分析して説明を生成 (async/await版)
    func analyzeImage(_ image: UIImage) {
        // UIの更新を即座に反映
        isLoading = true
        error = nil
        
        Task {
            do {
                // 非同期処理をTaskで実行
                let description = try await performImageAnalysis(image)
                
                // UIの更新はメインスレッドで
                await MainActor.run {
                    self.imageDescription = description
                    self.messages = [ChatMessage(content: description, isUser: false)]
                    self.isLoading = false
                }
            } catch let error as OpenAIServiceError {
                await handleError(error)
            } catch {
                await handleError(.unknownError)
            }
        }
    }
    
    /// 画像分析を実行する内部メソッド
    private func performImageAnalysis(_ image: UIImage) async throws -> String {
        // APIキーチェック
        if apiKey.isEmpty {
            throw OpenAIServiceError.invalidAPIKey
        }
        
        // 画像データの変換
        guard let imageData = prepareImageData(from: image) else {
            throw OpenAIServiceError.imageConversionFailed
        }
        
        // Base64エンコード
        let base64Image = imageData.base64EncodedString()
        self.imageBase64 = base64Image
        
        // APIリクエスト構築
        let requestBody = buildAnalysisRequestBody(with: base64Image)
        let request = try buildAPIRequest(with: requestBody)
        
        // リクエスト送信と結果の解析
        return try await sendRequest(request)
    }
    
    /// 画像データを適切なサイズと品質で準備
    private func prepareImageData(from image: UIImage) -> Data? {
        // 基本の圧縮品質で試行
        guard let imageData = image.jpegData(compressionQuality: 0.7) else {
            return nil
        }
        
        // サイズをチェックして必要なら圧縮率を下げる
        let imageSizeKB = Double(imageData.count) / 1024.0
        if imageSizeKB > 20000 { // 20MB制限
            return image.jpegData(compressionQuality: 0.5)
        }
        
        return imageData
    }
    
    /// APIリクエストボディを構築
    private func buildAnalysisRequestBody(with base64Image: String) -> [String: Any] {
        return [
            "model": "gpt-4o",
            "messages": [
                [
                    "role": "user",
                    "content": [
                        [
                            "type": "text",
                            "text": "Please describe this image in detail. What is shown and what kind of scene it is. This is for a blind user to understand their surroundings."
                        ],
                        [
                            "type": "image_url",
                            "image_url": [
                                "url": "data:image/jpeg;base64,\(base64Image)"
                            ]
                        ]
                    ]
                ]
            ],
            "max_tokens": 500
        ]
    }
    
    /// URLRequestを構築
    private func buildAPIRequest(with body: [String: Any]) throws -> URLRequest {
        let url = URL(string: "https://api.openai.com/v1/chat/completions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        return request
    }
    
    /// リクエストを送信して結果を解析
    private func sendRequest(_ request: URLRequest) async throws -> String {
        let (data, response) = try await URLSession.shared.data(for: request)
        
        // HTTPレスポンスの確認
        guard let httpResponse = response as? HTTPURLResponse else {
            throw OpenAIServiceError.unknownError
        }
        
        if httpResponse.statusCode != 200 {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw OpenAIServiceError.responseError(httpResponse.statusCode, errorMessage)
        }
        
        // レスポンスの解析
        do {
            let result = try JSONDecoder().decode(OpenAIResponse.self, from: data)
            if let content = result.choices.first?.message.content {
                return content
            } else {
                throw OpenAIServiceError.unknownError
            }
        } catch {
            throw OpenAIServiceError.decodingError(error)
        }
    }
    
    /// AIに質問を送信
    func sendQuestion(_ question: String) {
        // 質問を会話履歴に追加
        let userMessage = ChatMessage(content: question, isUser: true)
        messages.append(userMessage)
        isLoading = true
        error = nil
        
        Task {
            do {
                let messageHistory = buildMessageHistory(with: question)
                let requestBody = [
                    "model": "gpt-4o",
                    "messages": messageHistory,
                    "max_tokens": 500
                ] as [String: Any]
                
                let request = try buildAPIRequest(with: requestBody)
                let answer = try await sendRequest(request)
                
                await MainActor.run {
                    self.messages.append(ChatMessage(content: answer, isUser: false))
                    self.isLoading = false
                }
            } catch {
                await handleError(.networkError(error))
            }
        }
    }
    
    /// メッセージ履歴を構築
    private func buildMessageHistory(with question: String? = nil) -> [[String: Any]] {
        var history: [[String: Any]] = []
        
        // システムメッセージを追加
        history.append([
            "role": "system",
            "content": "You are a helpful assistant that helps blind users understand images and their surroundings. Answer questions based on the image that was shared earlier."
        ])
        
        // 画像メッセージを追加
        if let imageBase64 = self.imageBase64 {
            history.append([
                "role": "user",
                "content": [
                    [
                        "type": "text",
                        "text": "This is an image of my surroundings. Please help me understand what's in it."
                    ],
                    [
                        "type": "image_url",
                        "image_url": [
                            "url": "data:image/jpeg;base64,\(imageBase64)"
                        ]
                    ]
                ]
            ])
            
            // 最初のAI応答
            if !imageDescription.isEmpty {
                history.append([
                    "role": "assistant",
                    "content": imageDescription
                ])
            }
        }
        
        // 既存の会話履歴を追加（最初のAI応答を除く）
        for i in 1..<messages.count {
            let message = messages[i]
            history.append([
                "role": message.isUser ? "user" : "assistant",
                "content": message.content
            ])
        }
        
        // 現在の質問を追加
        if let question = question {
            history.append([
                "role": "user",
                "content": question
            ])
        }
        
        return history
    }
    
    /// エラー処理
    @MainActor
    private func handleError(_ serviceError: OpenAIServiceError) {
        let errorMessage: String
        
        switch serviceError {
        case .invalidAPIKey:
            errorMessage = "API key is missing or invalid. Please check your settings."
        case .imageConversionFailed:
            errorMessage = "Failed to process the image. Please try again with a different image."
        case .networkError(let error):
            errorMessage = "Network error: \(error.localizedDescription)"
        case .decodingError(let error):
            errorMessage = "Failed to process API response: \(error.localizedDescription)"
        case .responseError(let code, _):
            errorMessage = "API error (code \(code)). Please try again later."
        case .unknownError:
            errorMessage = "An unknown error occurred. Please try again."
        }
        
        self.error = errorMessage
        self.isLoading = false
    }
    
    /// 会話履歴をリセット
    func resetConversation() {
        messages.removeAll()
        imageBase64 = nil
        imageDescription = ""
        error = nil
    }
}

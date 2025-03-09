import Foundation
import UIKit
import Combine

/// メッセージの種類
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
        if let providedKey = apiKey, !providedKey.isEmpty {
            self.apiKey = providedKey
            print("Using provided API key")
        } else {
            // APIキーを環境から取得
            self.apiKey = AppEnvironment.openAIAPIKey
            print("Using API key from environment")
        }
    }
    
    /// 画像を分析して説明を生成
    func analyzeImage(_ image: UIImage) {
        print("Starting image analysis...")
        
        // APIキーチェック
        if apiKey.isEmpty {
            self.error = "有効なAPIキーがありません。Info.plistの設定を確認してください。"
            print("Invalid API key")
            return
        }
        
        guard let imageData = image.jpegData(compressionQuality: 0.7) else {
            self.error = "画像の変換に失敗しました"
            print("Failed to convert image to JPEG data")
            return
        }
        
        // 画像サイズをチェック (APIには制限があります)
        let imageSizeKB = Double(imageData.count) / 1024.0
        print("Image size: \(imageSizeKB) KB")
        
        // 大きすぎる場合は圧縮率を下げて再度試行
        var finalImageData = imageData
        if imageSizeKB > 20000 { // 20MB制限の仮定
            print("Image too large, trying with lower quality")
            guard let compressedData = image.jpegData(compressionQuality: 0.5) else {
                self.error = "大きな画像の圧縮に失敗しました"
                return
            }
            
            let newSizeKB = Double(compressedData.count) / 1024.0
            print("Compressed image size: \(newSizeKB) KB")
            finalImageData = compressedData
        }
        
        isLoading = true
        error = nil
        
        // 会話履歴をリセット
        messages.removeAll()
        
        // Base64エンコード
        let base64Image = finalImageData.base64EncodedString()
        self.imageBase64 = base64Image
        print("Image encoded to base64")
        
        // リクエスト作成
        let url = URL(string: "https://api.openai.com/v1/chat/completions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        
        // リクエストボディ作成
        let requestBody: [String: Any] = [
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
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
            print("Request body created successfully")
        } catch {
            self.error = "Request creation failed: \(error.localizedDescription)"
            self.isLoading = false
            print("Failed to create request body: \(error)")
            return
        }
        
        print("Sending API request to OpenAI...")
        
        // APIリクエスト実行
        URLSession.shared.dataTaskPublisher(for: request)
            .map { data, response -> Data in
                // HTTPレスポンスをデバッグ
                if let httpResponse = response as? HTTPURLResponse {
                    print("API Response Code: \(httpResponse.statusCode)")
                    
                    // エラーレスポンスをログに記録
                    if httpResponse.statusCode != 200 {
                        if let errorText = String(data: data, encoding: .utf8) {
                            print("Error response: \(errorText)")
                        }
                    }
                }
                return data
            }
            .decode(type: OpenAIResponse.self, decoder: JSONDecoder())
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    guard let self = self else { return }
                    
                    self.isLoading = false
                    
                    switch completion {
                    case .finished:
                        print("API request completed successfully")
                    case .failure(let error):
                        self.error = "API error: \(error.localizedDescription)"
                        print("API request failed: \(error)")
                        
                        // デコードエラーの詳細を表示
                        if let decodingError = error as? DecodingError {
                            switch decodingError {
                            case .dataCorrupted(let context):
                                print("Data corrupted: \(context.debugDescription)")
                            case .keyNotFound(let key, let context):
                                print("Key not found: \(key.stringValue), context: \(context.debugDescription)")
                            case .typeMismatch(let type, let context):
                                print("Type mismatch: expected \(type), context: \(context.debugDescription)")
                            case .valueNotFound(let type, let context):
                                print("Value not found: expected \(type), context: \(context.debugDescription)")
                            @unknown default:
                                print("Unknown decoding error: \(decodingError)")
                            }
                        }
                    }
                },
                receiveValue: { [weak self] response in
                    guard let self = self else { return }
                    
                    if let content = response.choices.first?.message.content {
                        print("Received description from API: \(content.prefix(50))...")
                        self.imageDescription = content
                        
                        // 会話履歴に追加
                        self.messages.append(ChatMessage(content: content, isUser: false))
                    } else {
                        self.error = "応答の解析に失敗しました"
                        print("Failed to parse response: no content found")
                    }
                }
            )
            .store(in: &cancellables)
    }
    
    /// AIに質問を送信
    func sendQuestion(_ question: String) {
        print("Sending follow-up question to OpenAI...")
        
        // APIキーチェック
        if apiKey.isEmpty {
            self.error = "有効なAPIキーがありません。Info.plistの設定を確認してください。"
            print("Invalid API key")
            return
        }
        
        // 質問を会話履歴に追加
        let userMessage = ChatMessage(content: question, isUser: true)
        messages.append(userMessage)
        
        isLoading = true
        error = nil
        
        // メッセージ履歴を構築
        var messageHistory: [[String: Any]] = []
        
        // システムメッセージを追加
        messageHistory.append([
            "role": "system",
            "content": "You are a helpful assistant that helps blind users understand images and their surroundings. Answer questions based on the image that was shared earlier."
        ])
        
        // 最初のメッセージ（画像付き）
        if let imageBase64 = self.imageBase64 {
            messageHistory.append([
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
                messageHistory.append([
                    "role": "assistant",
                    "content": imageDescription
                ])
            }
        }
        
        // それ以降の会話履歴（最初のAI応答以降）
        for i in 1..<messages.count {
            let message = messages[i]
            let role = message.isUser ? "user" : "assistant"
            messageHistory.append([
                "role": role,
                "content": message.content
            ])
        }
        
        // リクエスト作成
        let url = URL(string: "https://api.openai.com/v1/chat/completions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        
        // リクエストボディ作成
        let requestBody: [String: Any] = [
            "model": "gpt-4o",
            "messages": messageHistory,
            "max_tokens": 500
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
            print("Follow-up request created successfully")
        } catch {
            self.error = "Request creation failed: \(error.localizedDescription)"
            self.isLoading = false
            print("Failed to create request body: \(error)")
            return
        }
        
        // APIリクエスト実行
        URLSession.shared.dataTaskPublisher(for: request)
            .map { data, response -> Data in
                if let httpResponse = response as? HTTPURLResponse {
                    print("API Response Code: \(httpResponse.statusCode)")
                    if httpResponse.statusCode != 200 {
                        if let errorText = String(data: data, encoding: .utf8) {
                            print("Error response: \(errorText)")
                        }
                    }
                }
                return data
            }
            .decode(type: OpenAIResponse.self, decoder: JSONDecoder())
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    guard let self = self else { return }
                    
                    self.isLoading = false
                    
                    switch completion {
                    case .finished:
                        print("Follow-up request completed successfully")
                    case .failure(let error):
                        self.error = "API error: \(error.localizedDescription)"
                        print("API request failed: \(error)")
                    }
                },
                receiveValue: { [weak self] response in
                    guard let self = self else { return }
                    
                    if let content = response.choices.first?.message.content {
                        print("Received response from API: \(content.prefix(50))...")
                        
                        // 会話履歴に追加
                        self.messages.append(ChatMessage(content: content, isUser: false))
                    } else {
                        self.error = "応答の解析に失敗しました"
                        print("Failed to parse response: no content found")
                    }
                }
            )
            .store(in: &cancellables)
    }
    
    /// 会話履歴をリセット
    func resetConversation() {
        messages.removeAll()
        imageBase64 = nil
        imageDescription = ""
        error = nil
    }
}

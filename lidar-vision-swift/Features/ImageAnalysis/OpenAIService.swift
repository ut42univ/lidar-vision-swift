import Foundation
import UIKit
import Combine

/// OpenAI APIを使用した画像分析サービス
final class OpenAIService: ObservableObject {
    @Published var isLoading = false
    @Published var imageDescription: String = ""
    @Published var error: String? = nil
    
    private var cancellables = Set<AnyCancellable>()
    private let apiKey: String
    
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
        
        // Base64エンコード
        let base64Image = finalImageData.base64EncodedString()
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
                            "text": "Please describe this image in detail. What is shown and what kind of scene it is in English."
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
                    } else {
                        self.error = "応答の解析に失敗しました"
                        print("Failed to parse response: no content found")
                    }
                }
            )
            .store(in: &cancellables)
    }
}

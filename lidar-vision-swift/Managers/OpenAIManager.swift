import Foundation
import UIKit
import Combine

final class OpenAIManager: ObservableObject {
    @Published var isLoading = false
    @Published var imageDescription: String = ""
    @Published var error: String? = nil
    
    private var cancellables = Set<AnyCancellable>()
    private let apiKey: String
    
    init(apiKey: String) {
        self.apiKey = apiKey
    }
    
    func analyzeImage(_ image: UIImage) {
        guard let imageData = image.jpegData(compressionQuality: 0.7) else {
            self.error = "Failed to convert image"
            return
        }
        
        isLoading = true
        error = nil
        
        // Base64 encode
        let base64Image = imageData.base64EncodedString()
        
        // Create request
        let url = URL(string: "https://api.openai.com/v1/chat/completions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        
        // Create request body
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
        } catch {
            self.error = "Failed to create request: \(error.localizedDescription)"
            self.isLoading = false
            return
        }
        
        // Execute API request
        URLSession.shared.dataTaskPublisher(for: request)
            .map(\.data)
            .decode(type: OpenAIResponse.self, decoder: JSONDecoder())
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    self?.isLoading = false
                    if case .failure(let error) = completion {
                        self?.error = "API error: \(error.localizedDescription)"
                    }
                },
                receiveValue: { [weak self] response in
                    if let content = response.choices.first?.message.content {
                        self?.imageDescription = content
                    } else {
                        self?.error = "Failed to parse response"
                    }
                }
            )
            .store(in: &cancellables)
    }
}

// OpenAI API response structure
struct OpenAIResponse: Decodable {
    let choices: [Choice]
    
    struct Choice: Decodable {
        let message: Message
    }
    
    struct Message: Decodable {
        let content: String
    }
}

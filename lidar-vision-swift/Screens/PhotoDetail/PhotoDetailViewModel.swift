import SwiftUI
import Combine

/// 写真詳細画面のViewModel
final class PhotoDetailViewModel: ObservableObject {
    // 入力と依存サービス
    let image: UIImage
    
    // サービスはプロパティとして保持
    let openAIService: OpenAIService
    let speechService: TextToSpeechService
    
    // プロパティを監視して状態変化をビューに通知
    @Published private(set) var isAnalyzing: Bool = false
    @Published private(set) var analysisError: String? = nil
    
    private var cancellables = Set<AnyCancellable>()
    
    init(image: UIImage) {
        print("Initializing PhotoDetailViewModel")
        self.image = image
        
        // 環境変数からAPIキーを取得するデフォルトの動作を使用
        self.openAIService = OpenAIService()
        self.speechService = TextToSpeechService()
        
        // サービスの状態変化を監視してプロパティに反映
        setupBindings()
    }
    
    private func setupBindings() {
        // OpenAIServiceの状態変化を監視
        openAIService.$isLoading
            .assign(to: \.isAnalyzing, on: self)
            .store(in: &cancellables)
        
        openAIService.$error
            .assign(to: \.analysisError, on: self)
            .store(in: &cancellables)
    }
    
    /// 画像の自動分析を開始
    func analyzeImage() {
        print("Starting image analysis from ViewModel")
        openAIService.analyzeImage(image)
    }
    
    /// 画像の説明を読み上げ
    func speakDescription() {
        if speechService.isPlaying {
            speechService.stopSpeaking()
        } else if !openAIService.imageDescription.isEmpty {
            speechService.speakWithAutoLanguageDetection(text: openAIService.imageDescription)
        }
    }
    
    deinit {
        print("PhotoDetailViewModel deinit")
        if speechService.isPlaying {
            speechService.stopSpeaking()
        }
    }
}

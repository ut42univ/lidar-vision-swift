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
    @Published var autoPlay: Bool = true // 自動分析・読み上げの設定
    
    private var cancellables = Set<AnyCancellable>()
    
    init(image: UIImage, autoAnalyze: Bool = true) {
        print("Initializing PhotoDetailViewModel")
        self.image = image
        
        // 環境変数からAPIキーを取得するデフォルトの動作を使用
        self.openAIService = OpenAIService()
        self.speechService = TextToSpeechService()
        
        // サービスの状態変化を監視してプロパティに反映
        setupBindings()
        
        // 画面表示時に自動分析
        if autoAnalyze {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.analyzeImage()
            }
        }
    }
    
    private func setupBindings() {
        // OpenAIServiceの状態変化を監視
        openAIService.$isLoading
            .assign(to: \.isAnalyzing, on: self)
            .store(in: &cancellables)
        
        openAIService.$error
            .assign(to: \.analysisError, on: self)
            .store(in: &cancellables)
        
        // 分析完了時の処理
        openAIService.$imageDescription
            .dropFirst() // 初期値をスキップ
            .filter { !$0.isEmpty } // 空でない場合のみ
            .sink { [weak self] description in
                guard let self = self else { return }
                
                // 自動読み上げが有効なら読み上げ開始
                if self.autoPlay {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        self.speechService.speakWithAutoLanguageDetection(text: description)
                    }
                }
            }
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
    
    /// 自動読み上げを切り替え
    func toggleAutoPlay() {
        autoPlay.toggle()
        if autoPlay && !openAIService.imageDescription.isEmpty && !speechService.isPlaying {
            speakDescription()
        } else if !autoPlay && speechService.isPlaying {
            speechService.stopSpeaking()
        }
    }
    
    deinit {
        print("PhotoDetailViewModel deinit")
        if speechService.isPlaying {
            speechService.stopSpeaking()
        }
    }
}

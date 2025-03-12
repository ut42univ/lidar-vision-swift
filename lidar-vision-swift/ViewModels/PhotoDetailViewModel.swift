import SwiftUI
import Combine

/// 写真詳細画面のViewModel
final class PhotoDetailViewModel: ObservableObject {
    // 入力
    let image: UIImage
    
    // 公開プロパティ（UI状態）
    @Published var isAnalyzing = false
    @Published var analysisError: String? = nil
    @Published var autoPlay: Bool = true
    @Published var showChatView = false
    
    // サービスはプロパティとして保持（Dependency Injection用に初期化で注入可能に）
    let openAIService: OpenAIService
    let speechService: TextToSpeechService
    
    private var cancellables = Set<AnyCancellable>()
    
    init(
        image: UIImage,
        openAIService: OpenAIService = OpenAIService(),
        speechService: TextToSpeechService = TextToSpeechService(),
        autoAnalyze: Bool = true
    ) {
        print("Initializing PhotoDetailViewModel")
        self.image = image
        self.openAIService = openAIService
        self.speechService = speechService
        
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
        // リアクティブにサービスの状態を追跡
        setupOpenAIServiceBindings()
        setupSpeechServiceBindings()
    }
    
    private func setupOpenAIServiceBindings() {
        // OpenAIServiceの読み込み状態を追跡
        openAIService.$isLoading
            .receive(on: RunLoop.main)
            .assign(to: \.isAnalyzing, on: self)
            .store(in: &cancellables)
        
        // エラー状態を追跡
        openAIService.$error
            .receive(on: RunLoop.main)
            .map { $0 } // 変換不要だがわかりやすく
            .assign(to: \.analysisError, on: self)
            .store(in: &cancellables)
        
        // 分析完了時の処理
        openAIService.$imageDescription
            .dropFirst() // 初期値をスキップ
            .filter { !$0.isEmpty } // 空でない場合のみ
            .throttle(for: .seconds(0.5), scheduler: RunLoop.main, latest: true) // 短時間の重複を防止
            .sink { [weak self] description in
                guard let self = self, !description.isEmpty else { return }
                
                // 自動読み上げが有効なら読み上げ開始
                if self.autoPlay {
                    self.speechService.speak(text: description)
                }
            }
            .store(in: &cancellables)
    }
    
    private func setupSpeechServiceBindings() {
        // 必要に応じて音声サービスの状態を追跡
        // この例では実装不要
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
            speechService.speak(text: openAIService.imageDescription)
        }
    }
    
    /// 自動読み上げを切り替え
    func toggleAutoPlay() {
        autoPlay.toggle()
        
        // 状態に応じて適切な処理を実行
        handleAutoPlayStateChange()
    }
    
    private func handleAutoPlayStateChange() {
        if autoPlay && !openAIService.imageDescription.isEmpty && !speechService.isPlaying {
            speakDescription()
        } else if !autoPlay && speechService.isPlaying {
            speechService.stopSpeaking()
        }
    }
    
    /// チャットビューの表示状態を切り替え
    func toggleChatView() {
        withAnimation {
            showChatView.toggle()
        }
    }
    
    deinit {
        print("PhotoDetailViewModel deinit")
        if speechService.isPlaying {
            speechService.stopSpeaking()
        }
        
        // サブスクリプションをキャンセル
        cancellables.forEach { $0.cancel() }
        cancellables.removeAll()
    }
}

// MARK: - Computed Properties
extension PhotoDetailViewModel {
    // 現在の説明テキスト
    var description: String {
        openAIService.imageDescription
    }
    
    // 分析ボタンを表示すべきかのフラグ
    var shouldShowAnalyzeButton: Bool {
        return openAIService.imageDescription.isEmpty &&
               openAIService.error == nil &&
               !openAIService.isLoading
    }
    
    // 読み上げボタンを表示すべきかのフラグ
    var canPlayDescription: Bool {
        return !openAIService.imageDescription.isEmpty
    }
}

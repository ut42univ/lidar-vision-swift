import SwiftUI

/// 写真詳細画面
struct PhotoDetailView: View {
    let image: UIImage
    @StateObject private var viewModel: PhotoDetailViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showChatView = false
    
    init(image: UIImage, autoAnalyze: Bool = true) {
        self.image = image
        _viewModel = StateObject(wrappedValue: PhotoDetailViewModel(image: image, autoAnalyze: autoAnalyze))
    }
    
    var body: some View {
        NavigationView {
            VStack {
                if showChatView {
                    // チャットビュー
                    ChatView(
                        openAIService: viewModel.openAIService,
                        speechService: viewModel.speechService
                    )
                } else {
                    // 通常の詳細ビュー
                    ScrollView {
                        VStack(spacing: 20) {
                            // 画像表示部分
                            imageView
                            
                            // ステータス表示部分
                            statusContent
                            
                            // 質問ボタン
                            if !viewModel.openAIService.imageDescription.isEmpty {
                                askQuestionButton
                            }
                        }
                        .padding(.vertical)
                    }
                }
            }
            .navigationTitle(showChatView ? "AIに質問" : "Photo Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    closeButton
                }
                
                if !showChatView {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Toggle(isOn: $viewModel.autoPlay) {
                            Label("自動読み上げ", systemImage: "speaker.wave.2")
                                .labelStyle(.iconOnly)
                        }
                        .toggleStyle(SwitchToggleStyle(tint: .blue))
                        .disabled(viewModel.openAIService.imageDescription.isEmpty)
                    }
                    
                    if shouldShowAnalyzeButton {
                        ToolbarItem(placement: .bottomBar) {
                            analyzeButton
                        }
                    }
                } else {
                    // チャットビュー時の戻るボタン
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button(action: {
                            withAnimation {
                                showChatView = false
                            }
                        }) {
                            HStack {
                                Image(systemName: "chevron.left")
                                Text("戻る")
                            }
                        }
                    }
                }
            }
        }
        .onDisappear {
            if viewModel.speechService.isPlaying {
                viewModel.speechService.stopSpeaking()
            }
            // 画面を閉じる時にコンテキストをリセット
            viewModel.openAIService.resetConversation()
        }
    }
    
    // 質問ボタン
    private var askQuestionButton: some View {
        Button(action: {
            withAnimation {
                showChatView = true
            }
        }) {
            HStack {
                Image(systemName: "bubble.left.and.bubble.right.fill")
                Text("AIに詳しく質問する")
            }
            .padding()
            .frame(maxWidth: .infinity)
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(10)
            .padding(.horizontal)
        }
    }
    
    // 画像表示ビュー
    private var imageView: some View {
        Image(uiImage: image)
            .resizable()
            .scaledToFit()
            .cornerRadius(12)
            .padding(.horizontal)
    }
    
    // ステータス表示コンテンツ
    private var statusContent: some View {
        Group {
            if viewModel.openAIService.isLoading {
                ProgressView("Analyzing image...")
                    .padding()
            } else if let error = viewModel.openAIService.error {
                ErrorView(error: error) {
                    viewModel.analyzeImage()
                }
            } else if !viewModel.openAIService.imageDescription.isEmpty {
                ImageDescriptionView(
                    description: viewModel.openAIService.imageDescription,
                    speechService: viewModel.speechService,
                    speakAction: { viewModel.speakDescription() }
                )
                .padding(.horizontal)
            }
        }
    }
    
    // 読み上げ設定ビュー（削除）
    // private var speechSettingsView: some View {
    //    SpeechSettingsView(
    //        speechService: viewModel.speechService,
    //        description: viewModel.openAIService.imageDescription
    //    )
    // }
    
    // 閉じるボタン
    private var closeButton: some View {
        Button(action: {
            if viewModel.speechService.isPlaying {
                viewModel.speechService.stopSpeaking()
            }
            dismiss()
        }) {
            Image(systemName: "xmark.circle.fill")
                .foregroundColor(.secondary)
        }
    }
    
    // 分析ボタン
    private var analyzeButton: some View {
        Button("Analyze Image with AI") {
            viewModel.analyzeImage()
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
    }
    
    // 分析ボタンを表示すべきかのフラグ
    private var shouldShowAnalyzeButton: Bool {
        return viewModel.openAIService.imageDescription.isEmpty &&
               viewModel.openAIService.error == nil &&
               !viewModel.openAIService.isLoading
    }
}

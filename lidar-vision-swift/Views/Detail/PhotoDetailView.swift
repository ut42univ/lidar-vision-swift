import SwiftUI

struct PhotoDetailView: View {
    // 入力プロパティ
    let image: UIImage
    
    // ViewModel
    @StateObject private var viewModel: PhotoDetailViewModel
    
    // 環境変数
    @Environment(\.dismiss) private var dismiss
    
    init(image: UIImage, autoAnalyze: Bool = true) {
        self.image = image
        _viewModel = StateObject(wrappedValue: PhotoDetailViewModel(image: image, autoAnalyze: autoAnalyze))
    }
    
    var body: some View {
        NavigationStack {
            Group {
                if viewModel.showChatView {
                    // チャットビュー
                    ChatView(
                        openAIService: viewModel.openAIService,
                        speechService: viewModel.speechService
                    )
                    .transition(.move(edge: .trailing))
                } else {
                    // 通常の詳細ビュー
                    PhotoDetailContent(image: image, viewModel: viewModel)
                        .transition(.opacity)
                }
            }
            .navigationTitle(viewModel.showChatView ? "Ask AI" : "Photo Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                // ナビゲーションバーの内容
                toolbarItems
            }
        }
        .onDisappear {
            cleanup()
        }
    }
    
    // ツールバーアイテム
    @ToolbarContentBuilder
    private var toolbarItems: some ToolbarContent {
        // 常に表示する閉じるボタン
        ToolbarItem(placement: .navigationBarTrailing) {
            Button(action: dismiss.callAsFunction) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.secondary)
            }
        }
        
        // 詳細ビュー用のアイテム
        if !viewModel.showChatView {
            // 自動読み上げトグル
            ToolbarItem(placement: .navigationBarLeading) {
                Toggle(isOn: $viewModel.autoPlay) {
                    Label("Auto Speak", systemImage: "speaker.wave.2")
                        .labelStyle(.iconOnly)
                }
                .toggleStyle(SwitchToggleStyle(tint: .blue))
                .disabled(viewModel.openAIService.imageDescription.isEmpty)
            }
            
            // 分析ボタン（必要な場合のみ表示）
            if viewModel.shouldShowAnalyzeButton {
                ToolbarItem(placement: .bottomBar) {
                    Button("Analyze Image with AI") {
                        viewModel.analyzeImage()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                }
            }
        } else {
            // チャットビュー時の戻るボタン
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: {
                    withAnimation {
                        viewModel.showChatView = false
                    }
                }) {
                    HStack {
                        Image(systemName: "chevron.left")
                        Text("Back")
                    }
                }
            }
        }
    }
    
    // 画面を閉じるときのクリーンアップ
    private func cleanup() {
        if viewModel.speechService.isPlaying {
            viewModel.speechService.stopSpeaking()
        }
        // 画面を閉じる時にコンテキストをリセット
        viewModel.openAIService.resetConversation()
    }
}

// MARK: - 詳細コンテンツビュー
struct PhotoDetailContent: View {
    let image: UIImage
    @ObservedObject var viewModel: PhotoDetailViewModel
    
    var body: some View {
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
    
    // 画像表示ビュー
    private var imageView: some View {
        Image(uiImage: image)
            .resizable()
            .scaledToFit()
            .cornerRadius(12)
            .padding(.horizontal)
            .accessibilityLabel("Captured photo")
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
        .animation(.easeInOut, value: viewModel.openAIService.isLoading)
        .animation(.easeInOut, value: viewModel.openAIService.error)
        .animation(.easeInOut, value: viewModel.openAIService.imageDescription)
    }
    
    // 質問ボタン
    private var askQuestionButton: some View {
        Button(action: {
            withAnimation {
                viewModel.showChatView = true
            }
        }) {
            HStack {
                Image(systemName: "bubble.left.and.bubble.right.fill")
                Text("Ask AI for Details")
            }
            .padding()
            .frame(maxWidth: .infinity)
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(10)
            .padding(.horizontal)
        }
        .accessibilityHint("Opens a chat interface to ask questions about the image")
    }
}

// MARK: - 画像説明ビュー（最適化版）
struct AnalysisDescriptionView: View {
    let description: String
    let speechService: TextToSpeechService
    let speakAction: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // ヘッダーと読み上げボタン
            HStack {
                Text("Image Description")
                    .font(.headline)
                
                Spacer()
                
                readAloudButton
            }
            .padding(.leading, 8)
            .padding(.trailing)
            
            // 説明テキスト
            Text(description)
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(8)
                .accessibilityLabel("Image description")
        }
    }
    
    // 読み上げボタン
    private var readAloudButton: some View {
        Button(action: speakAction) {
            HStack(spacing: 5) {
                Image(systemName: speechService.isPlaying ? "stop.fill" : "play.fill")
                Text(speechService.isPlaying ? "Stop" : "Speak")
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 12)
            .background(
                Capsule()
                    .fill(speechService.isPlaying ? Color.red : Color.blue)
            )
            .foregroundColor(.white)
            .font(.footnote.bold())
        }
        .accessibilityLabel(speechService.isPlaying ? "Stop speaking" : "Read description aloud")
    }
}

// MARK: - エラービュー（最適化版）
struct AnalysisErrorView: View {
    let error: String
    let retryAction: () -> Void
    
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.largeTitle)
                .foregroundColor(.orange)
                .padding(.bottom, 4)
                .accessibilityHidden(true)
            
            Text("An error occurred")
                .font(.headline)
            
            Text(error)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Button("Retry", action: retryAction)
                .padding(.top, 8)
                .buttonStyle(.borderedProminent)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .padding(.horizontal)
    }
}

#Preview {
    PhotoDetailView(image: UIImage(systemName: "photo")!)
}

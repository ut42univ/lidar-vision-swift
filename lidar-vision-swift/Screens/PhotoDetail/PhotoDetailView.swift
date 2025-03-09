import SwiftUI

/// 写真詳細画面
struct PhotoDetailView: View {
    let image: UIImage
    @StateObject private var viewModel: PhotoDetailViewModel
    @Environment(\.dismiss) private var dismiss
    
    init(image: UIImage) {
        self.image = image
        _viewModel = StateObject(wrappedValue: PhotoDetailViewModel(image: image))
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // 画像表示部分
                    imageView
                    
                    // ステータス表示部分
                    statusContent
                    
                    // 読み上げ設定セクション
                    if !viewModel.openAIService.imageDescription.isEmpty && viewModel.speechService.isPlaying {
                        speechSettingsView
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle("Photo Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    closeButton
                }
                
                if shouldShowAnalyzeButton {
                    ToolbarItem(placement: .bottomBar) {
                        analyzeButton
                    }
                }
            }
        }
        .onDisappear {
            if viewModel.speechService.isPlaying {
                viewModel.speechService.stopSpeaking()
            }
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
    
    // 読み上げ設定ビュー
    private var speechSettingsView: some View {
        SpeechSettingsView(
            speechService: viewModel.speechService,
            description: viewModel.openAIService.imageDescription
        )
    }
    
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

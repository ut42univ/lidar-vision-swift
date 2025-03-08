import SwiftUI

struct PhotoDetailView: View {
    let image: UIImage
    @StateObject private var openAIManager = OpenAIManager(apiKey: EnvironmentManager.openAIAPIKey)
    @StateObject private var speechManager = TextToSpeechManager()
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // 画像表示部分
                    PhotoImageView(image: image)
                    
                    // ステータス表示部分（ローディング、エラー、説明）
                    StatusContentView(
                        openAIManager: openAIManager,
                        speechManager: speechManager,
                        image: image
                    )
                    
                    // 読み上げ設定セクション
                    if !openAIManager.imageDescription.isEmpty && speechManager.isPlaying {
                        SpeechSettingsView(
                            speechManager: speechManager,
                            description: openAIManager.imageDescription
                        )
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle("Photo Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        // 画面を閉じる前に読み上げを停止
                        if speechManager.isPlaying {
                            speechManager.stopSpeaking()
                        }
                        dismiss()
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                }
                
                if openAIManager.imageDescription.isEmpty && openAIManager.error == nil && !openAIManager.isLoading {
                    ToolbarItem(placement: .bottomBar) {
                        Button("Analyze Image with AI") {
                            openAIManager.analyzeImage(image)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                    }
                }
            }
        }
        .onAppear {
            // Uncomment to perform automatic analysis
            // openAIManager.analyzeImage(image)
        }
        .onDisappear {
            // 画面が非表示になる際に読み上げを停止
            if speechManager.isPlaying {
                speechManager.stopSpeaking()
            }
        }
    }
}

// 画像表示コンポーネント
struct PhotoImageView: View {
    let image: UIImage
    
    var body: some View {
        Image(uiImage: image)
            .resizable()
            .scaledToFit()
            .cornerRadius(12)
            .padding(.horizontal)
    }
}

// ステータス表示コンポーネント
struct StatusContentView: View {
    @ObservedObject var openAIManager: OpenAIManager
    let speechManager: TextToSpeechManager
    let image: UIImage
    
    var body: some View {
        Group {
            if openAIManager.isLoading {
                ProgressView("Analyzing image...")
                    .padding()
            } else if let error = openAIManager.error {
                ErrorView(error: error) {
                    openAIManager.analyzeImage(image)
                }
            } else if !openAIManager.imageDescription.isEmpty {
                ImageDescriptionView(
                    description: openAIManager.imageDescription,
                    speechManager: speechManager
                )
                .padding(.horizontal)
            }
        }
    }
}

// エラー表示コンポーネント
struct ErrorView: View {
    let error: String
    let retryAction: () -> Void
    
    var body: some View {
        VStack {
            Image(systemName: "exclamationmark.triangle")
                .font(.largeTitle)
                .foregroundColor(.orange)
                .padding(.bottom, 4)
            
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
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
        .padding(.horizontal)
    }
}

// 読み上げ設定コンポーネント
struct SpeechSettingsView: View {
    @ObservedObject var speechManager: TextToSpeechManager
    let description: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("読み上げ設定")
                .font(.headline)
                .padding(.leading, 8)
            
            VStack(spacing: 15) {
                // 速度調整スライダー
                VStack(alignment: .leading) {
                    Text("速度: \(Int(speechManager.rate * 100))%")
                        .font(.caption)
                    Slider(value: $speechManager.rate, in: 0.1...1.0) { _ in
                        if speechManager.isPlaying {
                            speechManager.stopSpeaking()
                            speechManager.speak(text: description)
                        }
                    }
                }
                
                // 音量調整スライダー
                VStack(alignment: .leading) {
                    Text("音量: \(Int(speechManager.volume * 100))%")
                        .font(.caption)
                    Slider(value: $speechManager.volume, in: 0.1...1.0) { _ in
                        if speechManager.isPlaying {
                            speechManager.stopSpeaking()
                            speechManager.speak(text: description)
                        }
                    }
                }
                
                // 言語選択
                HStack {
                    Text("言語:")
                        .font(.caption)
                    
                    Picker("言語", selection: $speechManager.language) {
                        Text("日本語").tag("ja-JP")
                        Text("英語").tag("en-US")
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .onChange(of: speechManager.language) {
                        if speechManager.isPlaying {
                            speechManager.stopSpeaking()
                            speechManager.speak(text: description)
                        }
                    }
                }
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(8)
        }
        .padding(.horizontal)
        .transition(.opacity)
        .animation(.easeInOut, value: speechManager.isPlaying)
    }
}

// 抽出された画像説明コンポーネント
struct ImageDescriptionView: View {
    let description: String
    let speechManager: TextToSpeechManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ImageDescriptionHeaderView(description: description, speechManager: speechManager)
            
            Text(description)
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)
        }
    }
}

// 説明ヘッダーと読み上げボタン
struct ImageDescriptionHeaderView: View {
    let description: String
    let speechManager: TextToSpeechManager
    
    var body: some View {
        HStack {
            Text("Image Description")
                .font(.headline)
            
            Spacer()
            
            ReadAloudButton(description: description, speechManager: speechManager)
        }
        .padding(.leading, 8)
        .padding(.trailing)
    }
}

// 読み上げボタンコンポーネント
struct ReadAloudButton: View {
    let description: String
    let speechManager: TextToSpeechManager
    
    var body: some View {
        Button(action: {
            if speechManager.isPlaying {
                speechManager.stopSpeaking()
            } else {
                speechManager.speakWithAutoLanguageDetection(text: description)
            }
        }) {
            HStack(spacing: 5) {
                Image(systemName: speechManager.isPlaying ? "stop.fill" : "play.fill")
                Text(speechManager.isPlaying ? "停止" : "読み上げ")
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 12)
            .background(
                Capsule()
                    .fill(speechManager.isPlaying ? Color.red : Color.blue)
            )
            .foregroundColor(.white)
            .font(.footnote.bold())
        }
    }
}

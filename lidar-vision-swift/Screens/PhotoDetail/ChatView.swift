import SwiftUI
import Speech

/// AIとの会話インターフェース（音声入力対応）
struct ChatView: View {
    @ObservedObject var openAIService: OpenAIService
    @ObservedObject var speechService: TextToSpeechService
    @State private var questionText: String = ""
    @State private var isRecording: Bool = false
    @State private var isInputExpanded: Bool = false
    @State private var speechRecognizer = SpeechRecognizer()
    @FocusState private var isInputFocused: Bool
    @State private var scrollToBottom: Bool = false
    
    var body: some View {
        VStack(spacing: 0) {
            // メッセージリスト
            ScrollViewReader { scrollView in
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(openAIService.messages) { message in
                            MessageBubble(
                                message: message,
                                speechService: speechService
                            )
                        }
                        
                        // 自動スクロール用のアンカー
                        Color.clear
                            .frame(height: 1)
                            .id("bottomAnchor")
                    }
                    .padding(.top, 8)
                    .padding(.horizontal)
                }
                .onChange(of: openAIService.messages.count) {
                    withAnimation {
                        scrollView.scrollTo("bottomAnchor", anchor: .bottom)
                    }
                }
                .onChange(of: scrollToBottom) {
                    withAnimation {
                        scrollView.scrollTo("bottomAnchor", anchor: .bottom)
                    }
                }
            }
            
            Divider()
            
            // 入力エリア
            VStack(spacing: 8) {
                // テキスト入力フィールド
                HStack(spacing: 8) {
                    TextField("Ask AI a qustion...", text: $questionText)
                        .padding(10)
                        .background(Color(.systemGray6))
                        .cornerRadius(20)
                        .focused($isInputFocused)
                        .disabled(openAIService.isLoading || isRecording)
                        .overlay(
                            Group {
                                if isRecording {
                                    HStack {
                                        Spacer()
                                        Circle()
                                            .fill(Color.red)
                                            .frame(width: 8, height: 8)
                                            .padding(.trailing, 12)
                                    }
                                }
                            }
                        )
                    
                    // 送信ボタン
                    Button(action: sendQuestion) {
                        Image(systemName: openAIService.isLoading ? "circle.dotted" : "arrow.up.circle.fill")
                            .font(.system(size: 30))
                            .foregroundColor(questionText.isEmpty || openAIService.isLoading || isRecording ? .gray : .blue)
                    }
                    .disabled(questionText.isEmpty || openAIService.isLoading || isRecording)
                    
                    // 音声入力ボタン
                    Button(action: toggleVoiceInput) {
                        Image(systemName: isRecording ? "mic.fill.badge.xmark" : "mic.fill")
                            .font(.system(size: 24))
                            .foregroundColor(isRecording ? .red : .blue)
                            .padding(6)
                    }
                    .disabled(openAIService.isLoading)
                }
                
                // 音声入力中のガイダンス
                if isRecording {
                    Text("Recognizing voice... (Tap to stop)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.vertical, 4)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            
            // ローディングインジケータ
            if openAIService.isLoading {
                HStack {
                    ProgressView()
                        .scaleEffect(0.7)
                    Text("Thinking...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(height: 30)
                .padding(.bottom, 4)
            } else {
                Color.clear.frame(height: 30) // スペースを確保
            }
        }
        .background(Color(.systemBackground))
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                scrollToBottom.toggle()
            }
        }
        .onChange(of: speechRecognizer.transcript) { newValue, _ in
            if !newValue.isEmpty {
                questionText = newValue
            }
        }
        .onChange(of: speechRecognizer.isFinished) { isFinished, _ in
            if isFinished && !speechRecognizer.transcript.isEmpty {
                // 認識が終了し、テキストがある場合は自動送信
                isRecording = false
                sendQuestion()
            }
        }
    }
    
    private func sendQuestion() {
        guard !questionText.isEmpty else { return }
        let question = questionText
        questionText = ""
        openAIService.sendQuestion(question)
        isInputFocused = false
    }
    
    private func toggleVoiceInput() {
        isRecording.toggle()
        
        if isRecording {
            // 音声認識開始
            speechRecognizer.resetTranscript()
            speechRecognizer.startTranscribing()
            // 触覚フィードバック
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        } else {
            // 音声認識停止
            speechRecognizer.stopTranscribing()
        }
    }
}

/// メッセージバブルコンポーネント
struct MessageBubble: View {
    let message: ChatMessage
    @ObservedObject var speechService: TextToSpeechService
    @State private var isPlaying = false
    
    var body: some View {
        HStack(alignment: .top) {
            if !message.isUser {
                // AIアイコン
                Image(systemName: "brain")
                    .font(.system(size: 20))
                    .foregroundColor(.white)
                    .padding(8)
                    .background(Color.purple)
                    .clipShape(Circle())
            }
            
            VStack(alignment: message.isUser ? .trailing : .leading, spacing: 2) {
                HStack {
                    Text(message.isUser ? "You" : "AI")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if !message.isUser {
                        Button(action: {
                            toggleSpeech(message.content)
                        }) {
                            Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                                .foregroundColor(.blue)
                                .font(.system(size: 18))
                        }
                    }
                }
                
                Text(message.content)
                    .padding(10)
                    .background(message.isUser ? Color.blue : Color(.systemGray5))
                    .foregroundColor(message.isUser ? .white : .primary)
                    .cornerRadius(16)
            }
            
            if message.isUser {
                // ユーザーアイコン
                Image(systemName: "person.circle.fill")
                    .font(.system(size: 24))
                    .foregroundColor(.blue)
            }
        }
        .frame(maxWidth: .infinity, alignment: message.isUser ? .trailing : .leading)
        .padding(.vertical, 4)
        .onAppear {
            // このメッセージの再生状態を確認
            isPlaying = speechService.isPlaying && speechService.currentText == message.content
        }
        .onChange(of: speechService.isPlaying) { newValue, _ in
            // 再生状態が変わったときに、このメッセージの再生状態を更新
            isPlaying = newValue && speechService.currentText == message.content
        }
    }
    
    private func toggleSpeech(_ text: String) {
        if isPlaying {
            speechService.stopSpeaking()
            isPlaying = false
        } else {
            speechService.speak(text: text)
            isPlaying = true
        }
    }
}

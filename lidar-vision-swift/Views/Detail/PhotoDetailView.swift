import SwiftUI

struct PhotoDetailView: View {
    // Input properties
    let image: UIImage

    // ViewModel
    @StateObject private var viewModel: PhotoDetailViewModel

    // Environment
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.horizontalSizeClass) var horizontalSizeClass

    // UI State
    @State private var messageText: String = ""
    @State private var keyboardHeight: CGFloat = 0
    @State private var isRecording: Bool = false
    @State private var scrollToBottom: Bool = false
    @State private var speechRecognizer = SpeechRecognizer()
    @FocusState private var isInputFocused: Bool

    // Design Constants
    private let cornerRadius: CGFloat = 20
    private let standardPadding: CGFloat = 20

    init(image: UIImage, autoAnalyze: Bool = true) {
        self.image = image
        _viewModel = StateObject(wrappedValue: PhotoDetailViewModel(image: image, autoAnalyze: autoAnalyze))
    }

    var body: some View {
        ZStack {
            Color(.systemBackground)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                topControlBar
                conversationSection
            }
        }
        .onTapGesture {
            isInputFocused = false
        }
        .onAppear {
            addKeyboardObservers()
        }
        .onDisappear {
            cleanup()
            removeKeyboardObservers()
        }
        .onChange(of: speechRecognizer.transcript) { newValue, _ in
            if !newValue.isEmpty { messageText = newValue }
        }
        .onChange(of: speechRecognizer.isFinished) { isFinished, _ in
            if isFinished && !speechRecognizer.transcript.isEmpty {
                isRecording = false
                sendMessage()
            }
        }
        .onChange(of: viewModel.openAIService.messages.count) { _, _ in
            scrollToBottom.toggle()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .navigationBarHidden(true)
        .environment(\.dynamicTypeSize, .large)
    }

    // MARK: - Top Control Bar
    private var topControlBar: some View {
        ZStack {
            // Back button (left aligned)
            HStack {
                Button(action: dismiss.callAsFunction) {
                    HStack(spacing: 6) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 18, weight: .semibold, design: .rounded))
                        Text("Back")
                            .font(.system(.body, design: .rounded).weight(.medium))
                    }
                    .foregroundColor(.accentColor)
                    .padding(.vertical, 10)
                    .padding(.horizontal, 14)
                    .background(thinMaterialBackground)
                    .cornerRadius(20)
                }
                .accessibilityLabel("Go back")
                .accessibilityHint("Returns to the camera view")

                Spacer()
            }
            
            // Title (center aligned)
            Text("AI Vision Analysis")
                .font(.headline)
                .fontWeight(.semibold)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .frame(maxWidth: UIScreen.main.bounds.width * 0.6) // Limit width for larger screens
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier("screenTitle")
        }
        .padding(.horizontal, standardPadding)
        .padding(.top, 16)
        .padding(.bottom, 12)
    }

    // MARK: - Image Section
    private var imageSection: some View {
        VStack {
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(maxHeight: horizontalSizeClass == .regular
                        ? UIScreen.main.bounds.height * 0.45
                        : UIScreen.main.bounds.height * 0.35)
                .clipped()
                .cornerRadius(cornerRadius)
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .stroke(Color(.systemGray4).opacity(0.5), lineWidth: 1)
                )
                .accessibilityLabel("Photo to be analyzed")
        }
        .padding(.horizontal, standardPadding)
        .padding(.vertical, 10)
    }

    // MARK: - Status Indicator
    private var statusIndicator: some View {
        HStack(spacing: 12) {
            ProgressView().scaleEffect(0.9)
            Text("Analyzing image...")
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundColor(.primary)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 20)
        .background(thinMaterialBackground)
        .cornerRadius(25)
        .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
        .padding(.bottom, 16)
    }

    // MARK: - Conversation Section
    private var conversationSection: some View {
        ZStack {
            Color(colorScheme == .light ? .white : .black)
                .opacity(0.95)
                .ignoresSafeArea(edges: .bottom)
            VStack(spacing: 0) {
                if let error = viewModel.openAIService.error {
                    ErrorView(error: error) { viewModel.analyzeImage() }
                        .padding(.top, standardPadding)
                        .padding(.horizontal, standardPadding)
                } else if viewModel.openAIService.messages.isEmpty && !viewModel.openAIService.isLoading {
                    VStack {
                        Spacer()
                        Button(action: {
                            viewModel.analyzeImage()
                            hapticFeedback(.medium)
                        }) {
                            HStack(spacing: 12) {
                                Image(systemName: "brain")
                                    .font(.system(size: 20, design: .rounded))
                                Text("Analyze with AI")
                                    .font(.system(.body, design: .rounded).weight(.semibold))
                            }
                            .padding(.vertical, 14)
                            .padding(.horizontal, 24)
                            .background(Capsule().fill(Color.accentColor))
                            .foregroundColor(.white)
                        }
                        .buttonStyle(ScaleButtonStyle())
                        .accessibilityLabel("Analyze image with AI")
                        Spacer()
                    }
                } else {
                    chatScrollView
                    messageInputBar
                }
            }
        }
    }

    // MARK: - Chat Scroll View
    private var chatScrollView: some View {
        ScrollViewReader { scrollView in
            ScrollView {
                LazyVStack(spacing: 16) {
                    imageSection
                    ForEach(viewModel.openAIService.messages) { message in
                        MessageBubble(message: message,
                                      speechService: viewModel.speechService)
                            .padding(.horizontal, 10)
                    }
                    Color.clear.frame(height: 1).id("bottomAnchor")
                }
                .padding(.top, standardPadding)
                .padding(.bottom, 8)
            }
            .coordinateSpace(name: "chatScroll")
            .onChange(of: scrollToBottom) { _, _ in
                withAnimation {
                    scrollView.scrollTo("bottomAnchor", anchor: .bottom)
                }
            }
            // キーボードが表示されたときに自動的に一番下にスクロール
            .onChange(of: keyboardHeight) { newValue, _ in
                if newValue > 0 {
                    withAnimation {
                        scrollView.scrollTo("bottomAnchor", anchor: .bottom)
                    }
                }
            }
        }
    }

    // MARK: - Message Input Bar
    private var messageInputBar: some View {
        VStack(spacing: 8) {
            Rectangle()
                .fill(Color(.systemGray4).opacity(0.3))
                .frame(height: 0.5)
                .padding(.horizontal, 10)
            HStack(spacing: 12) {
                // 入力フィールド
                ZStack(alignment: .trailing) {
                    TextField("Ask about this image...", text: $messageText)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(
                            thinMaterialBackground.clipShape(RoundedRectangle(cornerRadius: 25))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 25)
                                .stroke(Color(.systemGray3), lineWidth: 1)
                        )
                        .focused($isInputFocused)
                        .disabled(viewModel.openAIService.isLoading || isRecording)
                        .font(.system(.body, design: .rounded))
                        .submitLabel(.send) // Return キーを送信ボタンに
                        .onSubmit {
                            if !messageText.isEmpty && !viewModel.openAIService.isLoading && !isRecording {
                                sendMessage()
                            }
                        }
                        .accessibilityLabel("Chat input field")
                    
                    if isRecording {
                        Circle()
                            .fill(Color.red)
                            .frame(width: 8, height: 8)
                            .padding(.trailing, 16)
                            .accessibilityLabel("Recording in progress")
                    }
                }

                // マイクボタン
                Button(action: toggleVoiceInput) {
                    Image(systemName: isRecording ? "mic.fill.badge.xmark" : "mic.fill")
                        .font(.system(size: 22, design: .rounded))
                        .foregroundColor(.white)
                        .padding(12)
                        .background(Circle().fill(isRecording ? Color.red : Color.blue))
                }
                .disabled(viewModel.openAIService.isLoading)
                .accessibilityLabel(isRecording ? "Stop Recording" : "Start Recording")
                
                // 送信ボタン
                Button(action: sendMessage) {
                    Image(systemName: "arrow.up")
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)
                        .padding(12)
                        .background(
                            Circle().fill(
                                messageText.isEmpty ||
                                viewModel.openAIService.isLoading ||
                                isRecording
                                ? Color.gray.opacity(0.6)
                                : Color.accentColor
                            )
                        )
                }
                .disabled(messageText.isEmpty ||
                          viewModel.openAIService.isLoading ||
                          isRecording)
                .accessibilityLabel("Send message")
            }
            .padding(.horizontal, standardPadding)
            .padding(.vertical, 10)
            
            if isRecording || viewModel.openAIService.isLoading {
                statusBar
            }
            
            // キーボードの高さに合わせたスペーサー
            Spacer().frame(height: keyboardHeight > 0 ? 0 : 12)
        }
    }
    
    // ステータスバー
    private var statusBar: some View {
        HStack(spacing: 10) {
            if isRecording {
                HStack(spacing: 6) {
                    Circle().fill(Color.red).frame(width: 6, height: 6)
                    Text("Listening...")
                        .font(.system(size: 13, design: .rounded).weight(.medium))
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 4)
                .padding(.horizontal, 12)
                .background(thinMaterialBackground)
                .cornerRadius(15)
                .accessibilityLabel("Voice recognition active")
            }
            if viewModel.openAIService.isLoading {
                HStack(spacing: 8) {
                    ProgressView().scaleEffect(0.7)
                    Text("AI is thinking...")
                        .font(.system(size: 13, design: .rounded).weight(.medium))
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 4)
                .padding(.horizontal, 12)
                .background(thinMaterialBackground)
                .cornerRadius(15)
                .accessibilityLabel("AI is analyzing or responding")
            }
        }
        .padding(.vertical, 4)
    }

    // MARK: - Thin Material Background
    private var thinMaterialBackground: some View {
        Group {
            if #available(iOS 15.0, *) {
                Color.clear.background(.thinMaterial)
            } else {
                Color(.systemBackground).opacity(0.7).blur(radius: 3)
            }
        }
    }

    // MARK: - Actions
    private func sendMessage() {
        let trimmedText = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else {
            messageText = ""
            return
        }
        viewModel.openAIService.sendQuestion(trimmedText)
        messageText = ""
        isInputFocused = false
    }

    private func toggleVoiceInput() {
        isRecording.toggle()
        if isRecording {
            speechRecognizer.resetTranscript()
            speechRecognizer.startTranscribing()
            hapticFeedback(.medium)
        } else {
            speechRecognizer.stopTranscribing()
        }
    }

    private func cleanup() {
        if viewModel.speechService.isPlaying {
            viewModel.speechService.stopSpeaking()
        }
        viewModel.openAIService.resetConversation()
    }

    private func hapticFeedback(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        UIImpactFeedbackGenerator(style: style).impactOccurred()
    }

    // MARK: - Keyboard Handling - 改善版
    private func addKeyboardObservers() {
        let notificationCenter = NotificationCenter.default
        
        // キーボード表示の処理を最適化
        notificationCenter.addObserver(
            forName: UIResponder.keyboardWillShowNotification,
            object: nil,
            queue: .main
        ) { notification in
            // キーボードサイズを取得
            if let keyboardFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect {
                // 安全エリアを考慮した高さの計算 - iOS 15以降に対応
                let bottomPadding: CGFloat
                if #available(iOS 15.0, *) {
                    // iOS 15以降はUIWindowSceneを使用
                    let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene
                    bottomPadding = windowScene?.windows.first?.safeAreaInsets.bottom ?? 0
                } else {
                    // iOS 15未満は従来の方法を使用
                    bottomPadding = UIApplication.shared.windows.first?.safeAreaInsets.bottom ?? 0
                }
                
                // アニメーション情報を取得
                if let animationDuration = notification.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? TimeInterval,
                   let animationCurveValue = notification.userInfo?[UIResponder.keyboardAnimationCurveUserInfoKey] as? UInt {
                    
                    let animationCurve = UIView.AnimationCurve(rawValue: Int(animationCurveValue)) ?? .easeInOut
                    
                    // UIViewの標準アニメーションを使用して同期
                    withAnimation(.timingCurve(
                        animationCurve == .easeIn ? 0.42 : 0.0,
                        animationCurve == .easeOut ? 0.58 : 0.0,
                        animationCurve == .linear ? 1.0 : 0.5,
                        animationCurve == .linear ? 1.0 : 1.0,
                        duration: animationDuration
                    )) {
                        self.keyboardHeight = keyboardFrame.height - bottomPadding
                        self.scrollToBottom.toggle()
                    }
                } else {
                    // アニメーション情報がない場合はデフォルトで
                    withAnimation(.easeOut(duration: 0.25)) {
                        self.keyboardHeight = keyboardFrame.height - bottomPadding
                        self.scrollToBottom.toggle()
                    }
                }
            }
        }
        
        // キーボードが非表示になるときの処理も最適化
        notificationCenter.addObserver(
            forName: UIResponder.keyboardWillHideNotification,
            object: nil,
            queue: .main
        ) { notification in
            // アニメーション情報を取得
            if let animationDuration = notification.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? TimeInterval,
               let animationCurveValue = notification.userInfo?[UIResponder.keyboardAnimationCurveUserInfoKey] as? UInt {
                
                let animationCurve = UIView.AnimationCurve(rawValue: Int(animationCurveValue)) ?? .easeInOut
                
                // UIViewの標準アニメーションを使用して同期
                withAnimation(.timingCurve(
                    animationCurve == .easeIn ? 0.42 : 0.0,
                    animationCurve == .easeOut ? 0.58 : 0.0,
                    animationCurve == .linear ? 1.0 : 0.5,
                    animationCurve == .linear ? 1.0 : 1.0,
                    duration: animationDuration
                )) {
                    self.keyboardHeight = 0
                }
            } else {
                // アニメーション情報がない場合はデフォルトで
                withAnimation(.easeOut(duration: 0.25)) {
                    self.keyboardHeight = 0
                }
            }
        }
    }

    private func removeKeyboardObservers() {
        NotificationCenter.default.removeObserver(self)
    }
}

#Preview {
    NavigationView {
        PhotoDetailView(image: UIImage(systemName: "photo")!)
    }
}

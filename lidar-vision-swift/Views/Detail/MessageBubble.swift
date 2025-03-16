import SwiftUI

struct MessageBubble: View {
    let message: ChatMessage
    @ObservedObject var speechService: TextToSpeechService
    
    // isPlayingの状態を管理
    @State private var isPlaying: Bool = false
    
    // アニメーション用の状態
    @State private var buttonScale: CGFloat = 1.0
    
    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            // AI icon (only for AI messages)
            if !message.isUser {
                ZStack {
                    Circle()
                        .fill(Color.purple)
                        .frame(width: 32, height: 32)
                        .shadow(color: Color.purple.opacity(0.3), radius: 3, x: 0, y: 2)
                    
                    Image(systemName: "brain")
                        .font(.system(size: 16))
                        .foregroundColor(.white)
                }
            }
            
            VStack(alignment: message.isUser ? .trailing : .leading, spacing: 4) {
                // Message header
                HStack(spacing: 6) {
                    Text(message.isUser ? "You" : "AI Assistant")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                    
                    if !message.isUser {
                        // Time indicator
                        Text(formatTimestamp(message.timestamp))
                            .font(.system(size: 10))
                            .foregroundColor(.secondary.opacity(0.7))
                        
                        // 再生・停止ボタン
                        Button(action: {
                            // タップ時のアニメーション
                            withAnimation(.spring(response: 0.2, dampingFraction: 0.5)) {
                                buttonScale = 0.85
                            }
                            
                            // 遅延を設けて元のサイズに戻す
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                                withAnimation(.spring(response: 0.2, dampingFraction: 0.5)) {
                                    buttonScale = 1.0
                                }
                            }
                            
                            // 音声の再生・停止を切り替え
                            toggleSpeech(message.content)
                        }) {
                            Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                                .foregroundColor(.blue)
                                .font(.system(size: 22))
                                .scaleEffect(buttonScale)
                                .padding(4)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(PlainButtonStyle())
                        .accessibilityLabel(isPlaying ? "Stop speaking" : "Play message")
                    }
                }
                .padding(.horizontal, 8)
                .padding(.top, 2)
                
                // Message content with enhanced styling
                Text(message.content)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(
                        message.isUser
                            ? LinearGradient(
                                gradient: Gradient(colors: [Color.blue, Color.blue.opacity(0.9)]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                              )
                            : LinearGradient(
                                gradient: Gradient(colors: [Color(.systemGray6).opacity(0.8), Color(.systemGray6).opacity(0.75)]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                              )
                    )
                    .foregroundColor(message.isUser ? .white : .primary)
                    .cornerRadius(18)
            }
            .frame(maxWidth: UIScreen.main.bounds.width * 0.75, alignment: message.isUser ? .trailing : .leading)
            
            // User icon (only for user messages)
            if message.isUser {
                ZStack {
                    Circle()
                        .fill(Color.blue.opacity(0.1))
                        .frame(width: 32, height: 32)
                    
                    Image(systemName: "person.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.blue)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: message.isUser ? .trailing : .leading)
        .padding(.vertical, 4)
        .onAppear {
            // 表示時に再生状態をチェック
            updatePlayingState()
        }
        .onChange(of: speechService.isPlaying) { _, _ in
            // TextToSpeechServiceの状態変化を監視
            updatePlayingState()
        }
        .onChange(of: speechService.currentText) { _, _ in
            // テキスト変更時も状態を更新
            updatePlayingState()
        }
    }
    
    private func toggleSpeech(_ text: String) {
        if isPlaying {
            speechService.stopSpeaking()
        } else {
            speechService.speak(text: text)
        }
    }
    
    // 再生状態の更新を一箇所にまとめる
    private func updatePlayingState() {
        isPlaying = speechService.isPlaying && speechService.currentText == message.content
    }
    
    // Format timestamp to human-readable format
    private func formatTimestamp(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}
// プレビュー用の拡張
#Preview {
    VStack(spacing: 20) {
        MessageBubble(
            message: ChatMessage(content: "This is a test message from the user", isUser: true),
            speechService: TextToSpeechService()
        )
        
        MessageBubble(
            message: ChatMessage(content: "This is a response from the AI assistant with a longer text that might wrap to multiple lines", isUser: false),
            speechService: TextToSpeechService()
        )
    }
    .padding()
}

import SwiftUI

struct MessageBubble: View {
    let message: ChatMessage
    @ObservedObject var speechService: TextToSpeechService
    @State private var isPlaying = false
    
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
                        
                        // Play button for AI messages
                        Button(action: {
                            toggleSpeech(message.content)
                        }) {
                            Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                                .foregroundColor(.blue)
                                .font(.system(size: 16))
                        }
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
            // Check play status when view appears
            isPlaying = speechService.isPlaying && speechService.currentText == message.content
        }
        .onChange(of: speechService.isPlaying) { newValue, _ in
            // Update play status when speech service changes
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
    
    // Format timestamp to human-readable format
    private func formatTimestamp(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}
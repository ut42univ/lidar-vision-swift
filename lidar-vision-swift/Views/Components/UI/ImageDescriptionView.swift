import SwiftUI

/// 画像の説明を表示するコンポーネント
struct ImageDescriptionView: View {
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
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)
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
    }
}

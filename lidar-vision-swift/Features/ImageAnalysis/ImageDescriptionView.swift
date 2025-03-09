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
                Text(speechService.isPlaying ? "停止" : "読み上げ")
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

/// エラー表示コンポーネント
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

/// 読み上げ設定コンポーネント
struct SpeechSettingsView: View {
    @ObservedObject var speechService: TextToSpeechService
    let description: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("読み上げ設定")
                .font(.headline)
                .padding(.leading, 8)
            
            VStack(spacing: 15) {
                // 速度調整スライダー
                speedSettingSlider
                
                // 音量調整スライダー
                volumeSettingSlider
                
                // 言語選択
                languagePicker
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(8)
        }
        .padding(.horizontal)
        .transition(.opacity)
        .animation(.easeInOut, value: speechService.isPlaying)
    }
    
    // 速度調整スライダー
    private var speedSettingSlider: some View {
        VStack(alignment: .leading) {
            Text("速度: \(Int(speechService.rate * 100))%")
                .font(.caption)
            
            Slider(value: $speechService.rate, in: 0.1...1.0) { _ in
                if speechService.isPlaying {
                    speechService.stopSpeaking()
                    speechService.speak(text: description)
                }
            }
        }
    }
    
    // 音量調整スライダー
    private var volumeSettingSlider: some View {
        VStack(alignment: .leading) {
            Text("音量: \(Int(speechService.volume * 100))%")
                .font(.caption)
            
            Slider(value: $speechService.volume, in: 0.1...1.0) { _ in
                if speechService.isPlaying {
                    speechService.stopSpeaking()
                    speechService.speak(text: description)
                }
            }
        }
    }
    
    // 言語選択
    private var languagePicker: some View {
        HStack {
            Text("言語:")
                .font(.caption)
            
            Picker("言語", selection: $speechService.language) {
                Text("日本語").tag("ja-JP")
                Text("英語").tag("en-US")
            }
            .pickerStyle(SegmentedPickerStyle())
            .onChange(of: speechService.language) {
                if speechService.isPlaying {
                    speechService.stopSpeaking()
                    speechService.speak(text: description)
                }
            }
        }
    }
}

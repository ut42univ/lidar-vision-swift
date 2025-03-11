import Foundation
import AVFoundation
import Speech
import SwiftUI

/// 音声認識クラス
class SpeechRecognizer: NSObject, ObservableObject, SFSpeechRecognizerDelegate {
    
    @Published var transcript: String = ""
    @Published var isAvailable: Bool = false
    @Published var isFinished: Bool = false
    @Published var isListening: Bool = false
    
    // プライベート変数
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
    
    override init() {
        super.init()
        speechRecognizer?.delegate = self
        
        // 音声認識の認可状態を確認
        SFSpeechRecognizer.requestAuthorization { [weak self] (authStatus) in
            DispatchQueue.main.async {
                switch authStatus {
                case .authorized:
                    self?.isAvailable = true
                case .denied, .restricted, .notDetermined:
                    self?.isAvailable = false
                @unknown default:
                    self?.isAvailable = false
                }
            }
        }
    }
    
    func startTranscribing() {
        resetTranscript()
        
        // 既存のタスクがあれば終了
        if recognitionTask != nil {
            recognitionTask?.cancel()
            recognitionTask = nil
        }
        
        // オーディオセッションを設定
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            print("Audio session setup failed: \(error.localizedDescription)")
            return
        }
        
        // 認識リクエストを作成
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        
        // 入力ノードを取得（現在の API では inputNode は Optional ではない）
        let inputNode = audioEngine.inputNode
        
        // リクエストが作成されていることを確認
        guard let recognitionRequest = recognitionRequest else {
            print("Unable to create a SFSpeechAudioBufferRecognitionRequest object")
            return
        }
        
        // 途中結果も取得
        recognitionRequest.shouldReportPartialResults = true
        
        // 音声認識タスクの作成
        recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            guard let self = self else { return }
            
            var isFinal = false
            
            if let result = result {
                // テキストの設定
                DispatchQueue.main.async {
                    self.transcript = result.bestTranscription.formattedString
                }
                isFinal = result.isFinal
            }
            
            // エラーまたは最終結果の場合
            if error != nil || isFinal {
                self.audioEngine.stop()
                inputNode.removeTap(onBus: 0)
                
                self.recognitionRequest = nil
                self.recognitionTask = nil
                
                DispatchQueue.main.async {
                    self.isListening = false
                    self.isFinished = true
                }
            }
        }
        
        // マイクからのオーディオをタップして認識リクエストに追加
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { (buffer, when) in
            self.recognitionRequest?.append(buffer)
        }
        
        // オーディオエンジン準備と開始
        do {
            audioEngine.prepare()
            try audioEngine.start()
            isListening = true
            isFinished = false
        } catch {
            print("Audio engine failed to start: \(error.localizedDescription)")
        }
    }
    
    func stopTranscribing() {
        audioEngine.stop()
        recognitionRequest?.endAudio()
        isListening = false
        
        // 少し待ってから認識終了とマーク
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.isFinished = true
        }
    }
    
    func resetTranscript() {
        transcript = ""
        isFinished = false
    }
    
    // SFSpeechRecognizerDelegateメソッド
    func speechRecognizer(_ speechRecognizer: SFSpeechRecognizer, availabilityDidChange available: Bool) {
        DispatchQueue.main.async {
            self.isAvailable = available
        }
    }
    
    deinit {
        audioEngine.stop()
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
    }
}

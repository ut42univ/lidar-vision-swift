import Foundation
import AVFoundation
import Speech
import SwiftUI
import Combine

/// 音声認識クラス
@MainActor
class SpeechRecognizer: NSObject, ObservableObject {
    
    // MARK: - プロパティ
    
    // 認識結果
    @Published var transcript: String = ""
    @Published var isAvailable: Bool = false
    @Published var isFinished: Bool = false
    @Published var isListening: Bool = false
    
    // エラー処理
    @Published var errorMessage: String? = nil
    
    // プライベート変数
    private let speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - 初期化
    
    override init() {
        // 指定された言語の認識器を初期化
        self.speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
        
        super.init()
        
        // 認識器の初期設定
        setup()
    }
    
    /// 指定された言語で初期化
    convenience init(locale: Locale) {
        self.init()
        
        // ロケールが変更された場合の対応
        if let recognizer = SFSpeechRecognizer(locale: locale) {
            speechRecognizer?.delegate = nil
            recognizer.delegate = self
        }
    }
    
    // MARK: - セットアップ
    
    private func setup() {
        speechRecognizer?.delegate = self
        
        // 音声認識の認可状態を非同期で確認
        Task {
            await checkAuthorization()
        }
        
        // アプリのライフサイクルを監視して認識を自動停止
        setupAppLifecycleObservers()
    }
    
    private func setupAppLifecycleObservers() {
        // アプリがバックグラウンドに移行したら音声認識を停止
        NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)
            .sink { [weak self] _ in
                if self?.isListening == true {
                    self?.stopTranscribing()
                }
            }
            .store(in: &cancellables)
        
        // オーディオセッションが中断されたら音声認識を停止
        NotificationCenter.default.publisher(for: AVAudioSession.interruptionNotification)
            .sink { [weak self] notification in
                guard let self = self, self.isListening else { return }
                
                // 中断タイプを確認
                if let userInfo = notification.userInfo,
                   let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
                   let type = AVAudioSession.InterruptionType(rawValue: typeValue) {
                    
                    if type == .began {
                        self.stopTranscribing()
                    }
                }
            }
            .store(in: &cancellables)
    }
    
    /// 認可状態を確認
    private func checkAuthorization() async {
        let status = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status)
            }
        }
        
        DispatchQueue.main.async {
            switch status {
            case .authorized:
                self.isAvailable = true
                self.errorMessage = nil
            case .denied:
                self.isAvailable = false
                self.errorMessage = "Speech recognition access denied by user"
            case .restricted:
                self.isAvailable = false
                self.errorMessage = "Speech recognition restricted on this device"
            case .notDetermined:
                self.isAvailable = false
                self.errorMessage = "Speech recognition not yet authorized"
            @unknown default:
                self.isAvailable = false
                self.errorMessage = "Unknown authorization status"
            }
        }
    }
    
    // MARK: - 公開メソッド
    
    /// 音声認識を開始
    func startTranscribing() {
        // すでに実行中なら何もしない
        guard !isListening else { return }
        
        // 認識器が利用できない場合は終了
        guard isAvailable, let recognizer = speechRecognizer, recognizer.isAvailable else {
            DispatchQueue.main.async {
                self.errorMessage = "Speech recognizer is not available"
            }
            return
        }
        
        resetTranscript()
        
        // オーディオセッションを設定
        do {
            try setupAudioSession()
            try startAudioEngine()
            setupRecognitionRequest(with: recognizer)
            
            DispatchQueue.main.async {
                self.isListening = true
                self.isFinished = false
                self.errorMessage = nil
            }
        } catch {
            handleSetupError(error)
        }
    }
    
    /// 音声認識を停止
    func stopTranscribing() {
        audioEngine.stop()
        recognitionRequest?.endAudio()
        
        DispatchQueue.main.async {
            self.isListening = false
            
            // 少し待ってから認識終了とマーク
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.isFinished = true
            }
        }
    }
    
    /// 認識テキストをリセット
    func resetTranscript() {
        DispatchQueue.main.async {
            self.transcript = ""
            self.isFinished = false
            self.errorMessage = nil
        }
    }
    
    // MARK: - オーディオ処理
    
    private func setupAudioSession() throws {
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
    }
    
    private func startAudioEngine() throws {
        // 既存のタスクがあれば終了
        if let recognitionTask = recognitionTask {
            recognitionTask.cancel()
            self.recognitionTask = nil
        }
        
        // オーディオバッファのセットアップ
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, when in
            self?.recognitionRequest?.append(buffer)
        }
        
        audioEngine.prepare()
        try audioEngine.start()
    }
    
    private func setupRecognitionRequest(with recognizer: SFSpeechRecognizer) {
        // 認識リクエストを作成
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        
        guard let recognitionRequest = recognitionRequest else {
            DispatchQueue.main.async {
                self.errorMessage = "Unable to create recognition request"
            }
            return
        }
        
        // 途中結果も取得
        recognitionRequest.shouldReportPartialResults = true
        
        // 高精度な認識を要求
        if #available(iOS 16.0, *) {
            recognitionRequest.requiresOnDeviceRecognition = false
            recognitionRequest.addsPunctuation = true
        }
        
        // 音声認識タスクの作成
        recognitionTask = recognizer.recognitionTask(with: recognitionRequest) { [weak self] result, error in
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
            if let error = error {
                self.handleRecognitionError(error)
            }
            
            if error != nil || isFinal {
                self.finishRecognition()
            }
        }
    }
    
    private func finishRecognition() {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        
        recognitionRequest = nil
        recognitionTask = nil
        
        DispatchQueue.main.async {
            self.isListening = false
            self.isFinished = true
        }
    }
    
    // MARK: - エラー処理
    
    private func handleSetupError(_ error: Error) {
        DispatchQueue.main.async {
            self.errorMessage = "Setup failed: \(error.localizedDescription)"
            self.isListening = false
        }
        print("Audio engine setup failed: \(error.localizedDescription)")
    }
    
    private func handleRecognitionError(_ error: Error) {
        let nsError = error as NSError
        
        // 認識がキャンセルされた場合は通常のエラーとして扱わない
        if nsError.domain == "kAFAssistantErrorDomain" && nsError.code == 216 {
            // キャンセルエラー - 無視する
            return
        }
        
        DispatchQueue.main.async {
            // 簡単なエラーメッセージを提供
            if nsError.domain == "com.apple.speechrecognition.errors" {
                switch nsError.code {
                case 1: self.errorMessage = "Recognition canceled by user"
                case 2: self.errorMessage = "Network connection not available"
                case 3: self.errorMessage = "Audio quality issue, please try again"
                case 4: self.errorMessage = "Recognition timeout"
                default: self.errorMessage = "Recognition failed: \(nsError.code)"
                }
            } else {
                self.errorMessage = "Recognition error: \(error.localizedDescription)"
            }
        }
    }
    
    deinit {
        // クリーンアップ
        audioEngine.stop()
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        
        // 購読解除
        cancellables.forEach { $0.cancel() }
        cancellables.removeAll()
    }
}

// MARK: - SFSpeechRecognizerDelegate
extension SpeechRecognizer: SFSpeechRecognizerDelegate {
    nonisolated func speechRecognizer(_ speechRecognizer: SFSpeechRecognizer, availabilityDidChange available: Bool) {
        DispatchQueue.main.async {
            self.isAvailable = available
            
            if !available {
                self.errorMessage = "Speech recognition is currently unavailable"
                if self.isListening {
                    self.stopTranscribing()
                }
            } else {
                self.errorMessage = nil
            }
        }
    }
}

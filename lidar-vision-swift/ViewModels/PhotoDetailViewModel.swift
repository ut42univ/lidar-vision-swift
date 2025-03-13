import SwiftUI
import Combine

/// Photo detail screen ViewModel - Streamlined for integrated view
final class PhotoDetailViewModel: ObservableObject {
    // Input
    let image: UIImage
    
    // Published properties (UI state)
    @Published var isAnalyzing = false
    @Published var analysisError: String? = nil
    @Published var autoPlay: Bool = true
    
    // Services as properties (injectable for testing)
    let openAIService: OpenAIService
    let speechService: TextToSpeechService
    
    private var cancellables = Set<AnyCancellable>()
    
    init(
        image: UIImage,
        openAIService: OpenAIService = OpenAIService(),
        speechService: TextToSpeechService = TextToSpeechService(),
        autoAnalyze: Bool = true
    ) {
        print("Initializing PhotoDetailViewModel")
        self.image = image
        self.openAIService = openAIService
        self.speechService = speechService
        
        // Monitor service state changes
        setupBindings()
        
        // Auto-analyze the image when view appears
        if autoAnalyze {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.analyzeImage()
            }
        }
    }
    
    private func setupBindings() {
        // Track OpenAIService state reactively
        setupOpenAIServiceBindings()
        setupSpeechServiceBindings()
    }
    
    private func setupOpenAIServiceBindings() {
        // Track loading state
        openAIService.$isLoading
            .receive(on: RunLoop.main)
            .assign(to: \.isAnalyzing, on: self)
            .store(in: &cancellables)
        
        // Track error state
        openAIService.$error
            .receive(on: RunLoop.main)
            .assign(to: \.analysisError, on: self)
            .store(in: &cancellables)
        
        // Handle description updates
        openAIService.$imageDescription
            .dropFirst() // Skip initial empty value
            .filter { !$0.isEmpty } // Only process non-empty descriptions
            .throttle(for: .seconds(0.5), scheduler: RunLoop.main, latest: true) // Prevent rapid updates
            .sink { [weak self] description in
                guard let self = self, !description.isEmpty else { return }
                
                // Auto-speak if enabled
                if self.autoPlay {
                    self.speechService.speak(text: description)
                }
            }
            .store(in: &cancellables)
    }
    
    private func setupSpeechServiceBindings() {
        // Additional speech service bindings if needed
    }
    
    /// Start image analysis
    func analyzeImage() {
        print("Starting image analysis from ViewModel")
        openAIService.analyzeImage(image)
    }
    
    /// Toggle speak/stop for the image description
    func speakDescription() {
        if speechService.isPlaying {
            speechService.stopSpeaking()
        } else if !openAIService.imageDescription.isEmpty {
            speechService.speak(text: openAIService.imageDescription)
        }
    }
    
    /// Toggle auto-play setting
    func toggleAutoPlay() {
        autoPlay.toggle()
        
        // Handle state change appropriately
        if autoPlay && !openAIService.imageDescription.isEmpty && !speechService.isPlaying {
            speakDescription()
        } else if !autoPlay && speechService.isPlaying {
            speechService.stopSpeaking()
        }
    }
    
    deinit {
        print("PhotoDetailViewModel deinit")
        if speechService.isPlaying {
            speechService.stopSpeaking()
        }
        
        // Cancel all subscriptions
        cancellables.forEach { $0.cancel() }
        cancellables.removeAll()
    }
}

// MARK: - Computed Properties
extension PhotoDetailViewModel {
    // Current description text
    var description: String {
        openAIService.imageDescription
    }
    
    // Flag to show analyze button
    var shouldShowAnalyzeButton: Bool {
        return openAIService.imageDescription.isEmpty &&
               openAIService.error == nil &&
               !openAIService.isLoading
    }
    
    // Flag to enable description playback
    var canPlayDescription: Bool {
        return !openAIService.imageDescription.isEmpty
    }
}

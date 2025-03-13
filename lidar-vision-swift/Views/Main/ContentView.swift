import SwiftUI

/// Modern Apple-style main screen UI with translucent blur-based design
struct ContentView: View {
    // MARK: - View Models & Environment
    @StateObject var viewModel = ContentViewModel()
    @StateObject var orientationHelper = OrientationHelper()
    @Environment(\.colorScheme) var colorScheme
    
    // MARK: - UI State
    @State private var showAirPodsAlert = false
    @State private var showHelp = false
    @State private var captureScale: CGFloat = 1.0
    
    // MARK: - Design Constants
    private let buttonSize: CGFloat = 40
    private let captureButtonSize: CGFloat = 80
    private let barHeight: CGFloat = 8
    private let barWidth: CGFloat = 96
    private let cornerRadius: CGFloat = 12
    private let spacing: CGFloat = 12
    private let standardPadding: CGFloat = 16
    
    var body: some View {
        ZStack {
            // AR View
            arView
            
            // UI Overlays
            VStack(spacing: 0) {
                // Top controls
                topControls
                
                Spacer()
                
                // Bottom control bar
                bottomControlBar
                    .padding(.bottom, standardPadding)
            }
            .padding(standardPadding)
            
            // Help overlay when active
            if showHelp {
                helpOverlay
            }
        }
        .presentationModifiers()
        .alert("3D Spatial Audio", isPresented: $showAirPodsAlert) {
            Button("OK") { viewModel.toggleSpatialAudio() }
        } message: {
            Text("Advanced spatial audio with head tracking is available when using AirPods or AirPods Pro. Basic spatial audio is available with any stereo headphones.")
        }
        .onAppear { 
            viewModel.resumeARSession()
        }
        .onDisappear { 
            viewModel.pauseARSession() 
        }
        .environmentObject(viewModel)
    }
    
    // MARK: - Main Components
    
    // AR View Container
    private var arView: some View {
        ARViewContainer(sessionService: viewModel.sessionService)
            .ignoresSafeArea()
    }
    
    // Top control row
    private var topControls: some View {
        HStack {
            // Help button
            ControlButton(
                icon: "questionmark.circle", 
                accessibilityLabel: "Help"
            ) {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                    showHelp.toggle()
                }
            }
            .background(blurBackground)
            .clipShape(Circle())
            
            Spacer()
            
            // Function button group
            controlButtonGroup
        }
        .padding(.top, standardPadding)
    }
    
    // Grouped control buttons
    private var controlButtonGroup: some View {
        HStack(spacing: spacing) {
            // Spatial audio toggle
            ControlButton(
                icon: viewModel.isSpatialAudioEnabled ? "airpodsmax" : "headphones", 
                active: viewModel.isSpatialAudioEnabled,
                accessibilityLabel: "Spatial Audio"
            ) {
                if (!viewModel.isSpatialAudioEnabled) {
                    showAirPodsAlert = true
                } else {
                    viewModel.toggleSpatialAudio()
                }
            }
            
            // Mesh visibility toggle
            ControlButton(
                icon: viewModel.isMeshVisible ? "grid.circle.fill" : "grid.circle", 
                active: viewModel.isMeshVisible,
                accessibilityLabel: "Toggle Mesh Visibility"
            ) {
                viewModel.toggleMeshVisibility()
            }
            
            // Mesh reset button
            ControlButton(
                icon: "arrow.triangle.2.circlepath",
                accessibilityLabel: "Reset Mesh"
            ) {
                viewModel.resetMeshCache()
                hapticFeedback(style: .medium)
            }
            
            // Settings button
            ControlButton(
                icon: "gear",
                accessibilityLabel: "Settings"
            ) {
                viewModel.pauseARSession()
                viewModel.showSettings = true
            }
        }
        .padding(.horizontal, standardPadding)
        .padding(.vertical, 10)
        .background(blurBackground)
        .cornerRadius(20)
    }
    
    // Distance indicator bar (centered)
    private var distanceBarIndicator: some View {
        ZStack(alignment: .leading) {
            // Background track
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(Color.white.opacity(0.3))
                .frame(width: barWidth, height: barHeight)
            
            // Filled progress bar with color gradient
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(distanceGradient)
                .frame(width: barWidth * distanceProgress, height: barHeight)
        }
        .animation(.easeInOut, value: distanceProgress) // 距離バーのアニメーション
    }
    
    // Bottom control bar with camera button in center
    private var bottomControlBar: some View {
        ZStack {
            HStack(spacing: spacing) {
                VStack(spacing: 8) {
                    distanceBarIndicator
                    Text(distanceDescriptor)
                        .fontWeight(.semibold)
                }
                Spacer()
                HStack {
                    Image(systemName: "ruler.fill")
                        .foregroundColor(distanceValueColor)
                    Text(distanceValue)
                        .foregroundColor(distanceValueColor)
                        .fontWeight(.semibold)
                        .font(.title3)
                }
            }
            cameraButton
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16) // 下部を少し広めにする
        .padding(.horizontal, standardPadding)
        .background(blurBackground)
        .cornerRadius(20) // コーナー半径を上のボタンなどと合わせる
    }
    
    // Camera button (iOS Camera app style)
    private var cameraButton: some View {
        Button(action: capturePhoto) {
            ZStack {
                // Outer ring
                Circle()
                    .stroke(Color.white, lineWidth: 4)
                    .frame(width: captureButtonSize, height: captureButtonSize)
                
                // Inner white button
                Circle()
                    .fill(Color.white)
                    .frame(width: captureButtonSize - 10, height: captureButtonSize - 10)
                    .scaleEffect(captureScale)
            }
            .shadow(color: Color.black.opacity(0.2), radius: 2, x: 0, y: 1)
        }
        .accessibilityLabel("Capture Photo")
        .onChange(of: captureScale) {
            if captureScale < 1.0 {
                // Reset scale after animation completes
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                        captureScale = 1.0
                    }
                }
            }
        }
    }
    
    // Help overlay
    private var helpOverlay: some View {
        ZStack {
            if #available(iOS 15.0, *) {
                Color.black.opacity(0.3).background(.thinMaterial)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                            showHelp = false
                        }
                    }
            } else {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                            showHelp = false
                        }
                    }
            }

            VStack(spacing: 25) {
                Text("LiDAR Vision")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.primary)
                
                VStack(alignment: .leading, spacing: 20) {
                    helpItem(icon: "ruler", title: "Distance Indicator", description: "The bar shows distance to obstacles ahead")
                    
                    helpItem(icon: "camera", title: "Capture Photo", description: "Tap the button to analyze your surroundings")
                    
                    helpItem(icon: "airpodsmax", title: "Spatial Audio", description: "Detect distance and direction through sound")
                    
                    helpItem(icon: "gear", title: "Settings", description: "Customize the app to suit your preferences")
                }
                
                Button(action: {
                    withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                        showHelp = false
                    }
                }) {
                    Text("Close")
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 10)
                        .background(Color.accentColor)
                        .cornerRadius(cornerRadius)
                }
                .padding(.top, 10)
                .accessibilityHint("Closes the help screen")
            }
            .padding(30)
            .background(
                Color.white
                    .cornerRadius(20)
                    .shadow(color: Color.black.opacity(0.2), radius: 10, x: 0, y: 4)
            )
            .padding(24)
            .transition(.asymmetric(
                insertion: .scale(scale: 0.9).combined(with: .opacity).animation(.spring(response: 0.6, dampingFraction: 0.7)),
                removal: .scale(scale: 0.95).combined(with: .opacity).animation(.spring(response: 0.5, dampingFraction: 0.7))
            ))
        }
        .transition(.opacity.animation(.easeInOut(duration: 0.3)))
    }
    
    // Help item row
    private func helpItem(icon: String, title: String, description: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(Color.accentColor)
                .frame(width: 28, height: 28)
                .accessibilityHidden(true)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
    }
    
    // MARK: - Computed Properties
    
    // Background blur effect for controls
    private var blurBackground: some View {
        Group {
            if #available(iOS 15.0, *) {
                Color.clear.background(.ultraThinMaterial)
            } else {
                Color.black.opacity(0.4)
            }
        }
    }
    
    // Distance progress value (0.0-1.0)
    private var distanceProgress: CGFloat {
        let depth = viewModel.sessionService.centerDepth
        let maxDistance: CGFloat = 5.0
        
        // Calculate progress (closer = more filled)
        let progress = 1.0 - min(CGFloat(depth) / maxDistance, 1.0)
        
        // Ensure minimum visibility
        return max(progress, 0.05)
    }
    
    // Distance text based on measured depth
    private var distanceText: String {
        let depth = viewModel.sessionService.centerDepth
        
        if depth < 0.5 {
            return "Very Close: \(String(format: "%.2f", depth))m"
        } else if depth < 1.5 {
            return "Near: \(String(format: "%.2f", depth))m"
        } else if depth < 3.0 {
            return "Medium: \(String(format: "%.2f", depth))m"
        } else {
            return "Far: \(String(format: "%.2f", depth))m"
        }
    }
    
    // Gradient for distance indicator based on safety
    private var distanceGradient: LinearGradient {
        let depth = viewModel.sessionService.centerDepth
        
        if depth < 0.5 {
            // Danger - red
            return LinearGradient(
                gradient: Gradient(colors: [Color.red, Color.red.opacity(0.8)]),
                startPoint: .leading,
                endPoint: .trailing
            )
        } else if depth < 1.0 {
            // Warning - orange to yellow
            return LinearGradient(
                gradient: Gradient(colors: [Color.orange, Color.yellow]),
                startPoint: .leading,
                endPoint: .trailing
            )
        } else {
            // Safe - green
            return LinearGradient(
                gradient: Gradient(colors: [Color.green.opacity(0.8), Color.green]),
                startPoint: .leading,
                endPoint: .trailing
            )
        }
    }
    
    // Distance descriptor based on measured depth
    private var distanceDescriptor: String {
        let depth = viewModel.sessionService.centerDepth
        if depth < 0.5 {
            return "Very Close"
        } else if depth < 1.5 {
            return "Near"
        } else if depth < 3.0 {
            return "Medium"
        } else {
            return "Safe"
        }
    }

    // Distance value based on measured depth
    private var distanceValue: String {
        let depth = viewModel.sessionService.centerDepth
        return String(format: "%.2f", depth) + "m"
    }

    private var distanceValueColor: Color {
        let depth = viewModel.sessionService.centerDepth
        if depth < 0.5 {
            return .red
        } else if depth < 1.5 {
            return .orange
        } else {
            return .green
        }
    }

    // MARK: - Actions
    
    // Capture photo action
    private func capturePhoto() {
        // Button animation
        withAnimation(.spring(response: 0.2, dampingFraction: 0.6)) {
            captureScale = 0.9
        }
        
        // Haptic feedback
        hapticFeedback(style: .medium)
        
        // Capture photo
        viewModel.pauseARSession()
        viewModel.captureAndAnalyzePhoto()
    }
    
    // Generate haptic feedback
    private func hapticFeedback(style: UIImpactFeedbackGenerator.FeedbackStyle) {
        UIImpactFeedbackGenerator(style: style).impactOccurred()
    }
}

#Preview {
    ContentView()
}

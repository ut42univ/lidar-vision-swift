import SwiftUI

/// Modern main screen UI with consistent design system
struct ContentView: View {
    // MARK: - View Models & Environment
    @StateObject var viewModel = ContentViewModel()
    @StateObject var orientationHelper = OrientationHelper()
    @Environment(\.colorScheme) var colorScheme
    
    // MARK: - UI State
    @State private var showHelp = false
    @State private var captureScale: CGFloat = 1.0
    
    // MARK: - Design System Constants
    private enum DesignSystem {
        // Sizing
        static let buttonSize: CGFloat = 40
        static let captureButtonSize: CGFloat = 80
        static let standardCornerRadius: CGFloat = 20
        static let controlBarCornerRadius: CGFloat = 24
        static let standardSpacing: CGFloat = 12
        static let standardPadding: CGFloat = 16
        
        // Distance Bar
        static let barHeight: CGFloat = 8
        static let barWidth: CGFloat = 64
        
        // Material
        static let backgroundMaterial: Material = .ultraThinMaterial
    }
    
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
                    .padding(.bottom, DesignSystem.standardPadding)
            }
            .padding(DesignSystem.standardPadding)
            
            // Conditionally show overlays, ensuring they don't appear simultaneously
            if showHelp {
                helpOverlay
                    .zIndex(20) // Highest priority
            } else if viewModel.showProximityWarning {
                // 更新されたProximityWarningViewを使用
                ProximityWarningView(distance: viewModel.currentDistance)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .transition(.opacity.combined(with: .scale(scale: 0.9)))
                    .zIndex(10)
            }
        }
        .presentationModifiers()

        .onAppear {
            viewModel.resumeARSession()
        }
        .onDisappear {
            viewModel.pauseARSession()
        }
        .environmentObject(viewModel)
        .animation(.easeInOut(duration: 0.3), value: viewModel.showProximityWarning)
    }
    
    // MARK: - Main Components
    
    /// AR View Container
    private var arView: some View {
        ARViewContainer(sessionService: viewModel.sessionService)
            .ignoresSafeArea()
    }
    
    /// Top control row
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
            .background(DesignSystem.backgroundMaterial)
            .clipShape(Circle())
            
            Spacer()
            
            // Function button group
            controlButtonGroup
        }
        .padding(.top, DesignSystem.standardPadding)
    }
    
    /// Grouped control buttons
    private var controlButtonGroup: some View {
        HStack(spacing: DesignSystem.standardSpacing) {
            // Mesh reset button
            VStack(spacing: 4) {
                ControlButton(
                    icon: "arrow.triangle.2.circlepath",
                    accessibilityLabel: "Reset Mesh"
                ) {
                    viewModel.resetMeshCache()
                    hapticFeedback(style: .medium)
                }
                Text("Reset")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
            
            // Settings button
            VStack(spacing: 4) {
                ControlButton(
                    icon: "gear",
                    accessibilityLabel: "Settings"
                ) {
                    viewModel.pauseARSession()
                    viewModel.showSettings = true
                }
                Text("Settings")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, DesignSystem.standardPadding)
        .padding(.vertical, 10)
        .background(DesignSystem.backgroundMaterial)
        .cornerRadius(DesignSystem.standardCornerRadius)
    }
    
    /// Distance indicator bar (centered)
    private var distanceBarIndicator: some View {
        ZStack(alignment: .leading) {
            // Background track
            RoundedRectangle(cornerRadius: DesignSystem.standardCornerRadius)
                .fill(Color.white.opacity(0.3))
                .frame(width: DesignSystem.barWidth, height: DesignSystem.barHeight)
            
            // Filled progress bar with color gradient
            RoundedRectangle(cornerRadius: DesignSystem.standardCornerRadius)
                .fill(distanceGradient)
                .frame(width: DesignSystem.barWidth * distanceProgress, height: DesignSystem.barHeight)
        }
        .animation(.easeInOut, value: distanceProgress)
    }
    
    /// Bottom control bar with camera button in center
    private var bottomControlBar: some View {
        ZStack {
            HStack(spacing: DesignSystem.standardSpacing) {
                // Mesh visibility toggle
                VStack {
                    Button(action: {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        viewModel.toggleMeshVisibility()
                    }) {
                        Image(systemName: viewModel.isMeshVisible ? "cube.transparent.fill" : "cube.transparent")
                            .font(.system(size: 32))
                            .frame(width: 56, height: 56)
                            .foregroundColor(viewModel.isMeshVisible ? .white : .white.opacity(0.9))
                            .background(viewModel.isMeshVisible ? Color.secondary.opacity(0.8) : Color.clear)
                            .clipShape(Circle())
                    }
                    .accessibilityLabel("Toggle Mesh Visibility")
                }
                .padding()
                
                Spacer()
                
                VStack {
                    distanceBarIndicator
                    Text(distanceValue)
                        .foregroundColor(distanceValueColor)
                        .fontWeight(.semibold)
                        .font(.system(.body, design: .monospaced))
                }
                .padding()
            }
            
            cameraButton
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .padding(.horizontal, DesignSystem.standardPadding)
        .background(DesignSystem.backgroundMaterial)
        .cornerRadius(DesignSystem.controlBarCornerRadius)
    }
    
    /// Camera button (iOS Camera app style)
    private var cameraButton: some View {
        Button(action: capturePhoto) {
            ZStack {
                // Outer ring
                Circle()
                    .stroke(Color.white, lineWidth: 4)
                    .frame(width: DesignSystem.captureButtonSize, height: DesignSystem.captureButtonSize)
                
                // Inner white button
                Circle()
                    .fill(Color.white)
                    .frame(width: DesignSystem.captureButtonSize - 10, height: DesignSystem.captureButtonSize - 10)
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
    
    /// Help overlay
    private var helpOverlay: some View {
        ZStack {
            Color.black.opacity(0.3)
                .background(DesignSystem.backgroundMaterial)
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                        showHelp = false
                    }
                }

            VStack(spacing: 25) {
                Text("What is LiDAR Vision?")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.primary)
                
                VStack(alignment: .leading, spacing: 20) {
                    helpItem(icon: "ruler", title: "Distance Indicator", description: "The bar shows distance to obstacles ahead")
                    
                    helpItem(icon: "camera", title: "Capture Photo", description: "Tap the button to analyze your surroundings")
                    
                    helpItem(icon: "airpodsmax", title: "Spatial Audio", description: "Detect distance and direction through sound")
                    
                    helpItem(icon: "gear", title: "Settings", description: "Customize the app to suit your preferences")
                    
                    helpItem(icon: "exclamationmark.triangle.fill", title: "Warning Alerts", description: "Visual and haptic alerts when obstacles are too close")
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
                        .cornerRadius(DesignSystem.standardCornerRadius)
                }
                .padding(.top, 10)
                .accessibilityHint("Closes the help screen")
            }
            .padding(30)
            .background(
                RoundedRectangle(cornerRadius: DesignSystem.controlBarCornerRadius)
                    .fill(Color(.systemBackground).opacity(0.9))
            )
            .padding(24)
            .transition(.scale(scale: 0.9).combined(with: .opacity))
        }
    }
    
    /// Help item row
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
    
    /// Distance progress value (0.0-1.0)
    private var distanceProgress: CGFloat {
        let depth = viewModel.sessionService.centerDepth
        let maxDistance: CGFloat = 5.0
        
        // Calculate progress (closer = more filled)
        let progress = 1.0 - min(CGFloat(depth) / maxDistance, 1.0)
        
        // Ensure minimum visibility
        return max(progress, 0.05)
    }
    
    /// Gradient for distance indicator based on safety
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
    
    /// Distance value display with proper formatting
    private var distanceValue: String {
        let depth = viewModel.sessionService.centerDepth
        return String(format: "%.2f", depth) + "m"
    }

    /// Color for distance value based on safety threshold
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
    
    /// Capture photo action
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
    
    /// Generate haptic feedback
    private func hapticFeedback(style: UIImpactFeedbackGenerator.FeedbackStyle) {
        UIImpactFeedbackGenerator(style: style).impactOccurred()
    }
}

#Preview {
    ContentView()
}

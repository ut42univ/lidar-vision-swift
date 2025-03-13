import SwiftUI

/// Application settings screen
struct AppSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var settings: AppSettings
    @State private var showResetConfirmation = false
    
    // Callback to receive changes
    var onSettingsChanged: (AppSettings) -> Void
    
    init(settings: AppSettings, onSettingsChanged: @escaping (AppSettings) -> Void) {
        self._settings = State(initialValue: settings)
        self.onSettingsChanged = onSettingsChanged
    }
    
    var body: some View {
        NavigationView {
            Form {
                // Spatial audio section
                Section {
                    HStack {
                        Image(systemName: "speaker.wave.3")
                            .foregroundColor(.blue)
                            .accessibility(hidden: true)
                        Toggle("Enable Spatial Audio", isOn: $settings.spatialAudio.isEnabled)
                            .tint(.blue)
                            .onChange(of: settings.spatialAudio.isEnabled) { _, _ in
                                onSettingsChanged(settings)
                            }
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityHint("Toggles spatial audio feedback for obstacle detection")
                    
                    VStack(alignment: .leading) {
                        HStack {
                            Image(systemName: "volume.2")
                                .foregroundColor(.blue)
                                .accessibility(hidden: true)
                            Text("Volume: \(Int(settings.spatialAudio.volume * 100))%")
                        }
                        Slider(value: Binding(
                            get: { settings.spatialAudio.volume },
                            set: { newValue in
                                settings.spatialAudio.volume = newValue
                                onSettingsChanged(settings)
                            }
                        ), in: 0...1, step: 0.05)
                            .tint(.blue)
                            .accessibilityValue("\(Int(settings.spatialAudio.volume * 100)) percent")
                            .disabled(!settings.spatialAudio.isEnabled)
                    }
                    .padding(.vertical, 4)
                    .accessibilityElement(children: .combine)
                    .accessibilityHint("Adjust volume of spatial audio feedback")
                } header: {
                    Label("Spatial Audio", systemImage: "ear.and.waveform")
                }
                
                // Haptic feedback settings
                Section {
                    HStack {
                        Image(systemName: "iphone.radiowaves.left.and.right")
                            .foregroundColor(.blue)
                            .accessibility(hidden: true)
                        Toggle("Enable Haptic Feedback", isOn: $settings.hapticFeedback.isEnabled)
                            .tint(.blue)
                            .onChange(of: settings.hapticFeedback.isEnabled) { _, _ in
                                onSettingsChanged(settings)
                            }
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityHint("Toggles vibration feedback for obstacle detection")
                    
                    // 振動を開始する距離の設定
                    VStack(alignment: .leading) {
                        HStack {
                            Image(systemName: "ruler")
                                .foregroundColor(.blue)
                                .accessibility(hidden: true)
                            Text("Start Vibration at:")
                            Spacer()
                            Text("\(String(format: "%.1f", settings.hapticFeedback.startDistance))m")
                        }
                        Slider(value: Binding(
                            get: { settings.hapticFeedback.startDistance },
                            set: { newValue in
                                settings.hapticFeedback.startDistance = newValue
                                onSettingsChanged(settings)
                            }
                        ), in: 0.5...5.0, step: 0.1)
                            .tint(.blue)
                            .disabled(!settings.hapticFeedback.isEnabled)
                            .accessibilityValue("\(String(format: "%.1f", settings.hapticFeedback.startDistance)) meters")
                    }
                    .padding(.vertical, 4)
                    .accessibilityElement(children: .combine)
                    .accessibilityHint("Set the distance at which vibration feedback begins")
                    
                    // 説明文を追加
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "info.circle")
                            .foregroundColor(.secondary)
                            .accessibility(hidden: true)
                        Text("Haptic feedback intensity will increase naturally as you get closer to obstacles, based on human perception principles.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 2)
                } header: {
                    Label("Haptic Feedback", systemImage: "waveform.path")
                }
                
                // Reset settings button
                Section {
                    Button(action: {
                        showResetConfirmation = true
                    }) {
                        HStack {
                            Spacer()
                            Image(systemName: "arrow.counterclockwise")
                                .foregroundColor(.red)
                            Text("Reset Settings")
                                .foregroundColor(.red)
                                .fontWeight(.medium)
                            Spacer()
                        }
                    }
                    .accessibilityHint("Resets all settings to their default values")
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .alert("Reset Settings", isPresented: $showResetConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Reset", role: .destructive) {
                    settings = AppSettings()
                    onSettingsChanged(settings)
                }
            } message: {
                Text("This will reset all settings to their default values. This action cannot be undone.")
            }
        }
    }
}

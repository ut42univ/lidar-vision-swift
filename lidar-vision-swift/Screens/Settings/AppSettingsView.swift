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
                Section(header: Text("Spatial Audio")) {
                    Toggle("Enable Spatial Audio", isOn: $settings.spatialAudio.isEnabled)
                        .tint(.blue)
                        .onChange(of: settings.spatialAudio.isEnabled) {
                            onSettingsChanged(settings)
                        }
                    
                    VStack(alignment: .leading) {
                        Text("Volume: \(Int(settings.spatialAudio.volume * 100))%")
                        Slider(value: $settings.spatialAudio.volume, in: 0...1, step: 0.05)
                            .tint(.blue)
                            .onChange(of: settings.spatialAudio.volume) {
                                onSettingsChanged(settings)
                            }
                    }
                    .padding(.vertical, 4)
                }
                
                // Distance threshold settings
                Section(header: Text("Distance Threshold Settings")) {
                    VStack(alignment: .leading) {
                        HStack {
                            Text("Near distance:")
                            Spacer()
                            Text("\(String(format: "%.1f", settings.spatialAudio.nearThreshold))m")
                        }
                        Slider(value: $settings.spatialAudio.nearThreshold, in: 0.1...1.0, step: 0.1)
                            .tint(.red)
                            .onChange(of: settings.spatialAudio.nearThreshold) {
                                onSettingsChanged(settings)
                            }
                    }
                    .padding(.vertical, 4)
                    
                    VStack(alignment: .leading) {
                        HStack {
                            Text("Medium distance:")
                            Spacer()
                            Text("\(String(format: "%.1f", settings.spatialAudio.mediumThreshold))m")
                        }
                        Slider(value: $settings.spatialAudio.mediumThreshold, in: 1.0...3.0, step: 0.1)
                            .tint(.orange)
                            .onChange(of: settings.spatialAudio.mediumThreshold) {
                                onSettingsChanged(settings)
                            }
                    }
                    .padding(.vertical, 4)
                    
                    VStack(alignment: .leading) {
                        HStack {
                            Text("Maximum detection distance:")
                            Spacer()
                            Text("\(String(format: "%.1f", settings.spatialAudio.maxDistance))m")
                        }
                        Slider(value: $settings.spatialAudio.maxDistance, in: 3.0...10.0, step: 0.5)
                            .tint(.green)
                            .onChange(of: settings.spatialAudio.maxDistance) {
                                onSettingsChanged(settings)
                            }
                    }
                    .padding(.vertical, 4)
                }
                
                // Audio settings
                Section(header: Text("Sound Settings")) {
                    VStack(alignment: .leading) {
                        HStack {
                            Text("High pitch (near):")
                            Spacer()
                            Text("\(Int(settings.audioTones.highFrequency))Hz")
                        }
                        Slider(value: $settings.audioTones.highFrequency, in: 500...1200, step: 20)
                            .tint(.blue)
                            .onChange(of: settings.audioTones.highFrequency) {
                                onSettingsChanged(settings)
                            }
                    }
                    .padding(.vertical, 4)
                    
                    VStack(alignment: .leading) {
                        HStack {
                            Text("Medium pitch (medium):")
                            Spacer()
                            Text("\(Int(settings.audioTones.mediumFrequency))Hz")
                        }
                        Slider(value: $settings.audioTones.mediumFrequency, in: 300...700, step: 20)
                            .tint(.purple)
                            .onChange(of: settings.audioTones.mediumFrequency) {
                                onSettingsChanged(settings)
                            }
                    }
                    .padding(.vertical, 4)
                    
                    VStack(alignment: .leading) {
                        HStack {
                            Text("Low pitch (far):")
                            Spacer()
                            Text("\(Int(settings.audioTones.lowFrequency))Hz")
                        }
                        Slider(value: $settings.audioTones.lowFrequency, in: 100...400, step: 20)
                            .tint(.indigo)
                            .onChange(of: settings.audioTones.lowFrequency) {
                                onSettingsChanged(settings)
                            }
                    }
                    .padding(.vertical, 4)
                }
                
                // Haptic feedback settings
                Section(header: Text("Haptic Feedback")) {
                    Toggle("Enable Haptic Feedback", isOn: $settings.hapticFeedback.isEnabled)
                        .tint(.blue)
                        .onChange(of: settings.hapticFeedback.isEnabled) {
                            onSettingsChanged(settings)
                        }
                    
                    Picker("Near distance intensity", selection: $settings.hapticFeedback.nearIntensity) {
                        Text("Light").tag(HapticIntensity.light)
                        Text("Medium").tag(HapticIntensity.medium)
                        Text("Heavy").tag(HapticIntensity.heavy)
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .disabled(!settings.hapticFeedback.isEnabled)
                    .onChange(of: settings.hapticFeedback.nearIntensity) {
                        onSettingsChanged(settings)
                    }
                    
                    Picker("Medium distance intensity", selection: $settings.hapticFeedback.mediumIntensity) {
                        Text("Light").tag(HapticIntensity.light)
                        Text("Medium").tag(HapticIntensity.medium)
                        Text("Heavy").tag(HapticIntensity.heavy)
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .disabled(!settings.hapticFeedback.isEnabled)
                    .onChange(of: settings.hapticFeedback.mediumIntensity) {
                        onSettingsChanged(settings)
                    }
                }
                
                // Reset settings button
                Section {
                    Button(action: {
                        showResetConfirmation = true
                    }) {
                        HStack {
                            Spacer()
                            Text("Reset Settings")
                                .foregroundColor(.red)
                            Spacer()
                        }
                    }
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

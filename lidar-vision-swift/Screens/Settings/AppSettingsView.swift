import SwiftUI

/// アプリ全体の設定画面
struct AppSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var settings: AppSettings
    @State private var showResetConfirmation = false
    
    // 変更を受け取るコールバック
    var onSettingsChanged: (AppSettings) -> Void
    
    init(settings: AppSettings, onSettingsChanged: @escaping (AppSettings) -> Void) {
        self._settings = State(initialValue: settings)
        self.onSettingsChanged = onSettingsChanged
    }
    
    var body: some View {
        NavigationView {
            Form {
                // 空間オーディオセクション
                Section(header: Text("空間オーディオ")) {
                    Toggle("空間オーディオを有効化", isOn: $settings.spatialAudio.isEnabled)
                        .tint(.blue)
                        .onChange(of: settings.spatialAudio.isEnabled) {
                            onSettingsChanged(settings)
                        }
                    
                    VStack(alignment: .leading) {
                        Text("音量: \(Int(settings.spatialAudio.volume * 100))%")
                        Slider(value: $settings.spatialAudio.volume, in: 0...1, step: 0.05)
                            .tint(.blue)
                            .onChange(of: settings.spatialAudio.volume) {
                                onSettingsChanged(settings)
                            }
                    }
                    .padding(.vertical, 4)
                }
                
                // 距離のしきい値設定
                Section(header: Text("距離のしきい値設定")) {
                    VStack(alignment: .leading) {
                        HStack {
                            Text("近距離:")
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
                            Text("中距離:")
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
                            Text("最大検出距離:")
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
                
                // 音響設定
                Section(header: Text("音響設定")) {
                    VStack(alignment: .leading) {
                        HStack {
                            Text("高音 (近距離):")
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
                            Text("中音 (中距離):")
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
                            Text("低音 (遠距離):")
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
                
                // 触覚フィードバック設定
                Section(header: Text("触覚フィードバック")) {
                    Toggle("触覚フィードバックを有効化", isOn: $settings.hapticFeedback.isEnabled)
                        .tint(.blue)
                        .onChange(of: settings.hapticFeedback.isEnabled) {
                            onSettingsChanged(settings)
                        }
                    
                    Picker("近距離の強度", selection: $settings.hapticFeedback.nearIntensity) {
                        Text("弱").tag(HapticIntensity.light)
                        Text("中").tag(HapticIntensity.medium)
                        Text("強").tag(HapticIntensity.heavy)
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .disabled(!settings.hapticFeedback.isEnabled)
                    .onChange(of: settings.hapticFeedback.nearIntensity) {
                        onSettingsChanged(settings)
                    }
                    
                    Picker("中距離の強度", selection: $settings.hapticFeedback.mediumIntensity) {
                        Text("弱").tag(HapticIntensity.light)
                        Text("中").tag(HapticIntensity.medium)
                        Text("強").tag(HapticIntensity.heavy)
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .disabled(!settings.hapticFeedback.isEnabled)
                    .onChange(of: settings.hapticFeedback.mediumIntensity) {
                        onSettingsChanged(settings)
                    }
                }
                
                // 設定リセットボタン
                Section {
                    Button(action: {
                        showResetConfirmation = true
                    }) {
                        HStack {
                            Spacer()
                            Text("設定をリセット")
                                .foregroundColor(.red)
                            Spacer()
                        }
                    }
                }
            }
            .navigationTitle("設定")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完了") {
                        dismiss()
                    }
                }
            }
            .alert("設定をリセット", isPresented: $showResetConfirmation) {
                Button("キャンセル", role: .cancel) { }
                Button("リセット", role: .destructive) {
                    settings = AppSettings()
                    onSettingsChanged(settings)
                }
            } message: {
                Text("すべての設定をデフォルト値に戻します。この操作は元に戻せません。")
            }
        }
    }
}

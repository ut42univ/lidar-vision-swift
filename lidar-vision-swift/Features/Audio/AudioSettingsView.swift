import SwiftUI

/// Audio settings screen
struct AudioSettingsView: View {
    @Binding var volume: Float
    @Binding var isEnabled: Bool
    @Environment(\.dismiss) private var dismiss
    @State private var showHeadphoneInfo = false
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Spatial Audio")) {
                    Toggle("Enable Spatial Audio", isOn: $isEnabled)
                        .tint(.blue)
                    
                    VStack(alignment: .leading) {
                        Text("Volume: \(Int(volume * 100))%")
                        Slider(value: $volume, in: 0...1, step: 0.05)
                            .tint(.blue)
                    }
                    .padding(.vertical, 8)
                    
                    Button(action: {
                        showHeadphoneInfo = true
                    }) {
                        HStack {
                            Image(systemName: "airpodsmax")
                                .foregroundColor(.blue)
                            Text("About AirPods")
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    }
                    
                    HStack {
                        Text("Status:")
                        Spacer()
                        Text(isEnabled ? "Enabled" : "Disabled")
                            .foregroundColor(isEnabled ? .green : .secondary)
                    }
                }
                
                // Usage section
                Section(header: Text("How to Use"), footer: Text("For optimal experience, we recommend using AirPods Pro or AirPods Max.")) {
                    // Help content view
                    helpContentView
                }
            }
            .navigationTitle("Audio Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showHeadphoneInfo) {
                AirPodsInfoView()
            }
        }
        .presentationDetents([.medium, .large])
    }
    
    // Help content view
    private var helpContentView: some View {
        VStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 10) {
                Text("How Spatial Audio Works")
                    .font(.headline)
                
                Text("When you approach obstacles, you'll hear sound from their direction. With AirPods Pro, the sound direction adjusts according to your head movement.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 4)
            
            VStack(alignment: .leading, spacing: 10) {
                Text("Sound Meanings")
                    .font(.headline)
                
                Text("• High pitch (near): Obstacles within 0.5m\n• Medium pitch (warning): Obstacles within 0.5m-2m\n• Low pitch (far): Obstacles within 2m-5m")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 4)
        }
    }
}

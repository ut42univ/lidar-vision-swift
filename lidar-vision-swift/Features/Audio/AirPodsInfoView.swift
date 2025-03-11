import SwiftUI

/// Information view for AirPods extended features
struct AirPodsInfoView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Image(systemName: "airpodsmax")
                    .font(.system(size: 80))
                    .foregroundColor(.blue)
                    .padding(.top, 40)
                
                Text("Extended Features with AirPods Pro")
                    .font(.title2)
                    .fontWeight(.bold)
                
                VStack(alignment: .leading, spacing: 16) {
                    FeatureRow(
                        icon: "person.wave.2.fill",
                        title: "Head Tracking",
                        description: "Detects the movement of your head and adjusts the position of sound sources accordingly."
                    )
                    
                    FeatureRow(
                        icon: "ear.and.waveform",
                        title: "Dynamic Head Tracking",
                        description: "AirPods Pro detect your head movements and fix sound directions to the real world."
                    )
                    
                    FeatureRow(
                        icon: "speaker.wave.3.fill",
                        title: "Immersive Audio",
                        description: "Sound from surrounding obstacles can be heard from more accurate directions."
                    )
                }
                .padding(.horizontal, 30)
                
                Spacer()
                
                Text("These features are automatically enabled when you connect AirPods Pro or AirPods Max.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                    .padding(.bottom, 20)
            }
            .navigationTitle("AirPods Features")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
    }
}

/// Feature row component
struct FeatureRow: View {
    var icon: String
    var title: String
    var description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 26))
                .foregroundColor(.blue)
                .frame(width: 36, height: 36)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

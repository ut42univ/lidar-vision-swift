import SwiftUI

// MARK: - Error View with Updated Design

/// Elegantly redesigned error view with blur background
struct ErrorView: View {
    let error: String
    let retryAction: () -> Void
    
    var body: some View {
        VStack(spacing: 22) {
            // Alert icon with visual emphasis
            ZStack {
                Circle()
                    .fill(Color.orange.opacity(0.2))
                    .frame(width: 70, height: 70)
                
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 30))
                    .foregroundColor(.orange)
            }
            
            // Error title and message
            VStack(spacing: 8) {
                Text("Analysis Error")
                    .font(.system(size: 20, weight: .semibold))
                
                Text(error)
                    .font(.system(size: 15))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 6)
            }
            
            // Retry button with visual appeal
            Button(action: {
                retryAction()
            }) {
                Text("Try Again")
                    .font(.system(size: 16, weight: .semibold))
                    .padding(.horizontal, 32)
                    .padding(.vertical, 12)
                    .background(
                        Capsule()
                            .fill(
                                LinearGradient(
                                    gradient: Gradient(colors: [Color.blue, Color.blue.opacity(0.8)]),
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .shadow(color: Color.blue.opacity(0.3), radius: 5, x: 0, y: 3)
                    )
                    .foregroundColor(.white)
            }
            .buttonStyle(ScaleButtonStyle())
        }
        .padding(28)
        .background(
            // Layered background for depth
            ZStack {
                // Outer blur
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color(.systemBackground).opacity(0.5))
                    .blur(radius: 15)
                
                // Inner blur material
                Group {
                    if #available(iOS 15.0, *) {
                        RoundedRectangle(cornerRadius: 20)
                            .fill(.ultraThinMaterial)
                    } else {
                        RoundedRectangle(cornerRadius: 20)
                            .fill(Color(.systemBackground).opacity(0.8))
                    }
                }
                
                // Subtle border
                RoundedRectangle(cornerRadius: 20)
                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
            }
        )
        .cornerRadius(20)
        .padding(.horizontal, 24)
    }
}

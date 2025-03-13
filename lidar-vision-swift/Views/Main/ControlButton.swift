import SwiftUI

/// Modern control button with accessibility
struct ControlButton: View {
    let icon: String
    var active: Bool = false
    var accessibilityLabel: String
    let action: () -> Void
    
    private let size: CGFloat = 40
    private let iconSize: CGFloat = 16
    
    var body: some View {
        Button(action: {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            action()
        }) {
            Image(systemName: icon)
                .font(.system(size: iconSize, weight: .semibold))
                .foregroundColor(active ? .white : .white.opacity(0.9))
                .frame(width: size, height: size)
                .background(active ? Color.accentColor.opacity(0.8) : Color.clear)
                .clipShape(Circle())
        }
        .accessibilityLabel(accessibilityLabel)
    }
}

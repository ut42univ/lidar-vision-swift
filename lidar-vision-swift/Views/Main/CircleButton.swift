import SwiftUI

/// Circle button with customizable size
struct CircleButton: View {
    let icon: String
    var iconColor: Color = .white
    var size: CGFloat = 40
    var accessibilityLabel: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: size * 0.4, weight: .medium))
                .foregroundColor(iconColor)
                .frame(width: size, height: size)
        }
        .accessibilityLabel(accessibilityLabel)
    }
}

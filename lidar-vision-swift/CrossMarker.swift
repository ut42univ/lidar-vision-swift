import SwiftUI

// Crosshair marker with customizable color
struct CrossMarker: View {
    var color: Color = .white
    
    var body: some View {
        ZStack {
            Rectangle()
                .fill(color)
                .frame(width: 20, height: 2)
            Rectangle()
                .fill(color)
                .frame(width: 2, height: 20)
        }
    }
}

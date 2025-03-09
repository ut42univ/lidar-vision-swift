import SwiftUI

/// 中央の十字マーカー
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

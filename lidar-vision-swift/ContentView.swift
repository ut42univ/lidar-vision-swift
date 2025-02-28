//
//  ContentView.swift
//  lidar-vision-swift
//
//  Created by Takuya Uehara on 2025/02/28.
//

import SwiftUI

struct ContentView: View {
    // 計測値を保持する@State変数（Coordinator内で更新する仕組みを後ほど実装）
    @State private var measuredDistance: Float = 0.0
    
    var body: some View {
        ZStack {
            ARViewContainer() // ARの映像を全画面に表示
                .edgesIgnoringSafeArea(.all)
            VStack {
                Spacer()
                Text(String(format: "Depth of Center: %.2f m", measuredDistance))
                    .padding()
                    .background(Color.black.opacity(0.5))
                    .foregroundColor(.white)
                    .cornerRadius(8)
                    .padding(.bottom, 20)
            }
        }
        // Coordinatorからの距離更新を受け取る仕組みを実装することも検討（例：Combineやdelegateパターン）
    }
}


#Preview {
    ContentView()
}

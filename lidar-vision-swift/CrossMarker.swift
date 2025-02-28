//
//  CrossMarker.swift
//  lidar-vision-swift
//
//  Created by Takuya Uehara on 2025/02/28.
//

import SwiftUI

// 画面中央に配置するクロスマーカー
struct CrossMarker: View {
    var isTooClose: Bool
    
    var body: some View {
        ZStack {
            Rectangle()
                .fill(isTooClose ? Color.red : Color.white)
                .frame(width: 40, height: 2)
            Rectangle()
                .fill(isTooClose ? Color.red : Color.white)
                .frame(width: 2, height: 40)
        }
    }
}

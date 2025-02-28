//
//  CrossMarker.swift
//  lidar-vision-swift
//
//  Created by Takuya Uehara on 2025/02/28.
//

import SwiftUI

// ③ 中央に表示する十字マークビュー
struct CrossMarker: View {
    // isTooCloseがtrueの場合は赤、それ以外は白
    var isTooClose: Bool
    
    var body: some View {
        ZStack {
            // 横線
            Rectangle()
                .fill(isTooClose ? Color.red : Color.white)
                .frame(width: 40, height: 2)
            // 縦線
            Rectangle()
                .fill(isTooClose ? Color.red : Color.white)
                .frame(width: 2, height: 40)
        }
    }
}

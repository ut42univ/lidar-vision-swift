//
//  CrossMarker.swift
//  lidar-vision-swift
//
//  Created by Takuya Uehara on 2025/02/28.
//

import SwiftUI

// クロスマーカーは色を引数で指定（白／黄色／赤）
struct CrossMarker: View {
    var color: Color = .white
    
    var body: some View {
        ZStack {
            Rectangle()
                .fill(color)
                .frame(width: 40, height: 2)
            Rectangle()
                .fill(color)
                .frame(width: 2, height: 40)
        }
    }
}

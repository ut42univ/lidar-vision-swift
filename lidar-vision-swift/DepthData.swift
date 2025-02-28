//
//  DepthData.swift
//  lidar-vision-swift
//
//  Created by Takuya Uehara on 2025/02/28.
//


import Combine

class DepthData: ObservableObject {
    @Published var centerDepth: Float = 0.0
}

//
//  ContentView.swift
//  lidar-vision-swift
//
//  Created by Takuya Uehara on 2025/02/28.
//

import SwiftUI

struct ContentView: View {
    @StateObject var depthData = DepthData()
    @State private var didTriggerHaptic = false
    let threshold: Float = 0.5

    var body: some View {
        ZStack {
            ARViewContainer(depthData: depthData)
                .edgesIgnoringSafeArea(.all)
            
            VStack {
                Spacer()
                Text(String(format: "距離: %.2f m", depthData.centerDepth))
                    .padding()
                    .background(Color.black.opacity(0.5))
                    .foregroundColor(.white)
                    .cornerRadius(8)
                    .padding(.bottom, 20)
            }
        }
        .overlay(
            CrossMarker(isTooClose: depthData.centerDepth < threshold)
                .frame(width: 40, height: 40),
            alignment: .center
        )
        .onChange(of: depthData.centerDepth) { newDepth, _ in
            if newDepth < threshold {
                if !didTriggerHaptic {
                    let generator = UIImpactFeedbackGenerator(style: .medium)
                    generator.impactOccurred()
                    didTriggerHaptic = true
                }
            } else {
                didTriggerHaptic = false
            }
        }
    }
}



#Preview {
    ContentView()
}

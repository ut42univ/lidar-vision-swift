//
//  ContentView.swift
//  lidar-vision-swift
//
//  Created by Takuya Uehara on 2025/02/28.
//

import SwiftUI

struct ContentView: View {
    @StateObject var depthData = DepthData()
    
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
    }
}



#Preview {
    ContentView()
}

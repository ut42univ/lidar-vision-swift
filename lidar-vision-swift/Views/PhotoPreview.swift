//
//  PhotoPreview.swift
//  lidar-vision-swift
//
//  Created by Takuya Uehara on 2025/03/06.
//

import SwiftUI

struct PhotoPreview: View {
    let image: UIImage
    let onClose: () -> Void
    
    var body: some View {
        ZStack(alignment: .topTrailing) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(maxWidth: 300, maxHeight: 300)
                .background(Color.black.opacity(0.8))
                .cornerRadius(12)
                .padding()
                .shadow(radius: 10)
            
            Button(action: onClose) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 32))
                    .foregroundColor(.white)
                    .padding(8)
            }
        }
    }
}

#Preview {
    PhotoPreview(image: UIImage(), onClose: { })
}

import SwiftUI

struct PhotoDetailModifier: ViewModifier {
    @EnvironmentObject var viewModel: ContentViewModel
    
    func body(content: Content) -> some View {
        content
            .fullScreenCover(isPresented: $viewModel.showPhotoDetail, onDismiss: {
                viewModel.resumeARSession()
            }) {
                if let capturedImage = viewModel.capturedImage {
                    PhotoDetailView(image: capturedImage)
                }
            }
    }
}

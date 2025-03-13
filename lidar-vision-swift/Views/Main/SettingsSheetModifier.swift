import SwiftUI

struct SettingsSheetModifier: ViewModifier {
    @EnvironmentObject var viewModel: ContentViewModel
    
    func body(content: Content) -> some View {
        content
            .sheet(isPresented: $viewModel.showSettings, onDismiss: {
                DispatchQueue.main.async {
                    viewModel.resumeARSession()
                }
            }) {
                AppSettingsView(
                    settings: viewModel.appSettings,
                    onSettingsChanged: { newSettings in
                        viewModel.updateSettings(newSettings)
                    }
                )
            }
    }
}

// 元ファイルで使用されていた拡張
extension View {
    func presentationModifiers() -> some View {
        self
            .modifier(PhotoDetailModifier())
            .modifier(SettingsSheetModifier())
    }
}

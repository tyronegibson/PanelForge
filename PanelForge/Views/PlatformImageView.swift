import SwiftUI

/// A platform-agnostic SwiftUI view that wraps PlatformImage.
struct PlatformImageView: View {
    let image: PlatformImage

    var body: some View {
        #if os(macOS)
        Image(nsImage: image)
            .resizable()
        #else
        Image(uiImage: image)
            .resizable()
        #endif
    }
}

import Foundation

/// The user's scene input that drives panel generation.
/// Named ComicScene to avoid shadowing SwiftUI.Scene.
struct ComicScene {
    var description: String
    var styleMode: StyleMode
    var selectedLoRAs: [LoRAModel]
    var layout: LayoutTemplate
}

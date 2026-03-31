import Foundation

/// A single generated comic panel.
struct Panel: Identifiable {
    var id: UUID = UUID()
    var prompt: String
    var negativePrompt: String
    var shotType: ShotType
    /// Short description of what is happening in this panel.
    var action: String
    var mood: String
    var charactersPresent: [String]
    /// Populated after image generation completes.
    var image: PlatformImage?
    /// Generation status for this individual panel.
    var state: PanelState = .pending

    enum PanelState {
        case pending
        case generating
        case complete
        case failed(String)
    }
}

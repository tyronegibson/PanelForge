import Foundation

/// A completed set of panels saved to the library.
struct GeneratedPage: Identifiable, Codable {
    var id: UUID = UUID()
    var createdAt: Date = Date()
    var layout: LayoutTemplate
    var sceneDescription: String
    var styleMode: StyleMode
    /// Filenames (relative to the library directory) for each panel image.
    var imageFilenames: [String]
}

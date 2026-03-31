import Foundation
#if os(macOS)
import AppKit
#endif

/// Persists and retrieves saved GeneratedPage records.
@MainActor
final class LibraryStore: ObservableObject {

    @Published var pages: [GeneratedPage] = []

    private let fm = FileManager.default

    private var libraryDir: URL {
        let docs = try! fm.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        return docs.appendingPathComponent("PanelForge/Library", isDirectory: true)
    }

    private var indexURL: URL { libraryDir.appendingPathComponent("index.json") }

    // MARK: - Init

    init() {
        load()
    }

    // MARK: - CRUD

    func add(_ page: GeneratedPage) {
        pages.insert(page, at: 0)
        save()
    }

    func delete(at offsets: IndexSet) {
        let toDelete = offsets.map { pages[$0] }
        pages.remove(atOffsets: offsets)
        save()
        // Remove associated image files.
        for page in toDelete {
            let dir = libraryDir.appendingPathComponent(page.id.uuidString, isDirectory: true)
            try? fm.removeItem(at: dir)
        }
    }

    /// Loads a PlatformImage for a stored panel image filename.
    func image(for page: GeneratedPage, at index: Int) -> PlatformImage? {
        guard index < page.imageFilenames.count else { return nil }
        let url = libraryDir
            .appendingPathComponent(page.id.uuidString)
            .appendingPathComponent(page.imageFilenames[index])
        guard let data = try? Data(contentsOf: url) else { return nil }
        return PlatformImage(data: data)
    }

    /// Saves panel images to disk and records the page in the library.
    func savePage(panels: [Panel], layout: LayoutTemplate, description: String, style: StyleMode) {
        let pageID = UUID()
        let dir = libraryDir.appendingPathComponent(pageID.uuidString, isDirectory: true)
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true)

        var filenames: [String] = []
        for (i, panel) in panels.enumerated() {
            guard let img = panel.image else { continue }
            let filename = "panel_\(i + 1).png"
            let url = dir.appendingPathComponent(filename)
            #if os(macOS)
            if let tiff = img.tiffRepresentation,
               let rep  = NSBitmapImageRep(data: tiff),
               let png  = rep.representation(using: .png, properties: [:]) {
                try? png.write(to: url)
            }
            #else
            try? img.pngData()?.write(to: url)
            #endif
            filenames.append(filename)
        }

        let page = GeneratedPage(
            id: pageID,
            createdAt: Date(),
            layout: layout,
            sceneDescription: description,
            styleMode: style,
            imageFilenames: filenames
        )
        add(page)
    }

    // MARK: - Persistence

    private func load() {
        try? fm.createDirectory(at: libraryDir, withIntermediateDirectories: true)
        guard let data = try? Data(contentsOf: indexURL),
              let decoded = try? JSONDecoder().decode([GeneratedPage].self, from: data)
        else { return }
        pages = decoded
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(pages) else { return }
        try? data.write(to: indexURL)
    }
}

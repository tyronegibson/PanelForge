import SwiftUI

@main
struct PanelForgeApp: App {
    @StateObject private var settings = AppSettings()
    @StateObject private var library = LibraryStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(settings)
                .environmentObject(library)
        }
        #if os(macOS)
        .defaultSize(width: 1200, height: 800)
        #endif
    }
}

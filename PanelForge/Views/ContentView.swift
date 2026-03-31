import SwiftUI

struct ContentView: View {
    var body: some View {
        #if os(macOS)
        MacContentView()
        #else
        IOSContentView()
        #endif
    }
}

// MARK: - iOS: Tab Bar Navigation

#if os(iOS)
private struct IOSContentView: View {
    var body: some View {
        TabView {
            GenerateView()
                .tabItem {
                    Label("Generate", systemImage: "paintbrush.pointed")
                }
            LibraryView()
                .tabItem {
                    Label("Library", systemImage: "photo.on.rectangle.angled")
                }
            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
        }
    }
}
#endif

// MARK: - macOS: Sidebar Navigation

#if os(macOS)
private enum SidebarItem: String, CaseIterable, Identifiable {
    case generate = "Generate"
    case library  = "Library"
    case settings = "Settings"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .generate: return "paintbrush.pointed"
        case .library:  return "photo.on.rectangle.angled"
        case .settings: return "gear"
        }
    }
}

private struct MacContentView: View {
    @State private var selection: SidebarItem? = .generate

    var body: some View {
        NavigationSplitView {
            List(SidebarItem.allCases, selection: $selection) { item in
                Label(item.rawValue, systemImage: item.icon)
                    .tag(item)
            }
            .navigationSplitViewColumnWidth(min: 180, ideal: 200)
            .navigationTitle("Panel Forge")
        } detail: {
            switch selection {
            case .generate, nil: GenerateView()
            case .library:       LibraryView()
            case .settings:      SettingsView()
            }
        }
    }
}
#endif

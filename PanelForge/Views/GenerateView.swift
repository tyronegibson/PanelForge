import SwiftUI

struct GenerateView: View {
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var library: LibraryStore
    @StateObject private var vm = GeneratorViewModel()

    @State private var description   = ""
    @State private var styleMode     = StyleMode.manga
    @State private var selectedLoRAs = Set<UUID>()
    @State private var layout        = LayoutTemplate.four
    @State private var showSaveAlert = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Panel Forge")
                    .font(.largeTitle).bold()
                    .padding(.top)

                // Scene description
                VStack(alignment: .leading, spacing: 6) {
                    Label("Scene Description", systemImage: "doc.text")
                        .font(.headline)
                    TextEditor(text: $description)
                        .frame(minHeight: 120)
                        .padding(8)
                        .background(Color.clear)
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.secondary.opacity(0.4)))
                        .scrollContentBackground(.hidden)
                }

                // Style picker
                VStack(alignment: .leading, spacing: 6) {
                    Label("Style", systemImage: "paintpalette")
                        .font(.headline)
                    Picker("Style Mode", selection: $styleMode) {
                        ForEach(StyleMode.allCases, id: \.self) { mode in
                            Text(mode.displayName).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                // Layout picker
                VStack(alignment: .leading, spacing: 6) {
                    Label("Layout", systemImage: "square.grid.2x2")
                        .font(.headline)
                    LayoutPickerView(selection: $layout)
                }

                // LoRA selector
                if !settings.loraModels.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Label("Character LoRAs", systemImage: "person.crop.circle.badge.plus")
                            .font(.headline)
                        LoRASelectorView(models: settings.loraModels, selection: $selectedLoRAs)
                    }
                }

                // Generate button
                Button {
                    Task {
                        let scene = buildScene()
                        await vm.generate(scene: scene)
                    }
                } label: {
                    HStack {
                        if vm.phase.isActive {
                            ProgressView().controlSize(.small)
                        }
                        Text(vm.phase.isActive ? buttonLabel(for: vm.phase) : "Generate Panels")
                            .bold()
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                }
                .buttonStyle(.borderedProminent)
                .disabled(description.trimmingCharacters(in: .whitespaces).isEmpty || vm.phase.isActive)

                // Error banner
                if let err = vm.errorMessage {
                    ErrorBanner(message: err)
                }

                // Panel grid
                if !vm.panels.isEmpty {
                    PanelGridView(panels: vm.panels, layout: layout)
                        .padding(.top)

                    if vm.phase == .complete {
                        HStack {
                            Spacer()
                            Button("Save to Library") {
                                library.savePage(
                                    panels: vm.panels,
                                    layout: layout,
                                    description: description,
                                    style: styleMode
                                )
                                showSaveAlert = true
                            }
                            .buttonStyle(.bordered)

                            ExportButton(panels: vm.panels, layout: layout)
                            Spacer()
                        }
                        .padding(.top, 8)
                    }
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 40)
        }
        .navigationTitle("Generate")
        .alert("Saved!", isPresented: $showSaveAlert) {
            Button("OK") {}
        } message: {
            Text("Page saved to your Library.")
        }
    }

    // MARK: - Helpers

    private func buildScene() -> ComicScene {
        let loraList = settings.loraModels.filter { selectedLoRAs.contains($0.id) }
        return ComicScene(
            description: description,
            styleMode: styleMode,
            selectedLoRAs: loraList,
            layout: layout
        )
    }

    private func buttonLabel(for phase: GeneratorViewModel.Phase) -> String {
        switch phase {
        case .parsingScene:                    return "Asking Claude…"
        case .generatingPanels(let n, let t):  return "Generating \(n)/\(t)…"
        default:                               return "Generate Panels"
        }
    }
}

// MARK: - Supporting sub-views

private struct ErrorBanner: View {
    let message: String
    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.red)
            Text(message)
                .font(.callout)
                .foregroundStyle(.primary)
            Spacer()
        }
        .padding()
        .background(Color.red.opacity(0.08))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.red.opacity(0.3)))
        .cornerRadius(8)
    }
}

struct LayoutPickerView: View {
    @Binding var selection: LayoutTemplate

    private let columns = [
        GridItem(.flexible()), GridItem(.flexible()),
        GridItem(.flexible()), GridItem(.flexible())
    ]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 10) {
            ForEach(LayoutTemplate.allCases, id: \.self) { template in
                LayoutThumbnail(template: template, isSelected: selection == template)
                    .onTapGesture { selection = template }
            }
        }
    }
}

private struct LayoutThumbnail: View {
    let template: LayoutTemplate
    let isSelected: Bool

    var body: some View {
        VStack(spacing: 4) {
            LayoutPreviewGrid(template: template)
                .frame(height: 60)
                .padding(6)
                .background(isSelected ? Color.accentColor.opacity(0.15) : Color.secondary.opacity(0.07))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(isSelected ? Color.accentColor : Color.secondary.opacity(0.3), lineWidth: isSelected ? 2 : 1)
                )
                .cornerRadius(8)
            Text(template.displayName)
                .font(.caption2)
                .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
        }
    }
}

private struct LayoutPreviewGrid: View {
    let template: LayoutTemplate

    var body: some View {
        switch template {
        case .two:
            VStack(spacing: 2) {
                rectangle; rectangle
            }
        case .three:
            HStack(spacing: 2) {
                rectangle; rectangle; rectangle
            }
        case .four:
            Grid(horizontalSpacing: 2, verticalSpacing: 2) {
                GridRow { rectangle; rectangle }
                GridRow { rectangle; rectangle }
            }
        case .six:
            Grid(horizontalSpacing: 2, verticalSpacing: 2) {
                GridRow { rectangle; rectangle; rectangle }
                GridRow { rectangle; rectangle; rectangle }
            }
        }
    }

    private var rectangle: some View {
        Color.secondary.opacity(0.4)
            .cornerRadius(2)
    }
}

struct LoRASelectorView: View {
    let models: [LoRAModel]
    @Binding var selection: Set<UUID>

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(models) { model in
                Toggle(isOn: Binding(
                    get: { selection.contains(model.id) },
                    set: { on in
                        if on { selection.insert(model.id) }
                        else  { selection.remove(model.id) }
                    }
                )) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(model.name).font(.subheadline)
                        Text(model.triggerWord).font(.caption).foregroundStyle(.secondary)
                    }
                }
                .toggleStyle(.button)
            }
        }
    }
}

private struct ExportButton: View {
    let panels: [Panel]
    let layout: LayoutTemplate

    var body: some View {
        if let image = try? ImageExporter().compositePage(panels: panels, layout: layout) {
            #if os(iOS)
            let uiImage = image
            ShareLink(item: Image(uiImage: uiImage), preview: SharePreview("Comic Page")) {
                Label("Export", systemImage: "square.and.arrow.up")
            }
            .buttonStyle(.bordered)
            #else
            // macOS: save panel via NSSavePanel
            Button("Export…") {
                exportOnMac(image: image)
            }
            .buttonStyle(.bordered)
            #endif
        }
    }

    #if os(macOS)
    private func exportOnMac(image: PlatformImage) {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.png]
        panel.nameFieldStringValue = "comic_page.png"
        if panel.runModal() == .OK, let url = panel.url {
            try? ImageExporter().savePage(image, to: url)
        }
    }
    #endif
}

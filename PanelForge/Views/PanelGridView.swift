import SwiftUI

/// Displays generated panels in the chosen layout with loading placeholders.
struct PanelGridView: View {
    let panels: [Panel]
    let layout: LayoutTemplate

    @State private var selectedPanel: Panel? = nil

    var body: some View {
        PanelLayout(panels: panels, layout: layout) { panel in
            PanelCell(panel: panel)
                .onTapGesture {
                    if case .complete = panel.state { selectedPanel = panel }
                }
        }
        .sheet(item: $selectedPanel) { panel in
            PanelDetailView(panel: panel)
        }
    }
}

// MARK: - Flexible layout engine

private struct PanelLayout<Content: View>: View {
    let panels: [Panel]
    let layout: LayoutTemplate
    let content: (Panel) -> Content

    var body: some View {
        switch layout {
        case .two:
            VStack(spacing: 4) {
                ForEach(panels) { content($0) }
            }
        case .three:
            HStack(spacing: 4) {
                ForEach(panels) { content($0) }
            }
        case .four:
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 4) {
                ForEach(panels) { content($0) }
            }
        case .six:
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 4) {
                ForEach(panels) { content($0) }
            }
        }
    }
}

// MARK: - Single panel cell

private struct PanelCell: View {
    let panel: Panel

    var body: some View {
        ZStack {
            Color.secondary.opacity(0.1)
                .aspectRatio(2/3, contentMode: .fit)

            switch panel.state {
            case .pending:
                VStack(spacing: 8) {
                    ProgressView()
                    Text("Waiting…")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            case .generating:
                VStack(spacing: 8) {
                    ProgressView()
                    Text("Generating…")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            case .complete:
                if let img = panel.image {
                    PlatformImageView(image: img)
                        .aspectRatio(contentMode: .fill)
                        .clipped()
                }
            case .failed(let reason):
                VStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundStyle(.red)
                    Text(reason)
                        .font(.caption2)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                }
                .padding(8)
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
        )
        .cornerRadius(4)
    }
}

// MARK: - Full-screen panel detail

private struct PanelDetailView: View {
    let panel: Panel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if let img = panel.image {
                        PlatformImageView(image: img)
                            .aspectRatio(contentMode: .fit)
                            .cornerRadius(8)
                    }
                    VStack(alignment: .leading, spacing: 6) {
                        InfoRow(label: "Shot",   value: panel.shotType.displayName)
                        InfoRow(label: "Action", value: panel.action)
                        InfoRow(label: "Mood",   value: panel.mood)
                        if !panel.charactersPresent.isEmpty {
                            InfoRow(label: "Characters", value: panel.charactersPresent.joined(separator: ", "))
                        }
                    }
                    .padding()
                    .background(Color.secondary.opacity(0.08))
                    .cornerRadius(8)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Positive Prompt").font(.caption).foregroundStyle(.secondary)
                        Text(panel.prompt).font(.caption2)
                    }
                }
                .padding()
            }
            .navigationTitle("Panel Detail")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

private struct InfoRow: View {
    let label: String
    let value: String
    var body: some View {
        HStack(alignment: .top) {
            Text(label + ":").font(.caption).bold().frame(width: 80, alignment: .leading)
            Text(value).font(.caption)
            Spacer()
        }
    }
}

import SwiftUI

struct LibraryView: View {
    @EnvironmentObject private var library: LibraryStore
    @State private var selectedPage: GeneratedPage? = nil

    private let columns = [
        GridItem(.adaptive(minimum: 200, maximum: 280), spacing: 12)
    ]

    var body: some View {
        Group {
            if library.pages.isEmpty {
                ContentUnavailableView(
                    "No Saved Pages",
                    systemImage: "photo.on.rectangle.angled",
                    description: Text("Generated comic pages will appear here after you save them.")
                )
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(library.pages) { page in
                            LibraryCard(page: page)
                                .onTapGesture { selectedPage = page }
                        }
                    }
                    .padding()
                }
            }
        }
        .navigationTitle("Library")
        .sheet(item: $selectedPage) { page in
            LibraryPageDetail(page: page)
        }
        #if os(iOS)
        .toolbar {
            if !library.pages.isEmpty {
                EditButton()
            }
        }
        #endif
    }
}

// MARK: - Library card thumbnail

private struct LibraryCard: View {
    @EnvironmentObject private var library: LibraryStore
    let page: GeneratedPage

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ZStack {
                Color.secondary.opacity(0.1)
                    .aspectRatio(3/4, contentMode: .fit)
                    .cornerRadius(8)

                if let firstImage = library.image(for: page, at: 0) {
                    PlatformImageView(image: firstImage)
                        .aspectRatio(3/4, contentMode: .fill)
                        .clipped()
                        .cornerRadius(8)
                } else {
                    Image(systemName: "photo")
                        .font(.largeTitle)
                        .foregroundStyle(.tertiary)
                }
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(page.layout.displayName)
                    .font(.caption).bold()
                Text(page.sceneDescription)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                Text(page.createdAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 4)
        }
    }
}

// MARK: - Page detail sheet

private struct LibraryPageDetail: View {
    @EnvironmentObject private var library: LibraryStore
    let page: GeneratedPage
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text(page.sceneDescription)
                        .font(.subheadline)
                        .padding()
                        .background(Color.secondary.opacity(0.08))
                        .cornerRadius(8)

                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 6) {
                        ForEach(0..<page.imageFilenames.count, id: \.self) { i in
                            if let img = library.image(for: page, at: i) {
                                PlatformImageView(image: img)
                                    .aspectRatio(contentMode: .fit)
                                    .cornerRadius(6)
                            } else {
                                Color.secondary.opacity(0.1)
                                    .aspectRatio(2/3, contentMode: .fit)
                                    .cornerRadius(6)
                                    .overlay(Image(systemName: "photo").foregroundStyle(.tertiary))
                            }
                        }
                    }
                }
                .padding()
            }
            .navigationTitle(page.layout.displayName)
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

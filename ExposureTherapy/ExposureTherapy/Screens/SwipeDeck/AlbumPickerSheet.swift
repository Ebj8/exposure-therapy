//
//  AlbumPickerSheet.swift
//  ExposureTherapy
//
//  SPEC.md → Gestures and interactions → Album picker. A half-height sheet
//  of your albums, newest first, with the last album used pinned on top.
//

import SwiftUI

struct AlbumPickerSheet: View {
    /// Called with an existing album's ID.
    let onPick: (String) -> Void
    /// Called with the name for a new album.
    let onCreate: (String) -> Void

    @Environment(PhotoLibrary.self) private var library
    @Environment(\.dismiss) private var dismiss
    @AppStorage(SettingsKey.lastAlbumID) private var lastAlbumID = ""

    @State private var albums: [PhotoAlbum]?
    @State private var isNamingAlbum = false
    @State private var newAlbumName = ""

    /// The last album used first, then the rest newest first.
    private var orderedAlbums: [PhotoAlbum] {
        guard let albums else { return [] }
        guard let pinned = albums.first(where: { $0.id == lastAlbumID }) else { return albums }
        return [pinned] + albums.filter { $0.id != lastAlbumID }
    }

    var body: some View {
        NavigationStack {
            List {
                Button {
                    newAlbumName = ""
                    isNamingAlbum = true
                } label: {
                    Label("New album…", systemImage: "plus.rectangle.on.rectangle")
                        .font(.inter(16, .semibold))
                        .foregroundStyle(.rose)
                }

                if albums == nil {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                } else {
                    ForEach(orderedAlbums) { album in
                        Button {
                            onPick(album.id)
                        } label: {
                            row(for: album)
                        }
                    }
                }
            }
            .navigationTitle("Add to album")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .alert("New album", isPresented: $isNamingAlbum) {
                TextField("Album name", text: $newAlbumName)
                Button("Cancel", role: .cancel) {}
                Button("Create") {
                    let name = newAlbumName.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !name.isEmpty {
                        onCreate(name)
                    }
                }
            } message: {
                Text("The photo will be added to it.")
            }
        }
        .presentationDetents([.medium, .large])
        .task {
            albums = await library.albums()
        }
    }

    private func row(for album: PhotoAlbum) -> some View {
        HStack {
            Image(systemName: album.id == lastAlbumID ? "pin.fill" : "rectangle.stack")
                .foregroundStyle(album.id == lastAlbumID ? .rose : .muted)
                .frame(width: 24)
                .accessibilityHidden(true)
            Text(album.title)
                .font(.inter(16))
                .foregroundStyle(.plum)
            Spacer()
            Text(album.count.formatted())
                .font(.inter(15))
                .foregroundStyle(.muted)
        }
        .accessibilityElement(children: .combine)
        .accessibilityHint(album.id == lastAlbumID ? "Last album used" : "")
    }
}

#Preview {
    Color.cream
        .sheet(isPresented: .constant(true)) {
            AlbumPickerSheet(onPick: { _ in }, onCreate: { _ in })
        }
        .environment(PreviewData.library())
}

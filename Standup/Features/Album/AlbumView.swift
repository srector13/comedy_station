import SwiftUI

/// A special's page, Music style: large artwork, title, comedian and year,
/// Play and Shuffle, editorial notes, the bits with their durations, and the
/// total runtime. A special plays as one continuous set.
struct AlbumView: View {
    let album: ComedyAlbum

    @Environment(\.catalog) private var catalog
    @Environment(\.play) private var play
    @State private var detail: LoadState<AlbumDetail> = .loading
    @State private var showsNotes = false
    @State private var showsTitle = false
    @State private var showsArtist = false

    /// The loaded album once there is one (it knows its comedian's ID).
    private var shown: ComedyAlbum { detail.value?.album ?? album }

    var body: some View {
        List {
            header
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(top: 0, leading: 20, bottom: 12, trailing: 20))

            switch detail {
            case .loading:
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .listRowSeparator(.hidden)
            case .failed(let message):
                ContentUnavailableView {
                    Label("Couldn't Load This Special", systemImage: "exclamationmark.triangle")
                } description: {
                    Text(message)
                }
                .listRowSeparator(.hidden)
            case .loaded(let detail):
                if let notes = detail.editorialNotes {
                    notesRow(notes)
                        .listRowSeparator(.hidden)
                }
                ForEach(Array(detail.tracks.enumerated()), id: \.element.id) { index, track in
                    Button {
                        play(PlayRequest(item: .album(shown), startIndex: index))
                    } label: {
                        TrackRow(number: track.trackNumber ?? index + 1, track: track)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("album.track.\(index)")
                }
                footer(detail)
                    .listRowSeparator(.hidden)
            }
        }
        .listStyle(.plain)
        .navigationTitle(shown.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                // Music shows the title in the bar only once the header has
                // scrolled away.
                Text(shown.title)
                    .font(.headline)
                    .lineLimit(1)
                    .opacity(showsTitle ? 1 : 0)
                    .accessibilityHidden(!showsTitle)
            }
        }
        .onScrollGeometryChange(for: Bool.self) { geometry in
            geometry.contentOffset.y + geometry.contentInsets.top > 360
        } action: { _, pastHeader in
            withAnimation(.easeInOut(duration: 0.2)) { showsTitle = pastHeader }
        }
        .navigationDestination(isPresented: $showsArtist) {
            if let artistID = shown.artistID {
                ArtistView(artist: ComedyArtist(
                    id: artistID, name: shown.artistName,
                    artwork: ArtworkRef(generatedFor: artistID), genreNames: shown.genreNames
                ))
            }
        }
        .sheet(isPresented: $showsNotes) {
            if let notes = detail.value?.editorialNotes {
                NotesSheet(title: shown.title, notes: notes)
            }
        }
        .task(id: album.id) {
            do {
                detail = .loaded(try await catalog.album(id: album.id))
            } catch {
                detail = .failed(error.localizedDescription)
            }
        }
    }

    private var header: some View {
        VStack(spacing: 6) {
            ArtworkView(shown.artwork, placeholder: .poster(shown.title), pixels: 1000)
                .clipShape(.rect(cornerRadius: 12))
                .shadow(color: .black.opacity(0.25), radius: 18, y: 10)
                .frame(maxWidth: 290)
                .padding(.horizontal, 28)
                .padding(.top, 8)
                .padding(.bottom, 14)

            Text(shown.title)
                .font(.title2.bold())
                .multilineTextAlignment(.center)
                .accessibilityAddTraits(.isHeader)

            Button {
                showsArtist = true
            } label: {
                Text(shown.artistName)
                    .font(.title3)
                    .foregroundStyle(Theme.accent)
            }
            .buttonStyle(.plain)
            .disabled(shown.artistID == nil)
            .accessibilityHint("Shows the comedian's page")

            HStack(spacing: 4) {
                Text(["Comedy", Format.year(shown.releaseDate)].compactMap { $0 }.joined(separator: " · "))
                if shown.isExplicit { ExplicitBadge() }
            }
            .font(.footnote)
            .foregroundStyle(.secondary)

            HStack(spacing: 12) {
                Button {
                    play(PlayRequest(item: .album(shown)))
                } label: {
                    Label("Play", systemImage: "play.fill")
                        .frame(maxWidth: .infinity)
                }
                .accessibilityIdentifier("album.play")
                Button {
                    play(PlayRequest(item: .album(shown), shuffle: true))
                } label: {
                    Label("Shuffle", systemImage: "shuffle")
                        .frame(maxWidth: .infinity)
                }
                .accessibilityIdentifier("album.shuffle")
            }
            .font(.headline)
            .foregroundStyle(Theme.accent)
            .buttonStyle(.glass)
            .controlSize(.large)
            .padding(.top, 14)
        }
        .frame(maxWidth: .infinity)
        .accessibilityIdentifier("album.header")
    }

    private func notesRow(_ notes: String) -> some View {
        Button {
            showsNotes = true
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                Text(notes)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
                    .multilineTextAlignment(.leading)
                Text("More")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.accent)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("About this special")
        .accessibilityHint("Shows the full notes")
    }

    private func footer(_ detail: AlbumDetail) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            if let date = Format.longDate(detail.album.releaseDate) {
                Text(date)
            }
            Text("\(Format.bitCount(detail.tracks.count)), \(Format.runtime(detail.totalDuration))")
            if let copyright = detail.copyright {
                Text(copyright)
            }
        }
        .font(.footnote)
        .foregroundStyle(.secondary)
        .padding(.vertical, 12)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("album.footer")
    }
}

/// One bit on a special's page: number, title, duration.
struct TrackRow: View {
    let number: Int
    let track: ComedyTrack

    var body: some View {
        HStack(spacing: 14) {
            Text("\(number)")
                .font(.body)
                .monospacedDigit()
                .foregroundStyle(.secondary)
                .frame(minWidth: 22, alignment: .trailing)
            HStack(spacing: 4) {
                Text(track.title)
                    .lineLimit(2)
                if track.isExplicit { ExplicitBadge() }
            }
            Spacer(minLength: 8)
            Text(Format.trackTime(track.duration))
                .font(.subheadline)
                .monospacedDigit()
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 6)
        .contentShape(.rect)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(number). \(track.title), \(Format.trackTime(track.duration))")
        .accessibilityHint("Plays the special from this bit")
    }
}

/// The full editorial notes.
struct NotesSheet: View {
    let title: String
    let notes: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                Text(notes)
                    .font(.body)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done", systemImage: "checkmark") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

#Preview {
    NavigationStack {
        AlbumView(album: MockData.albums[0])
            .comedyDestinations()
    }
    .tint(Theme.accent)
}

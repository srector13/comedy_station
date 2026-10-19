import SwiftUI

/// A comedy playlist: artwork, name, curator, notes, Play/Shuffle, and its
/// bits. Only bits on comedy specials are listed (rule 3).
struct PlaylistView: View {
    let playlist: ComedyPlaylist

    @Environment(\.catalog) private var catalog
    @Environment(\.play) private var play
    @State private var detail: LoadState<PlaylistDetail> = .loading

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
                    Label("Couldn't Load This Playlist", systemImage: "exclamationmark.triangle")
                } description: {
                    Text(message)
                }
                .listRowSeparator(.hidden)
            case .loaded(let detail):
                ForEach(Array(detail.tracks.enumerated()), id: \.element.id) { index, track in
                    Button {
                        play(PlayRequest(item: .playlist(playlist), startIndex: index, trackID: track.id))
                    } label: {
                        BitRow(track: track, subtitle: [track.artistName, track.albumTitle].compactMap { $0 }.joined(separator: " · "))
                    }
                    .buttonStyle(.plain)
                    .libraryContextMenu(.bit(track))
                    .librarySwipeActions(.bit(track))
                    .accessibilityIdentifier("playlist.track.\(index)")
                }
                Text(Format.bitCount(detail.tracks.count) + ", " + Format.runtime(detail.tracks.compactMap(\.duration).reduce(0, +)))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 12)
                    .listRowSeparator(.hidden)
            }
        }
        .listStyle(.plain)
        .navigationTitle(playlist.name)
        .navigationBarTitleDisplayMode(.inline)
        .task(id: playlist.id) {
            do {
                detail = .loaded(try await catalog.playlist(id: playlist.id))
            } catch {
                detail = .failed(error.localizedDescription)
            }
        }
    }

    private var header: some View {
        VStack(spacing: 6) {
            ArtworkView(playlist.artwork, placeholder: .poster(playlist.name), pixels: 1000)
                .clipShape(.rect(cornerRadius: 12))
                .shadow(color: .black.opacity(0.25), radius: 18, y: 10)
                .frame(maxWidth: 260)
                .padding(.top, 8)
                .padding(.bottom, 14)
            Text(playlist.name)
                .font(.title2.bold())
                .multilineTextAlignment(.center)
                .accessibilityAddTraits(.isHeader)
            if let curator = playlist.curatorName {
                Text(curator)
                    .font(.title3)
                    .foregroundStyle(Theme.accent)
            }
            if let summary = playlist.summary {
                Text(summary)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            PlayButtonsLayout {
                Button {
                    play(PlayRequest(item: .playlist(playlist)))
                } label: {
                    Label("Play", systemImage: "play.fill")
                        .frame(maxWidth: .infinity)
                }
                .accessibilityIdentifier("playlist.play")
                Button {
                    play(PlayRequest(item: .playlist(playlist), shuffle: true))
                } label: {
                    Label("Shuffle", systemImage: "shuffle")
                        .frame(maxWidth: .infinity)
                }
            }
            .font(.headline)
            .foregroundStyle(Theme.accent)
            .buttonStyle(.glass)
            .controlSize(.large)
            .padding(.top, 14)
        }
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    NavigationStack {
        PlaylistView(playlist: MockData.playlists[1])
            .comedyDestinations()
    }
    .previewEnvironment()
}

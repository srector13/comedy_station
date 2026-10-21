import SwiftUI

/// Browse: TMDB's stand-up by streaming service and by decade, shown as the
/// specials on the service Standup runs on. On Apple Music, Apple's Comedy
/// charts too: a featured special up top, then the TMDB grids, Top
/// Specials, Top Bits (tap to play) and Playlists. Spotify has no charts
/// for an app like this, so its Browse is the grids alone.
struct BrowseView: View {
    @State private var charts: LoadState<ComedyCharts> = .loading
    @State private var categories: LoadState<[BrowseCategory]> = .loading

    @Environment(\.catalog) private var catalog
    @Environment(\.play) private var play
    @Environment(SpecialsSettings.self) private var specials
    @Environment(ServiceChoice.self) private var service

    private var provider: Provider {
        service.provider ?? .appleMusic
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 34) {
                    if provider == .appleMusic {
                        appleMusicSections
                    } else {
                        tmdbOnlySections
                    }
                }
                .padding(.vertical, 12)
            }
            .navigationTitle("Browse")
            .settingsButton()
            .comedyDestinations()
            // Again when the TMDB key changes in Settings.
            .task(id: specials.revision) { await load() }
            .refreshable { await load() }
        }
    }

    // MARK: Sections

    @ViewBuilder
    private var appleMusicSections: some View {
        switch charts {
        case .loading:
            // TMDB's grids usually arrive first; placeholders for the rest.
            BannerSkeleton()
                .loadingPlaceholder("browse.loading")
            if categories.value != nil {
                categorySections
            } else {
                CategoriesSkeleton()
                    .loadingPlaceholder("browse.loading")
            }
            ShelfSkeleton()
                .loadingPlaceholder("browse.loading")
        case .failed(let message):
            categorySections
            failure(message)
        case .loaded(let charts):
            featured(charts)
            categorySections
            chartSections(charts)
        }
    }

    /// Spotify's: the TMDB grids, which need a key.
    @ViewBuilder
    private var tmdbOnlySections: some View {
        switch categories {
        case .loading:
            CategoriesSkeleton()
                .loadingPlaceholder("browse.loading")
        case .failed(let message):
            failure(message)
        case .loaded(let list) where list.isEmpty:
            ContentUnavailableView(
                "Add a TMDB Key",
                systemImage: "sparkles.tv",
                description: Text("Browse lists stand-up by streaming service and by decade, from TMDB. Add your free TMDB key in Settings (the gear above), and Browse shows the specials on \(provider.name).")
            )
            .accessibilityIdentifier("browse.needsKey")
        case .loaded:
            categorySections
        }
    }

    /// Streaming services, then decades.
    @ViewBuilder
    private var categorySections: some View {
        if let list = categories.value {
            let services = list.filter { !$0.isDecade }
            let decades = list.filter(\.isDecade)
            if !services.isEmpty {
                serviceGrid(services)
            }
            if !decades.isEmpty {
                categoryGrid("Decades", decades, id: "browse.decades")
            }
        }
    }

    /// The services' logos, app-icon style.
    private func serviceGrid(_ services: [BrowseCategory]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            ShelfHeader(title: "Streaming Services")
            // Top-aligned, so a name on two lines doesn't lift its logo.
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 92, maximum: 140), spacing: 16, alignment: .top)], spacing: 18) {
                ForEach(services) { service in
                    NavigationLink(value: Route.category(service)) {
                        ServiceTile(service: service)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("browse.category.\(service.id)")
                }
            }
            .padding(.horizontal, 20)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("browse.services")
    }

    private func categoryGrid(_ title: String, _ items: [BrowseCategory], id: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            ShelfHeader(title: title)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 12)], spacing: 12) {
                ForEach(items) { category in
                    NavigationLink(value: Route.category(category)) {
                        CategoryTile(category: category)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("browse.category.\(category.id)")
                }
            }
            .padding(.horizontal, 20)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(id)
    }

    @ViewBuilder
    private func featured(_ charts: ComedyCharts) -> some View {
        if let featured = charts.newSpecials().first ?? charts.topSpecials.first {
            NavigationLink(value: Route.album(featured)) {
                FeaturedBanner(album: featured, label: !charts.newSpecials().isEmpty ? "NEW SPECIAL" : charts.specialsSource == .chart ? "TOP SPECIAL" : "FEATURED SPECIAL")
            }
            .buttonStyle(.plain)
            .libraryContextMenu(.special(featured))
            .padding(.horizontal, 20)
            .accessibilityIdentifier("browse.featured")
        }
    }

    @ViewBuilder
    private func chartSections(_ charts: ComedyCharts) -> some View {
        if !charts.topSpecials.isEmpty {
            Shelf(title: charts.specialsTitle) {
                ForEach(charts.topSpecials) { album in
                    NavigationLink(value: Route.album(album)) {
                        SpecialCard(album: album)
                    }
                    .buttonStyle(.plain)
                    .libraryContextMenu(.special(album))
                }
            }
        }

        if !charts.topBits.isEmpty {
            RankedGrid(title: charts.bitsTitle, items: charts.topBits) { rank, track in
                Button {
                    if let album = track.albumStub {
                        play(PlayRequest(item: .album(album), startIndex: max((track.trackNumber ?? 1) - 1, 0), trackID: track.id))
                    }
                } label: {
                    RankedRow(rank: charts.bitRank(rank), title: track.title, subtitle: track.artistName, artwork: track.artwork, placeholderTitle: track.albumTitle ?? track.title)
                }
                .buttonStyle(.plain)
                .libraryContextMenu(.bit(track))
                .accessibilityHint("Plays the special from this bit")
            }
        }

        if !charts.playlists.isEmpty {
            Shelf(title: "Comedy Playlists") {
                ForEach(charts.playlists) { playlist in
                    NavigationLink(value: Route.playlist(playlist)) {
                        PlaylistCard(playlist: playlist)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("browse.playlist.\(playlist.id)")
                }
            }
        }
    }

    private func failure(_ message: String) -> some View {
        ContentUnavailableView {
            Label("Can't Load Browse", systemImage: "wifi.exclamationmark")
        } description: {
            Text(message)
        } actions: {
            Button("Try Again") {
                Task { await load() }
            }
            .buttonStyle(.glass)
        }
    }

    // MARK: Loading

    /// TMDB's lists first (quick), then on Apple Music the charts.
    private func load() async {
        let provider = self.provider
        do {
            categories = .loaded(try await catalog.browseCategories(in: provider))
        } catch {
            if categories.value == nil {
                categories = .failed(error.localizedDescription)
            }
        }
        guard provider == .appleMusic else { return }
        do {
            charts = .loaded(try await catalog.charts())
        } catch {
            if charts.value == nil {
                charts = .failed(error.localizedDescription)
            }
        }
    }
}

/// A streaming service's tile: its logo, as on a Home Screen, over its
/// name. The logo comes from TMDB; without one (offline, mock mode) its
/// initials stand in.
struct ServiceTile: View {
    let service: BrowseCategory

    var body: some View {
        VStack(spacing: 8) {
            ArtworkView(service.logo ?? ArtworkRef(seed: ArtworkRef.seed(for: service.id)), placeholder: .monogram(service.title), pixels: 154)
                .clipShape(.rect(cornerRadius: 20))
                .overlay {
                    RoundedRectangle(cornerRadius: 20)
                        .strokeBorder(.quaternary, lineWidth: 0.5)
                }
                .shadow(color: .black.opacity(0.12), radius: 6, y: 3)
            Text(service.title)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.primary)
                .lineLimit(2)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .contentShape(.rect)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(service.title)
        .accessibilityAddTraits(.isButton)
    }
}

/// A Browse list's tile: its name on a color of its own, like Music's
/// category tiles.
struct CategoryTile: View {
    let category: BrowseCategory

    var body: some View {
        let tint = ArtworkRef(generatedFor: category.id).tint
        Text(category.title)
            .font(.headline)
            .foregroundStyle(.white)
            .multilineTextAlignment(.leading)
            .padding(14)
            .frame(maxWidth: .infinity, minHeight: 84, alignment: .bottomLeading)
            .background(
                LinearGradient(colors: [tint, tint.mix(with: .black, by: 0.45)], startPoint: .topLeading, endPoint: .bottomTrailing),
                in: .rect(cornerRadius: 14)
            )
            .contentShape(.rect(cornerRadius: 14))
            .accessibilityAddTraits(.isButton)
    }
}

/// A big card for one special, tinted from its artwork, like Music's
/// editorial banners.
struct FeaturedBanner: View {
    let album: ComedyAlbum
    let label: String

    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        let layout = typeSize.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading, spacing: 14)) : AnyLayout(HStackLayout(spacing: 16))
        layout {
            ArtworkView(album.artwork, placeholder: .poster(album.title), pixels: 600)
                .frame(width: 132, height: 132)
                .clipShape(.rect(cornerRadius: 10))
                .shadow(color: .black.opacity(0.3), radius: 10, y: 6)
            VStack(alignment: .leading, spacing: 6) {
                Text(label)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white.opacity(0.85))
                Text(album.title)
                    .font(.title2.bold())
                    .foregroundStyle(.white)
                    .lineLimit(3)
                Text([album.artistName, Format.year(album.releaseDate)].compactMap { $0 }.joined(separator: " · "))
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.85))
            }
            Spacer(minLength: 0)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(colors: [album.artwork.tint, album.artwork.tint.mix(with: .black, by: 0.55)], startPoint: .topLeading, endPoint: .bottomTrailing),
            in: .rect(cornerRadius: 22)
        )
        .contentShape(.rect(cornerRadius: 22))
        .accessibilityElement(children: .combine)
        .accessibilityHint("Shows the special")
    }
}

#Preview {
    BrowseView()
        .previewEnvironment()
}

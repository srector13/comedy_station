import SwiftUI

/// The App Library's sections, as rows like Music's library.
enum LibraryCategory: String, CaseIterable, Identifiable, Hashable {
    case comedians, specials, bits, recentlyAdded, downloads

    var id: Self { self }

    var title: String {
        switch self {
        case .comedians: "Comedians"
        case .specials: "Specials"
        case .bits: "Bits"
        case .recentlyAdded: "Recently Added"
        case .downloads: "Downloads"
        }
    }

    var symbol: String {
        switch self {
        case .comedians: "music.mic"
        case .specials: "square.stack"
        case .bits: "quote.bubble"
        case .recentlyAdded: "clock"
        case .downloads: "arrow.down.circle"
        }
    }

    var emptyMessage: String {
        switch self {
        case .comedians: "Comedians you add from search or an artist page appear here."
        case .specials: "Add a special with the + button on its page."
        case .bits: "Swipe on a track to add a single bit."
        case .recentlyAdded: "Everything you add shows up here, newest first."
        case .downloads: "Downloads aren't available yet."
        }
    }
}

/// The Library tab. It reads only Standup's own store, never the Apple Music
/// library.
struct LibraryView: View {
    var body: some View {
        NavigationStack {
            List {
                ForEach(LibraryCategory.allCases) { category in
                    NavigationLink(value: category) {
                        Label {
                            Text(category.title)
                                .font(.title3)
                        } icon: {
                            Image(systemName: category.symbol)
                                .foregroundStyle(Theme.accent)
                        }
                    }
                    .accessibilityIdentifier("library.\(category.rawValue)")
                }
            }
            .listStyle(.plain)
            .navigationTitle("Library")
            .navigationDestination(for: LibraryCategory.self) { category in
                LibraryCategoryView(category: category)
            }
        }
    }
}

/// One library section. Empty until the App Library store lands (Phase 3).
struct LibraryCategoryView: View {
    let category: LibraryCategory

    var body: some View {
        ContentUnavailableView {
            Label("No \(category.title)", systemImage: category.symbol)
        } description: {
            Text(category.emptyMessage)
        }
        .navigationTitle(category.title)
        .navigationBarTitleDisplayMode(.large)
    }
}

#Preview {
    LibraryView()
        .tint(Theme.accent)
}

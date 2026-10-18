import SwiftUI

/// The search tab. Catalog search and suggestions arrive in Phase 2.
struct SearchView: View {
    @State private var query = ""

    var body: some View {
        NavigationStack {
            Group {
                if query.isEmpty {
                    ContentUnavailableView {
                        Label("Search Comedy", systemImage: "magnifyingglass")
                    } description: {
                        Text("Find comedians, specials, and bits.")
                    }
                } else {
                    ContentUnavailableView.search(text: query)
                }
            }
            .navigationTitle("Search")
        }
        .searchable(text: $query, prompt: "Comedians, Specials, and Bits")
    }
}

#Preview {
    SearchView()
        .tint(Theme.accent)
}

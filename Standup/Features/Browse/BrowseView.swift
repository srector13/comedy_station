import SwiftUI

/// Browse: the Comedy charts and comedy playlists (Phase 5).
struct BrowseView: View {
    var body: some View {
        NavigationStack {
            ScrollView {
                ContentUnavailableView {
                    Label("Browse Comedy", systemImage: "square.grid.2x2")
                } description: {
                    Text("Top comedy charts and comedy playlists from the Apple Music catalog.")
                }
                .padding(.top, 80)
            }
            .navigationTitle("Browse")
            .comedyDestinations()
        }
    }
}

#Preview {
    BrowseView()
        .tint(Theme.accent)
}

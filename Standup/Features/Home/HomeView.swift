import SwiftUI

/// Home: Continue Listening, New Specials, Top Comedy and Recently Added
/// (Phase 5). For now, the empty state Continue Listening will show.
struct HomeView: View {
    @State private var path: [Route]

    init(initialPath: [Route] = []) {
        _path = State(initialValue: initialPath)
    }

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                ContentUnavailableView {
                    Label("Nothing Playing Yet", systemImage: "music.mic")
                } description: {
                    Text("Specials you start show up here, so you can pick up right where the set left off.")
                }
                .padding(.top, 80)
            }
            .navigationTitle("Home")
            .comedyDestinations()
        }
    }
}

#Preview {
    HomeView()
        .tint(Theme.accent)
}

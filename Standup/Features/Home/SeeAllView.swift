import SwiftUI

/// All of a Home shelf's specials (See All), in a grid.
struct SeeAllSpecialsView: View {
    let title: String
    let albums: [ComedyAlbum]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 16, alignment: .top)], spacing: 22) {
                ForEach(albums) { album in
                    NavigationLink(value: Route.album(album)) {
                        SpecialCard(album: album, width: nil, showsComedian: true)
                    }
                    .buttonStyle(.plain)
                    .libraryContextMenu(.special(album))
                    .accessibilityIdentifier("seeAll.\(album.id)")
                }
            }
            .padding(20)
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.large)
    }
}

#Preview {
    NavigationStack {
        SeeAllSpecialsView(title: "New Specials", albums: MockData.albums)
            .comedyDestinations()
    }
    .previewEnvironment()
}

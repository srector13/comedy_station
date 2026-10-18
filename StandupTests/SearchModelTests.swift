import Testing
@testable import Standup

/// Counts the searches that reach the catalog.
actor CountingCatalog: CatalogProviding {
    private let base = MockCatalog()
    private(set) var searchedTerms: [String] = []

    func suggestions(for term: String) async throws -> [SearchSuggestion] {
        try await base.suggestions(for: term)
    }

    func search(_ term: String) async throws -> SearchResults {
        searchedTerms.append(term)
        return try await base.search(term)
    }

    func album(id: String) async throws -> AlbumDetail { try await base.album(id: id) }
    func artist(id: String) async throws -> ArtistDetail { try await base.artist(id: id) }
}

@MainActor
struct SearchModelTests {
    @Test func burstOfKeystrokesMakesOneSearch() async throws {
        let catalog = CountingCatalog()
        let model = SearchModel(catalog: catalog, debounce: .milliseconds(150))
        for prefix in ["m", "ma", "may", "maya"] {
            model.query = prefix
            model.queryChanged()
            try await Task.sleep(for: .milliseconds(20))
        }
        try await Task.sleep(for: .milliseconds(500))
        #expect(await catalog.searchedTerms == ["maya"])
        #expect(model.phase == .results)
        #expect(model.results.comedians.map(\.name) == ["Maya Okafor"])
    }

    @Test func suggestionsAreShownUntilSubmit() async throws {
        let model = SearchModel(catalog: MockCatalog(), debounce: .milliseconds(10))
        model.query = "lou"
        model.queryChanged()
        try await Task.sleep(for: .milliseconds(300))
        #expect(!model.visibleSuggestions.isEmpty)
        model.submit()
        #expect(model.visibleSuggestions.isEmpty)
    }

    @Test func pickedSuggestionHidesTheList() async throws {
        let model = SearchModel(catalog: MockCatalog(), debounce: .milliseconds(10))
        model.query = "lou"
        model.queryChanged()
        try await Task.sleep(for: .milliseconds(300))
        let picked = try #require(model.visibleSuggestions.first)
        model.query = picked.title
        #expect(model.visibleSuggestions.isEmpty)
    }

    @Test func clearingTheFieldResets() async throws {
        let model = SearchModel(catalog: MockCatalog(), debounce: .milliseconds(10))
        model.query = "maya"
        model.submit()
        try await Task.sleep(for: .milliseconds(200))
        #expect(model.phase == .results)
        model.query = "  "
        model.queryChanged()
        #expect(model.phase == .idle)
        #expect(model.results.isEmpty)
    }

    @Test func nothingFound() async throws {
        let model = SearchModel(catalog: MockCatalog(), debounce: .milliseconds(10))
        model.query = "zzzz"
        model.submit()
        try await Task.sleep(for: .milliseconds(200))
        #expect(model.phase == .noResults)
    }
}

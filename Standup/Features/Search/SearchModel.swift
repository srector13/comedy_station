import Observation

/// The search tab's state: as-you-type suggestions and results, both
/// debounced so a burst of keystrokes makes one request.
@MainActor
@Observable
final class SearchModel {
    enum Phase: Equatable {
        case idle
        case searching
        case results
        case noResults
        case failed(String)
    }

    /// The search field's text.
    var query = ""
    /// Which service to search (the switch shown once Spotify is connected).
    private(set) var provider = Provider.appleMusic
    private(set) var phase: Phase = .idle
    private(set) var results = SearchResults()
    private(set) var suggestions: [SearchSuggestion] = []
    /// The term last submitted (Search key or a picked suggestion); its
    /// suggestions stay hidden so the results show.
    private(set) var submittedTerm: String?

    @ObservationIgnored private let catalog: any CatalogProviding
    @ObservationIgnored private let debounce: Duration
    @ObservationIgnored private var pending: Task<Void, Never>?

    init(catalog: any CatalogProviding, query: String = "", debounce: Duration = .milliseconds(300)) {
        self.catalog = catalog
        self.query = query
        self.debounce = debounce
    }

    var term: String {
        query.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Suggestions to offer under the field: none once the term was
    /// submitted, or once it is exactly a suggestion's title (one was picked).
    var visibleSuggestions: [SearchSuggestion] {
        guard !term.isEmpty, term != submittedTerm,
              !suggestions.contains(where: { $0.title.localizedCaseInsensitiveCompare(term) == .orderedSame })
        else { return [] }
        return suggestions
    }

    /// Call when `query` changes: searches after the debounce.
    func queryChanged() {
        pending?.cancel()
        let term = self.term
        guard !term.isEmpty else {
            results = SearchResults()
            suggestions = []
            submittedTerm = nil
            phase = .idle
            return
        }
        if term != submittedTerm {
            submittedTerm = nil
        }
        let debounce = self.debounce
        pending = Task {
            do {
                try await Task.sleep(for: debounce)
            } catch {
                return
            }
            await load(term)
        }
    }

    /// The switch: clears what the other service found and searches this one.
    func setProvider(_ newValue: Provider) {
        guard newValue != provider else { return }
        provider = newValue
        results = SearchResults()
        suggestions = []
        let term = self.term
        guard !term.isEmpty else { return }
        pending?.cancel()
        pending = Task { await load(term) }
    }

    /// `provider` as the switch's binding target.
    var searchProvider: Provider {
        get { provider }
        set { setProvider(newValue) }
    }

    /// The Search key: search now and hide the suggestions.
    func submit() {
        let term = self.term
        guard !term.isEmpty else { return }
        submittedTerm = term
        pending?.cancel()
        pending = Task { await load(term) }
    }

    private func load(_ term: String) async {
        if results.isEmpty {
            phase = .searching
        }
        let catalog = self.catalog
        let provider = self.provider
        async let suggested = (try? await catalog.suggestions(for: term, in: provider)) ?? []
        do {
            let found = try await catalog.search(term, in: provider)
            guard !Task.isCancelled, term == self.term, provider == self.provider else { return }
            results = found
            phase = found.isEmpty ? .noResults : .results
        } catch {
            guard !Task.isCancelled, term == self.term, provider == self.provider else { return }
            phase = .failed(error.localizedDescription)
        }
        let latest = await suggested
        if term == self.term, provider == self.provider {
            suggestions = latest
        }
    }
}

import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import Observation

/// The person's Spotify connection: their Client ID (pasted in Settings),
/// the sign-in tokens (keychain, synced by iCloud Keychain), and whether
/// Standup can use Spotify right now.
@MainActor
@Observable
final class SpotifyAccount {
    private(set) var clientID: String?
    private(set) var isConnected: Bool
    /// Spotify's name for the person, once known.
    private(set) var displayName: String?

    @ObservationIgnored private let clientIDStore: any KeyStoring
    @ObservationIgnored private let tokenStore: any KeyStoring
    @ObservationIgnored private let transport: SpotifyWebAPI.Transport
    @ObservationIgnored private var tokens: SpotifyTokens?
    /// The sign-in under way: its PKCE verifier and state check.
    @ObservationIgnored private var pending: (verifier: String, state: String)?
    @ObservationIgnored private var refreshing: Task<SpotifyTokens, any Error>?
    /// Mock mode: connecting needs no Spotify.
    @ObservationIgnored let isMock: Bool
    @ObservationIgnored var now: () -> Date = { .now }

    init(
        clientIDs: any KeyStoring, tokens: any KeyStoring,
        transport: @escaping SpotifyWebAPI.Transport = { try await URLSession.shared.data(for: $0) },
        isMock: Bool = false
    ) {
        clientIDStore = clientIDs
        tokenStore = tokens
        self.transport = transport
        self.isMock = isMock
        clientID = clientIDs.load()
        self.tokens = SpotifyTokens(encoded: tokens.load())
        isConnected = self.tokens != nil
    }

    // MARK: Client ID

    /// Keeps the Client ID from the person's Spotify developer app. A new
    /// one signs out of the old.
    func setClientID(_ id: String) {
        let id = id.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !id.isEmpty, id != clientID else { return }
        disconnect()
        clientIDStore.save(id)
        clientID = id
    }

    func removeClientID() {
        disconnect()
        clientIDStore.save(nil)
        clientID = nil
    }

    // MARK: Signing in

    /// Spotify's sign-in page, for a new attempt.
    func signInURL() -> URL? {
        guard let clientID else { return nil }
        let verifier = SpotifyAuth.randomString()
        let state = SpotifyAuth.randomString(length: 24)
        pending = (verifier, state)
        return SpotifyAuth.authorizationURL(clientID: clientID, challenge: SpotifyAuth.challenge(for: verifier), state: state)
    }

    /// Finishes sign-in with Spotify's redirect back to Standup.
    func finishSignIn(callback: URL) async throws {
        guard let pending, let clientID else { throw SpotifyAuth.CallbackError.wrongState }
        let code = try SpotifyAuth.code(from: callback, state: pending.state)
        self.pending = nil
        let response = try await send(SpotifyAuth.tokenRequest(code: code, verifier: pending.verifier, clientID: clientID))
        keep(SpotifyTokens(response, now: now()))
        await loadName()
    }

    /// Mock mode's stand-in for signing in.
    func connectMock() {
        isConnected = true
        displayName = "Sample Listener"
    }

    func disconnect() {
        refreshing?.cancel()
        refreshing = nil
        tokenStore.save(nil)
        tokens = nil
        isConnected = false
        displayName = nil
    }

    // MARK: Tokens

    /// A token for Spotify, refreshed when it's spent or nearly so.
    func validToken() async throws -> String {
        guard let tokens else { throw SpotifyError.notConnected }
        guard tokens.needsRefresh(now: now()) else { return tokens.accessToken }
        if let refreshing {
            return try await refreshing.value.accessToken
        }
        guard let clientID else { throw SpotifyError.notConnected }
        let request = SpotifyAuth.refreshRequest(refreshToken: tokens.refreshToken, clientID: clientID)
        let refreshToken = tokens.refreshToken, transport = self.transport, asked = now()
        let task = Task {
            let response = try await Self.send(request, transport: transport)
            return SpotifyTokens(response, previousRefreshToken: refreshToken, now: asked)
        }
        refreshing = task
        defer { refreshing = nil }
        do {
            let fresh = try await task.value
            keep(fresh)
            return fresh.accessToken
        } catch SpotifyError.status(let code) where code == 400 || code == 401 {
            // The refresh token was revoked: sign in again.
            disconnect()
            throw SpotifyError.notConnected
        }
    }

    private func keep(_ tokens: SpotifyTokens) {
        self.tokens = tokens
        tokenStore.save(tokens.encoded)
        isConnected = true
    }

    private func send(_ request: URLRequest) async throws -> SpotifyAuth.TokenResponse {
        try await Self.send(request, transport: transport)
    }

    private nonisolated static func send(_ request: URLRequest, transport: SpotifyWebAPI.Transport) async throws -> SpotifyAuth.TokenResponse {
        let (data, response) = try await transport(request)
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw SpotifyError.status(http.statusCode)
        }
        return try JSONDecoder().decode(SpotifyAuth.TokenResponse.self, from: data)
    }

    // MARK: Profile

    private struct Profile: Decodable {
        var displayName: String?

        enum CodingKeys: String, CodingKey {
            case displayName = "display_name"
        }
    }

    /// Spotify's name for the person, for Settings. Not needed for anything
    /// else, so a failure is ignored.
    func loadName() async {
        guard let token = try? await validToken() else { return }
        var request = URLRequest(url: SpotifyWebAPI.base.appendingPathComponent("me"))
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        guard let answer = try? await transport(request),
              let profile = try? JSONDecoder().decode(Profile.self, from: answer.0)
        else { return }
        displayName = profile.displayName
    }
}

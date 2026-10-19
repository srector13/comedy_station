import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import Testing
@testable import Standup

struct SpotifyAuthTests {
    @Test func theSignInPageAsksForRemoteControlWithPKCE() throws {
        let url = SpotifyAuth.authorizationURL(clientID: "client123", challenge: "abc", state: "xyz")
        let items = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems)
        func value(_ name: String) -> String? { items.first { $0.name == name }?.value }
        #expect(url.host == "accounts.spotify.com")
        #expect(value("client_id") == "client123")
        #expect(value("response_type") == "code")
        #expect(value("redirect_uri") == "standup://spotify-callback")
        #expect(value("code_challenge_method") == "S256")
        #expect(value("code_challenge") == "abc")
        #expect(value("state") == "xyz")
        #expect(value("scope")?.contains("app-remote-control") == true)
    }

    @Test func theRedirectGivesTheCodeOnlyWithTheRightState() throws {
        let good = URL(string: "standup://spotify-callback?code=CODE&state=xyz")!
        #expect(try SpotifyAuth.code(from: good, state: "xyz") == "CODE")
        #expect(throws: SpotifyAuth.CallbackError.wrongState) { try SpotifyAuth.code(from: good, state: "other") }
        let denied = URL(string: "standup://spotify-callback?error=access_denied&state=xyz")!
        #expect(throws: SpotifyAuth.CallbackError.denied("access_denied")) { try SpotifyAuth.code(from: denied, state: "xyz") }
    }

    @Test func theTokenRequestIsAForm() throws {
        let request = SpotifyAuth.tokenRequest(code: "a b+c", verifier: "v", clientID: "id")
        #expect(request.httpMethod == "POST")
        #expect(request.url == SpotifyAuth.tokenURL)
        let body = String(data: try #require(request.httpBody), encoding: .utf8)
        #expect(body == "client_id=id&code=a%20b%2Bc&code_verifier=v&grant_type=authorization_code&redirect_uri=standup%3A%2F%2Fspotify-callback")
    }

    @Test func tokensRefreshAMinuteEarlyAndKeepTheirRefreshToken() {
        let now = Date(timeIntervalSince1970: 1_000_000)
        let response = SpotifyAuth.TokenResponse(accessToken: "new", expiresIn: 3600, refreshToken: nil)
        let tokens = SpotifyTokens(response, previousRefreshToken: "old-refresh", now: now)
        #expect(tokens.refreshToken == "old-refresh")
        #expect(!tokens.needsRefresh(now: now.addingTimeInterval(3500)))
        #expect(tokens.needsRefresh(now: now.addingTimeInterval(3550)))
        #expect(SpotifyTokens(encoded: tokens.encoded) == tokens)
    }
}

@MainActor
struct SpotifyAccountTests {
    /// Spotify's token endpoint, answering with whatever is queued.
    final class FakeSpotify: @unchecked Sendable {
        var answers: [(status: Int, body: String)] = []
        var requests: [URLRequest] = []

        var transport: SpotifyWebAPI.Transport {
            { request in
                self.requests.append(request)
                let answer: (status: Int, body: String) = self.answers.isEmpty ? (200, "{}") : self.answers.removeFirst()
                return (Data(answer.body.utf8), HTTPURLResponse(url: request.url!, statusCode: answer.status, httpVersion: nil, headerFields: nil)!)
            }
        }
    }

    let spotify = FakeSpotify()
    let tokens = MemoryKeyStore()

    func account() -> SpotifyAccount {
        SpotifyAccount(clientIDs: MemoryKeyStore("client123"), tokens: tokens, transport: spotify.transport)
    }

    private func signIn(_ account: SpotifyAccount) async throws {
        let url = try #require(account.signInURL())
        let state = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?.first { $0.name == "state" }?.value)
        spotify.answers = [(200, #"{"access_token":"A1","expires_in":3600,"refresh_token":"R1"}"#), (200, #"{"display_name":"Stephen"}"#)]
        try await account.finishSignIn(callback: URL(string: "standup://spotify-callback?code=C&state=\(state)")!)
    }

    @Test func signingInKeepsTokensAndName() async throws {
        let account = account()
        #expect(!account.isConnected)
        try await signIn(account)
        #expect(account.isConnected)
        #expect(account.displayName == "Stephen")
        #expect(try await account.validToken() == "A1")
        #expect(SpotifyTokens(encoded: tokens.load())?.refreshToken == "R1")
        // A relaunch finds the connection.
        #expect(SpotifyAccount(clientIDs: MemoryKeyStore("client123"), tokens: tokens).isConnected)
    }

    @Test func aSpentTokenIsRefreshed() async throws {
        let account = account()
        var clock = Date(timeIntervalSince1970: 1_000_000)
        account.now = { clock }
        try await signIn(account)
        clock += 3590
        spotify.answers = [(200, #"{"access_token":"A2","expires_in":3600}"#)]
        #expect(try await account.validToken() == "A2")
        #expect(SpotifyTokens(encoded: tokens.load())?.refreshToken == "R1")
    }

    @Test func aRevokedRefreshSignsOut() async throws {
        let account = account()
        var clock = Date(timeIntervalSince1970: 1_000_000)
        account.now = { clock }
        try await signIn(account)
        clock += 7200
        spotify.answers = [(400, #"{"error":"invalid_grant"}"#)]
        await #expect(throws: SpotifyError.notConnected) { _ = try await account.validToken() }
        #expect(!account.isConnected)
        #expect(tokens.load() == nil)
    }

    @Test func aNewClientIDSignsOut() async throws {
        let account = account()
        try await signIn(account)
        account.setClientID("other-client")
        #expect(!account.isConnected)
        #expect(account.clientID == "other-client")
    }
}

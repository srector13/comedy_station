import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Spotify sign-in with PKCE: the app holds only the person's Client ID
/// (from Settings), never a client secret. These are the requests and
/// answers; `SpotifyAccount` runs the flow and keeps the tokens.
enum SpotifyAuth {
    static let redirectURI = "standup://spotify-callback"
    static let callbackScheme = "standup"
    /// Remote control of the Spotify app. The catalog requests need no scope.
    static let scopes = ["app-remote-control", "user-read-playback-state", "user-modify-playback-state"]
    static let authorizeURL = URL(string: "https://accounts.spotify.com/authorize")!
    static let tokenURL = URL(string: "https://accounts.spotify.com/api/token")!

    /// The page Spotify signs the person in on.
    static func authorizationURL(clientID: String, challenge: String, state: String) -> URL {
        var components = URLComponents(url: authorizeURL, resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "client_id", value: clientID),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "redirect_uri", value: redirectURI),
            URLQueryItem(name: "code_challenge_method", value: "S256"),
            URLQueryItem(name: "code_challenge", value: challenge),
            URLQueryItem(name: "scope", value: scopes.joined(separator: " ")),
            URLQueryItem(name: "state", value: state),
        ]
        return components.url!
    }

    enum CallbackError: LocalizedError, Equatable {
        case denied(String)
        case wrongState
        case noCode

        var errorDescription: String? {
            switch self {
            case .denied(let reason): reason == "access_denied" ? "Spotify sign-in was cancelled." : "Spotify didn't sign you in (\(reason))."
            case .wrongState: "That Spotify sign-in wasn't the one Standup started. Try again."
            case .noCode: "Spotify didn't send a sign-in code. Try again."
            }
        }
    }

    /// The code in Spotify's redirect, once its state matches ours.
    static func code(from callback: URL, state: String) throws -> String {
        let items = URLComponents(url: callback, resolvingAgainstBaseURL: false)?.queryItems ?? []
        func value(_ name: String) -> String? { items.first { $0.name == name }?.value }
        if let error = value("error") { throw CallbackError.denied(error) }
        guard value("state") == state else { throw CallbackError.wrongState }
        guard let code = value("code"), !code.isEmpty else { throw CallbackError.noCode }
        return code
    }

    /// Trades the code for tokens.
    static func tokenRequest(code: String, verifier: String, clientID: String) -> URLRequest {
        form([
            "grant_type": "authorization_code",
            "code": code,
            "redirect_uri": redirectURI,
            "client_id": clientID,
            "code_verifier": verifier,
        ])
    }

    /// A new access token from the refresh token.
    static func refreshRequest(refreshToken: String, clientID: String) -> URLRequest {
        form([
            "grant_type": "refresh_token",
            "refresh_token": refreshToken,
            "client_id": clientID,
        ])
    }

    private static func form(_ fields: [String: String]) -> URLRequest {
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-._~")
        let body = fields.sorted { $0.key < $1.key }
            .map { "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: allowed) ?? $0.value)" }
            .joined(separator: "&")
        var request = URLRequest(url: tokenURL)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = Data(body.utf8)
        return request
    }

    /// Spotify's token answer.
    struct TokenResponse: Decodable {
        var accessToken: String
        var expiresIn: Int
        var refreshToken: String?

        enum CodingKeys: String, CodingKey {
            case accessToken = "access_token"
            case expiresIn = "expires_in"
            case refreshToken = "refresh_token"
        }
    }

    /// A random string for the PKCE verifier and the state check.
    static func randomString(length: Int = 64) -> String {
        let characters = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~")
        var generator = SystemRandomNumberGenerator()
        return String((0..<length).map { _ in characters.randomElement(using: &generator)! })
    }
}

/// The tokens kept in the keychain.
struct SpotifyTokens: Codable, Equatable, Sendable {
    var accessToken: String
    var refreshToken: String
    var expiresAt: Date

    init(accessToken: String, refreshToken: String, expiresAt: Date) {
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        self.expiresAt = expiresAt
    }

    /// From a token answer; a refresh that doesn't send a new refresh token
    /// keeps the old one.
    init(_ response: SpotifyAuth.TokenResponse, previousRefreshToken: String? = nil, now: Date = .now) {
        accessToken = response.accessToken
        refreshToken = response.refreshToken ?? previousRefreshToken ?? ""
        expiresAt = now.addingTimeInterval(TimeInterval(response.expiresIn))
    }

    /// Spent, or within a minute of it.
    func needsRefresh(now: Date = .now) -> Bool {
        expiresAt.timeIntervalSince(now) < 60
    }

    var encoded: String? {
        (try? JSONEncoder().encode(self)).flatMap { String(data: $0, encoding: .utf8) }
    }

    init?(encoded: String?) {
        guard let data = encoded?.data(using: .utf8),
              let tokens = try? JSONDecoder().decode(SpotifyTokens.self, from: data)
        else { return nil }
        self = tokens
    }
}

import Testing
@testable import Standup

/// The PKCE challenge (CryptoKit, so it runs on Apple platforms only).
struct SpotifyPKCETests {
    /// RFC 7636, appendix B.
    @Test func challengeMatchesTheRFCExample() {
        #expect(SpotifyAuth.challenge(for: "dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk") == "E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM")
    }
}

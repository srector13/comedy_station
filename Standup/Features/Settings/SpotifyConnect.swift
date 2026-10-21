import AuthenticationServices
import SwiftUI

extension SpotifyAccount {
    /// Signs in to Spotify in a web sheet (Settings and the Spotify route's
    /// setup). Nil once connected, or when the person closed the sheet;
    /// otherwise what went wrong.
    func connect(with session: WebAuthenticationSession) async -> String? {
        if isMock {
            connectMock()
            return nil
        }
        guard let url = signInURL() else { return "Add your Spotify Client ID first." }
        do {
            let callback = try await session.authenticate(using: url, callbackURLScheme: SpotifyAuth.callbackScheme)
            try await finishSignIn(callback: callback)
            return nil
        } catch let error as ASWebAuthenticationSessionError where error.code == .canceledLogin {
            // Closed the sign-in sheet: nothing to say.
            return nil
        } catch {
            return error.localizedDescription
        }
    }
}

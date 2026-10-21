import SwiftUI

/// The Spotify route's setup. Spotify only lets an app in Development Mode
/// sign in people its owner lists, through the owner's own developer app,
/// so this asks for that app's Client ID first, then signs in.
struct SpotifySetupView: View {
    @Environment(SpotifyAccount.self) private var spotify
    @Environment(ServiceChoice.self) private var service
    @Environment(AuthGate.self) private var gate
    @Environment(\.webAuthenticationSession) private var webAuthenticationSession
    @State private var clientIDDraft = ""
    @State private var problem: String?
    @State private var isWorking = false
    @ScaledMetric(relativeTo: .largeTitle) private var symbolSize = 72

    var body: some View {
        OnboardingPage {
            Image(systemName: "headphones")
                .font(.system(size: symbolSize, weight: .semibold))
                .foregroundStyle(Theme.accent)
                .symbolRenderingMode(.hierarchical)
                .accessibilityHidden(true)

            VStack(spacing: 12) {
                Text("Connect Spotify")
                    .font(.largeTitle.bold())
                    .accessibilityAddTraits(.isHeader)
                Text("Standup finds stand-up on Spotify and plays it in the Spotify app. You need Spotify Premium, and the Spotify app on this iPhone.")
                    .font(.body)
                    .foregroundStyle(.secondary)
            }
            .multilineTextAlignment(.center)

            if spotify.clientID == nil {
                steps
            }
        } actions: {
            VStack(spacing: 12) {
                if spotify.clientID == nil {
                    TextField("Spotify Client ID", text: $clientIDDraft)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .submitLabel(.continue)
                        .onSubmit {
                            spotify.setClientID(clientIDDraft)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(.quaternary, in: .rect(cornerRadius: 14))
                        .accessibilityIdentifier("spotifySetup.clientID")
                    primaryButton("Continue") {
                        spotify.setClientID(clientIDDraft)
                    }
                    .disabled(clientIDDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .accessibilityIdentifier("spotifySetup.saveClientID")
                } else {
                    primaryButton("Connect Spotify") {
                        Task { await connect() }
                    }
                    .disabled(isWorking)
                    .accessibilityIdentifier("spotifySetup.connect")
                    Button {
                        spotify.removeClientID()
                    } label: {
                        Text("Use a Different Client ID")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.glass)
                    .controlSize(.large)
                    .disabled(isWorking)
                }
            }

            if let problem {
                Text(problem)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
            }

            Button("Use Apple Music Instead") {
                useAppleMusic()
            }
            .font(.subheadline)
            .disabled(isWorking)
            .accessibilityIdentifier("spotifySetup.useAppleMusic")

            Text("Spotify can't keep comedy out of your Spotify listening history (a Private Session in Spotify can). Standup never saves anything to your Spotify library.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    /// Making the Spotify developer app the Client ID comes from.
    private var steps: some View {
        let bundleID = Bundle.main.bundleIdentifier ?? "PolarReality.Standup"
        return VStack(alignment: .leading, spacing: 10) {
            step(1, "At developer.spotify.com, create an app. Add the redirect URI standup://spotify-callback, tick Web API and iOS, and enter the bundle ID \(bundleID).")
            step(2, "Under User Management, add your Spotify account.")
            step(3, "Paste the app's Client ID below. No secret is needed.")
        }
        .font(.subheadline)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityIdentifier("spotifySetup.steps")
    }

    private func step(_ number: Int, _ text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text("\(number).")
                .monospacedDigit()
                .foregroundStyle(Theme.accent)
            Text(text)
                .textSelection(.enabled)
        }
    }

    private func primaryButton(_ title: String, action: @escaping @MainActor () -> Void) -> some View {
        Button(action: action) {
            Group {
                if isWorking {
                    ProgressView()
                } else {
                    Text(title)
                }
            }
            .font(.headline)
            .frame(maxWidth: .infinity)
            .foregroundStyle(Theme.onAccent)
        }
        .buttonStyle(.glassProminent)
        .controlSize(.large)
    }

    private func connect() async {
        problem = nil
        isWorking = true
        defer { isWorking = false }
        problem = await spotify.connect(with: webAuthenticationSession)
    }

    private func useAppleMusic() {
        isWorking = true
        Task {
            await gate.requestAccess()
            service.choose(.appleMusic)
            isWorking = false
        }
    }
}

#Preview {
    SpotifySetupView()
        .previewEnvironment()
}

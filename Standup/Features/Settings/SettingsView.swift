import AuthenticationServices
import SwiftUI

/// Settings: the TMDB key behind New and Popular Specials, the Spotify
/// connection, iCloud sync, and credits (TMDB asks for its logo and notice).
struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.webAuthenticationSession) private var webAuthenticationSession
    @Environment(SpecialsSettings.self) private var specials
    @Environment(SpotifyAccount.self) private var spotify
    @Environment(LibraryStore.self) private var library
    @State private var draft = ""
    @State private var isChecking = false
    @State private var problem: String?
    @State private var clientIDDraft = ""
    @State private var isConnecting = false
    @State private var spotifyProblem: String?

    var body: some View {
        NavigationStack {
            Form {
                specialsSection
                spotifySection
                if library.syncStatus != .local {
                    Section("iCloud") {
                        SyncStatusLine(status: library.syncStatus)
                    }
                }
                aboutSection
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .accessibilityIdentifier("settings.done")
                }
            }
        }
    }

    private var specialsSection: some View {
        Section {
            if specials.hasKey {
                Label("TMDB key saved", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(Theme.accent)
                    .accessibilityIdentifier("settings.tmdbSaved")
                Button("Remove Key", role: .destructive) {
                    specials.remove()
                }
            } else {
                SecureField("TMDB API key", text: $draft)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .accessibilityIdentifier("settings.tmdbKey")
                Button {
                    Task { await save() }
                } label: {
                    if isChecking {
                        ProgressView()
                    } else {
                        Text("Save Key")
                    }
                }
                .disabled(draft.trimmingCharacters(in: .whitespaces).isEmpty || isChecking)
                .accessibilityIdentifier("settings.tmdbSave")
            }
        } header: {
            Text("New & Popular Specials")
        } footer: {
            if let problem {
                Text(problem)
                    .foregroundStyle(.red)
            } else if specials.hasKey {
                Text("Home and Browse find new and popular stand-up specials through TMDB, and show the ones on Apple Music.")
            } else {
                Text("Apple's comedy charts lean on novelty songs and old albums. With a free TMDB API key (themoviedb.org → Settings → API), Home and Browse show new and popular stand-up specials instead, the ones on Apple Music.")
            }
        }
    }

    private var spotifySection: some View {
        Section {
            if spotify.clientID == nil {
                TextField("Spotify Client ID", text: $clientIDDraft)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .accessibilityIdentifier("settings.spotifyClientID")
                Button("Save Client ID") {
                    spotify.setClientID(clientIDDraft)
                    clientIDDraft = ""
                }
                .disabled(clientIDDraft.trimmingCharacters(in: .whitespaces).isEmpty)
                .accessibilityIdentifier("settings.spotifySaveClientID")
            } else if spotify.isConnected {
                Label(spotify.displayName.map { "Connected as \($0)" } ?? "Connected", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(Theme.accent)
                    .accessibilityIdentifier("settings.spotifyConnected")
                Button("Disconnect Spotify", role: .destructive) {
                    spotify.disconnect()
                }
            } else {
                Button {
                    Task { await connectSpotify() }
                } label: {
                    if isConnecting {
                        ProgressView()
                    } else {
                        Text("Connect Spotify")
                    }
                }
                .disabled(isConnecting)
                .accessibilityIdentifier("settings.spotifyConnect")
                Button("Change Client ID") {
                    spotify.removeClientID()
                }
            }
        } header: {
            Text("Spotify")
        } footer: {
            if let spotifyProblem {
                Text(spotifyProblem)
                    .foregroundStyle(.red)
            } else {
                Text("Search and play stand-up on Spotify too. Spotify plays in its own app and needs Premium, and it can't keep comedy out of your Spotify listening history (a Private Session in Spotify can). Standup never saves anything to your Spotify library. Setup: docs/MUSICKIT_SETUP.md.")
            }
        }
    }

    private func connectSpotify() async {
        spotifyProblem = nil
        if spotify.isMock {
            spotify.connectMock()
            return
        }
        guard let url = spotify.signInURL() else { return }
        isConnecting = true
        defer { isConnecting = false }
        do {
            let callback = try await webAuthenticationSession.authenticate(using: url, callbackURLScheme: SpotifyAuth.callbackScheme)
            try await spotify.finishSignIn(callback: callback)
        } catch let error as ASWebAuthenticationSessionError where error.code == .canceledLogin {
            // Closed the sign-in sheet: nothing to say.
        } catch {
            spotifyProblem = error.localizedDescription
        }
    }

    private var aboutSection: some View {
        Section("About") {
            LabeledContent("Version", value: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "–")
            VStack(alignment: .leading, spacing: 10) {
                Image("TMDBLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 16)
                    .accessibilityLabel("TMDB")
                Text("This product uses the TMDB API but is not endorsed or certified by TMDB.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 4)
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("settings.tmdbCredit")
        }
    }

    private func save() async {
        isChecking = true
        problem = nil
        defer { isChecking = false }
        do {
            try await specials.save(draft)
            draft = ""
        } catch {
            problem = error.localizedDescription
        }
    }
}

/// A gear in a tab's navigation bar that opens Settings.
struct SettingsButton: ViewModifier {
    @State private var showsSettings = false

    func body(content: Content) -> some View {
        content
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Settings", systemImage: "gearshape") {
                        showsSettings = true
                    }
                    .accessibilityIdentifier("settings.open")
                }
            }
            .sheet(isPresented: $showsSettings) {
                SettingsView()
            }
    }
}

extension View {
    func settingsButton() -> some View {
        modifier(SettingsButton())
    }
}

#Preview {
    SettingsView()
        .previewEnvironment()
}

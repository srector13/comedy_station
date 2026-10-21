import AuthenticationServices
import SwiftUI

/// Settings: the service Standup runs on, the TMDB key behind New and
/// Popular Specials, the Spotify connection, iCloud sync, and credits (TMDB
/// asks for its logo and notice).
struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.webAuthenticationSession) private var webAuthenticationSession
    @Environment(SpecialsSettings.self) private var specials
    @Environment(SpotifyAccount.self) private var spotify
    @Environment(LibraryStore.self) private var library
    @Environment(ServiceChoice.self) private var service
    @Environment(AuthGate.self) private var gate
    @State private var draft = ""
    @State private var isChecking = false
    @State private var problem: String?
    @State private var clientIDDraft = ""
    @State private var isConnecting = false
    @State private var spotifyProblem: String?
    @State private var isSwitching = false

    var body: some View {
        NavigationStack {
            Form {
                serviceSection
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

    /// Which service Standup runs on, and switching to the other.
    private var serviceSection: some View {
        let current = service.provider ?? .appleMusic
        let other: Provider = current == .spotify ? .appleMusic : .spotify
        return Section {
            LabeledContent("Listening On", value: current.name)
                .accessibilityIdentifier("settings.service")
            Button("Switch to \(other.name)") {
                switchService(to: other)
            }
            .disabled(isSwitching)
            .accessibilityIdentifier("settings.switchService")
        } header: {
            Text("Service")
        } footer: {
            Text(current == .spotify
                ? "Standup finds stand-up on Spotify and plays it in the Spotify app. It doesn't use Apple Music."
                : "Standup finds and plays stand-up on Apple Music.")
        }
    }

    /// Apple Music asks for access first (at once if already allowed);
    /// Spotify goes to its setup when it isn't connected.
    private func switchService(to provider: Provider) {
        guard provider == .appleMusic else {
            service.choose(.spotify)
            return
        }
        isSwitching = true
        Task {
            await gate.requestAccess()
            service.choose(.appleMusic)
            isSwitching = false
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
            } else if service.isSpotify {
                Text(specials.hasKey
                    ? "Home finds new, popular and essential stand-up specials through TMDB, and shows the ones on Spotify."
                    : "With a free TMDB API key (themoviedb.org → Settings → API), Home shows new, popular and essential stand-up specials on Spotify. Without one, Home has only what you've saved.")
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
                Text("\(service.isSpotify ? "" : "Search and play stand-up on Spotify too. ")Spotify plays in its own app and needs Premium, and it can't keep comedy out of your Spotify listening history (a Private Session in Spotify can). Standup never saves anything to your Spotify library. Setup: docs/MUSICKIT_SETUP.md.")
            }
        }
    }

    private func connectSpotify() async {
        spotifyProblem = nil
        isConnecting = true
        defer { isConnecting = false }
        spotifyProblem = await spotify.connect(with: webAuthenticationSession)
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

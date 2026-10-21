import SwiftUI

/// First launch: which service Standup runs on. Apple Music asks for access
/// straight away; Spotify goes on to its setup (`SpotifySetupView`).
struct ServicePickerView: View {
    @Environment(ServiceChoice.self) private var service
    @Environment(AuthGate.self) private var gate
    @State private var isWorking = false
    @ScaledMetric(relativeTo: .largeTitle) private var symbolSize = 72

    var body: some View {
        OnboardingPage {
            Image(systemName: "music.mic")
                .font(.system(size: symbolSize, weight: .semibold))
                .foregroundStyle(Theme.accent)
                .symbolRenderingMode(.hierarchical)
                .accessibilityHidden(true)

            VStack(spacing: 12) {
                Text("Standup")
                    .font(.largeTitle.bold())
                    .accessibilityAddTraits(.isHeader)
                Text("Stand-up specials, sets, and bits, and nothing else. Where do you listen?")
                    .font(.body)
                    .foregroundStyle(.secondary)
            }
            .multilineTextAlignment(.center)
        } actions: {
            VStack(spacing: 12) {
                choice(.appleMusic, detail: "Needs an Apple Music subscription. Plays right here in Standup.")
                choice(.spotify, detail: "Needs Spotify Premium and the Spotify app, where it plays. Takes a few minutes to set up.")
            }
            Text("You can switch in Settings. Standup keeps its own library and never adds anything to yours.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    private func choice(_ provider: Provider, detail: String) -> some View {
        Button {
            choose(provider)
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                Text(provider.name)
                    .font(.headline)
                Text(detail)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.leading)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 6)
        }
        .buttonStyle(.glass)
        .buttonBorderShape(.roundedRectangle(radius: 20))
        .controlSize(.large)
        .disabled(isWorking)
        .accessibilityIdentifier("service.\(provider.rawValue)")
    }

    private func choose(_ provider: Provider) {
        guard provider == .appleMusic else {
            service.choose(.spotify)
            return
        }
        isWorking = true
        Task {
            await gate.requestAccess()
            service.choose(.appleMusic)
            isWorking = false
        }
    }
}

/// An onboarding screen's layout: content centered in the space above the
/// actions, scrolling when text is large.
struct OnboardingPage<Content: View, Actions: View>: View {
    @ViewBuilder var content: Content
    @ViewBuilder var actions: Actions

    var body: some View {
        GeometryReader { proxy in
            ScrollView {
                VStack(spacing: 28) {
                    Spacer(minLength: 24)
                    content
                    Spacer(minLength: 24)
                    actions
                }
                .frame(maxWidth: 520)
                .padding(.horizontal, 28)
                .padding(.bottom, 16)
                .frame(maxWidth: .infinity, minHeight: proxy.size.height)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
    }
}

#Preview {
    ServicePickerView()
        .previewEnvironment()
}

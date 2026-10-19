import MusicKit
import SwiftUI
import UIKit

/// Onboarding, and the screens shown while Apple Music can't be used.
struct AccessGateView: View {
    let state: AccessState

    @Environment(AuthGate.self) private var gate
    @Environment(\.openURL) private var openURL
    @State private var showsSubscriptionOffer = false
    @State private var isWorking = false
    @ScaledMetric(relativeTo: .largeTitle) private var symbolSize = 72

    var body: some View {
        let content = GateContent(state: state)
        GeometryReader { proxy in
            ScrollView {
                VStack(spacing: 28) {
                    Spacer(minLength: 24)

                    Image(systemName: content.symbol)
                        .font(.system(size: symbolSize, weight: .semibold))
                        .foregroundStyle(Theme.accent)
                        .symbolRenderingMode(.hierarchical)
                        .accessibilityHidden(true)

                    VStack(spacing: 12) {
                        Text(content.title)
                            .font(.largeTitle.bold())
                            .accessibilityAddTraits(.isHeader)
                        Text(content.message)
                            .font(.body)
                            .foregroundStyle(.secondary)
                        if let detail = content.detail {
                            Text(detail)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                                .textSelection(.enabled)
                        }
                    }
                    .multilineTextAlignment(.center)

                    Spacer(minLength: 24)

                    VStack(spacing: 12) {
                        Button {
                            perform(content.primary)
                        } label: {
                            Text(content.primary.title)
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .foregroundStyle(Theme.onAccent)
                        }
                        .buttonStyle(.glassProminent)
                        .controlSize(.large)
                        .disabled(isWorking)
                        .accessibilityIdentifier("gate.primary")

                        if let secondary = content.secondary {
                            Button {
                                perform(secondary)
                            } label: {
                                Text(secondary.title)
                                    .font(.headline)
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.glass)
                            .controlSize(.large)
                            .disabled(isWorking)
                            .accessibilityIdentifier("gate.secondary")
                        }
                    }

                    if let footnote = content.footnote {
                        Text(footnote)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                }
                .frame(maxWidth: 520)
                .padding(.horizontal, 28)
                .padding(.bottom, 16)
                .frame(maxWidth: .infinity, minHeight: proxy.size.height)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
        .musicSubscriptionOffer(isPresented: $showsSubscriptionOffer)
    }

    private func perform(_ action: GateContent.Action) {
        switch action {
        case .requestAccess:
            run { await gate.requestAccess() }
        case .checkAgain:
            run { await gate.refresh() }
        case .openSettings:
            if let url = URL(string: UIApplication.openSettingsURLString) {
                openURL(url)
            }
        case .subscribe:
            showsSubscriptionOffer = true
        }
    }

    private func run(_ work: @escaping @MainActor () async -> Void) {
        isWorking = true
        Task {
            await work()
            isWorking = false
        }
    }
}

/// The words and buttons for each gate state.
struct GateContent: Equatable {
    enum Action: Equatable {
        case requestAccess, checkAgain, openSettings, subscribe

        var title: String {
            switch self {
            case .requestAccess: "Continue"
            case .checkAgain: "Check Again"
            case .openSettings: "Open Settings"
            case .subscribe: "Try Apple Music"
            }
        }
    }

    var symbol: String
    var title: String
    var message: String
    var detail: String?
    var primary: Action
    var secondary: Action?
    var footnote: String?

    init(state: AccessState) {
        detail = nil
        secondary = nil
        footnote = nil
        switch state {
        case .needsAuthorization, .checking, .ready:
            symbol = "music.mic"
            title = "Standup"
            message = "Stand-up specials, sets, and bits from the Apple Music catalog, and nothing else."
            primary = .requestAccess
            footnote = "Standup keeps its own library. It never adds anything to your Apple Music library, and what you play here stays out of your listening history."
        case .denied:
            symbol = "hand.raised.fill"
            title = "Allow Apple Music Access"
            message = "Standup needs access to Apple Music to play comedy. Turn on Media & Apple Music for Standup in Settings."
            primary = .openSettings
            secondary = .checkAgain
        case .restricted:
            symbol = "lock.fill"
            title = "Apple Music Is Restricted"
            message = "Access to Apple Music is restricted on this device, for example by Screen Time."
            primary = .checkAgain
        case .noSubscription(let canSubscribe):
            symbol = "music.note"
            title = "Subscription Needed"
            message = "Playing full specials needs an active Apple Music subscription."
            primary = canSubscribe ? .subscribe : .checkAgain
            secondary = canSubscribe ? .checkAgain : nil
        case .misconfigured(let signing):
            symbol = "exclamationmark.lock.fill"
            title = "MusicKit Isn't Set Up"
            message = "Apple Music only serves the catalog to a copy of Standup signed by the team whose App ID has MusicKit turned on, under that App ID's bundle ID."
            detail = signing
            primary = .checkAgain
            footnote = "The App ID needs MusicKit ticked under App Services. In Feather, sign with your own certificate and a profile for that App ID, and keep the bundle ID. See docs/MUSICKIT_SETUP.md."
        case .unavailable(let reason):
            symbol = "wifi.exclamationmark"
            title = "Can't Reach Apple Music"
            message = "Check your connection and try again. If this keeps happening, MusicKit may not be enabled for this app's bundle ID, or the app wasn't signed by that team."
            detail = reason
            primary = .checkAgain
        }
    }
}

#Preview("Onboarding") {
    AccessGateView(state: .needsAuthorization)
        .environment(AuthGate(access: MockMusicAccess(scenario: .notDetermined)))
        .tint(Theme.accent)
}

#Preview("Denied") {
    AccessGateView(state: .denied)
        .environment(AuthGate(access: MockMusicAccess(scenario: .denied)))
        .tint(Theme.accent)
}

#Preview("No subscription") {
    AccessGateView(state: .noSubscription(canSubscribe: true))
        .environment(AuthGate(access: MockMusicAccess(scenario: .noSubscription)))
        .tint(Theme.accent)
}
